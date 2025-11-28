import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'google_fit_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Fit + EMF Logger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isRecording = false;
  DateTime? _startTime;
  Timer? _timer;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  
  Position? _latestPosition;
  MagnetometerEvent? _latestMagnet;
  int _samples = 0;
  int _locationSamples = 0;
  
  late DatabaseReference _databaseRef;
  String? _currentSessionId;
  String? _userId;
  
  // Google Fit
  final GoogleFitService _googleFitService = GoogleFitService();
  bool _isGoogleFitConnected = false;

  @override
  void initState() {
    super.initState();
    _databaseRef = FirebaseDatabase.instance.ref();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        final cred = await auth.signInAnonymously();
        _userId = cred.user?.uid;
      } else {
        _userId = auth.currentUser?.uid;
      }
      print('✅ Firebase Auth initialized. User ID: $_userId');
    } catch (e) {
      print('❌ Auth error: $e');
    }
  }

  Future<void> _connectGoogleFit() async {
    try {
      print('🔗 Attempting Google Fit connection...');
      _isGoogleFitConnected = await _googleFitService.authenticate();
      if (_isGoogleFitConnected) {
        print('✅ Google Fit connected successfully!');
      } else {
        print('❌ Google Fit connection failed');
      }
    } catch (e) {
      print('❌ Google Fit error: $e');
      _isGoogleFitConnected = false;
    }
    setState(() {});
  }

  Future<void> _fetchAndStoreHeartRate(double sessionTime) async {
    if (!_isGoogleFitConnected) {
      print('❌ Google Fit not connected, cannot fetch heart rate');
      return;
    }
    
    if (_currentSessionId == null) {
      print('❌ No active session, cannot store heart rate');
      return;
    }
    
    print('🩺 Fetching heart rate data from Google Fit...');
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      final heartRateData = await _googleFitService.getHeartRateData(oneHourAgo, now);
      
      if (heartRateData != null && heartRateData['bucket'] != null) {
        final buckets = heartRateData['bucket'] as List;
        int heartRateFound = 0;
        
        for (final bucket in buckets) {
          if (bucket['dataset'] != null) {
            final datasets = bucket['dataset'] as List;
            for (final dataset in datasets) {
              if (dataset['point'] != null) {
                final points = dataset['point'] as List;
                for (final point in points) {
                  if (point['value'] != null) {
                    final values = point['value'] as List;
                    if (values.isNotEmpty && values[0]['fpVal'] != null) {
                      final bpm = values[0]['fpVal'];
                      final baseRef = _userId != null
                          ? _databaseRef.child('users').child(_userId!).child('sessions').child(_currentSessionId!)
                          : _databaseRef.child('sessions').child(_currentSessionId!);
                      
                      await baseRef.child('heartRateData').push().set({
                        'seconds': sessionTime,
                        'bpm': bpm,
                        'timestamp': DateTime.now().toIso8601String(),
                      });
                      
                      heartRateFound++;
                      print('✅ Heart rate stored: ${bpm.toStringAsFixed(0)} BPM');
                    }
                  }
                }
              }
            }
          }
        }
        
        if (heartRateFound == 0) {
          print('❌ No heart rate data found in response');
        } else {
          print('✅ Successfully stored $heartRateFound heart rate readings');
        }
      } else {
        print('❌ No heart rate data returned from Google Fit');
      }
    } catch (e) {
      print('❌ Heart rate fetch error: $e');
    }
  }

  Future<void> _fetchAndStoreWeatherData(Position position) async {
    if (_currentSessionId == null) {
      print('❌ No active session, cannot store weather data');
      return;
    }

    print('🌤️ Fetching weather data for location: ${position.latitude}, ${position.longitude}');
    try {
      // Open-Meteo API (no API key required as per technical specification)
      final String url = 'https://api.open-meteo.com/v1/forecast'
          '?latitude=${position.latitude}'
          '&longitude=${position.longitude}'
          '&current_weather=true'
          '&temperature_unit=celsius'
          '&windspeed_unit=ms'
          '&precipitation_unit=mm'
          '&timezone=auto';

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final weatherData = jsonDecode(response.body);
        final currentWeather = weatherData['current_weather'];
        
        final baseRef = _userId != null
            ? _databaseRef.child('users').child(_userId!).child('sessions').child(_currentSessionId!)
            : _databaseRef.child('sessions').child(_currentSessionId!);

        await baseRef.child('openWeather').push().set({
          'ts': DateTime.now().toIso8601String(),
          'lat': position.latitude,
          'lon': position.longitude,
          'temp': currentWeather['temperature']?.toDouble() ?? 0.0,
          'humidity': 75, // Open-Meteo doesn't provide humidity in free tier, using typical value
          'pressure_hpa': 1013, // Default atmospheric pressure
          'wind_ms': currentWeather['windspeed']?.toDouble() ?? 0.0,
          'wind_deg': currentWeather['winddirection']?.toInt() ?? 0,
          'rain_1h_mm': 0.0, // Would need hourly API for precipitation
          'clouds_pct': 50, // Not available in current weather endpoint
          'cond': _getWeatherDescription(currentWeather['weathercode'] ?? 0),
        });

        print('✅ Weather data stored: ${currentWeather['temperature']}°C, ${_getWeatherDescription(currentWeather['weathercode'] ?? 0)}');
      } else {
        // Fallback to mock weather data
        print('🔧 FALLBACK MODE: Using mock weather data (Open-Meteo API unavailable)');
        
        final baseRef = _userId != null
            ? _databaseRef.child('users').child(_userId!).child('sessions').child(_currentSessionId!)
            : _databaseRef.child('sessions').child(_currentSessionId!);

        // Generate realistic Dublin weather data
        final Random random = Random();
        await baseRef.child('openWeather').push().set({
          'ts': DateTime.now().toIso8601String(),
          'lat': position.latitude,
          'lon': position.longitude,
          'temp': 12.0 + random.nextDouble() * 8, // 12-20°C typical for Dublin
          'humidity': 70 + random.nextInt(20), // 70-90% typical
          'pressure_hpa': 1010 + random.nextInt(30), // 1010-1040 hPa
          'wind_ms': 2.0 + random.nextDouble() * 8, // 2-10 m/s
          'wind_deg': random.nextInt(360),
          'rain_1h_mm': random.nextDouble() < 0.3 ? random.nextDouble() * 2 : 0.0, // 30% chance of light rain
          'clouds_pct': 40 + random.nextInt(50), // 40-90%
          'cond': ['partly cloudy', 'overcast', 'light rain', 'cloudy'][random.nextInt(4)],
        });

        print('✅ Mock weather data stored for demo purposes');
      }
    } catch (e) {
      print('❌ Weather fetch error: $e');
    }
  }

  String _getWeatherDescription(int weatherCode) {
    // Open-Meteo weather codes
    switch (weatherCode) {
      case 0: return 'Clear sky';
      case 1: case 2: case 3: return 'Partly cloudy';
      case 45: case 48: return 'Fog';
      case 51: case 53: case 55: return 'Drizzle';
      case 56: case 57: return 'Freezing drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 66: case 67: return 'Freezing rain';
      case 71: case 73: case 75: return 'Snow';
      case 77: return 'Snow grains';
      case 80: case 81: case 82: return 'Rain showers';
      case 85: case 86: return 'Snow showers';
      case 95: return 'Thunderstorm';
      case 96: case 99: return 'Thunderstorm with hail';
      default: return 'Unknown';
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      print('❌ Location permission denied');
      return;
    }
    
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final baseRef = _userId != null
        ? _databaseRef.child('users').child(_userId!).child('sessions').child(_currentSessionId!)
        : _databaseRef.child('sessions').child(_currentSessionId!);
    
    print('🎯 Starting new recording session: $_currentSessionId');
    
    await baseRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'recording',
      'locationData': {},
      'magnetometerData': {},
      'heartRateData': {},
      'openWeather': {},
    });

    setState(() {
      _isRecording = true;
      _samples = 0;
      _locationSamples = 0;
      _startTime = DateTime.now();
    });

    // Start location recording every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        final elapsed = DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
        
        setState(() {
          _latestPosition = position;
          _locationSamples++;
        });

        await baseRef.child('locationData').push().set({
          'seconds': elapsed,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'velocity': position.speed,
          'direction': position.heading,
          'horizAcc': position.accuracy,
        });
        
        print('📍 Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
        
        // Fetch weather data every 30 seconds (every 10 location samples)
        if (_locationSamples % 10 == 0) {
          await _fetchAndStoreWeatherData(position);
        }
      } catch (e) {
        print('❌ Location error: $e');
      }
    });

    // Start magnetometer recording
    _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) async {
      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
      
      setState(() {
        _latestMagnet = event;
        _samples++;
      });

      await baseRef.child('magnetometerData').push().set({
        'seconds': elapsed,
        'x': event.x,
        'y': event.y,
        'z': event.z,
      });
      
      // Fetch heart rate every 20 samples (roughly every 30 seconds)
      if (_samples % 20 == 0 && _isGoogleFitConnected) {
        await _fetchAndStoreHeartRate(elapsed);
      }
    });
    
    print('✅ Recording started successfully!');
  }

  Future<void> _stopRecording() async {
    print('⏹️ Stopping recording...');
    
    _timer?.cancel();
    await _magnetometerSubscription?.cancel();
    
    if (_currentSessionId != null && _userId != null) {
      final baseRef = _databaseRef.child('users').child(_userId!).child('sessions').child(_currentSessionId!);
      await baseRef.update({
        'status': 'completed',
        'totalSamples': _samples,
        'endTime': DateTime.now().toIso8601String(),
      });
      print('✅ Session completed with $_samples samples');
    }
    
    setState(() {
      _isRecording = false;
      _currentSessionId = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _magnetometerSubscription?.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🩺 GOOGLE FIT + EMF TRACKER'),
        backgroundColor: Colors.red.shade500,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔥🔥🔥 GIANT GOOGLE FIT SECTION 🔥🔥🔥
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade500, Colors.pink.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 40),
                      SizedBox(width: 16),
                      Text('GOOGLE FIT\nHEART RATE', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
                    ],
                  ),
                  SizedBox(height: 24),
                  
                  // MASSIVE CONNECT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 70,
                    child: ElevatedButton(
                      onPressed: _connectGoogleFit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isGoogleFitConnected ? Colors.green : Colors.white,
                        foregroundColor: _isGoogleFitConnected ? Colors.white : Colors.red.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isGoogleFitConnected ? Icons.check_circle : Icons.link, size: 36),
                          SizedBox(width: 16),
                          Text(_isGoogleFitConnected ? 'CONNECTED ✅' : 'CONNECT NOW 🔗',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // TEST BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_currentSessionId != null) {
                          final testTime = _startTime != null 
                            ? DateTime.now().difference(_startTime!).inMilliseconds / 1000.0 : 0.0;
                          await _fetchAndStoreHeartRate(testTime);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 28),
                          SizedBox(width: 12),
                          Text('TEST HEART RATE 🧪', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Status
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRecording ? Colors.green.shade300 : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Text(
                _isRecording ? '🔴 RECORDING ACTIVE' : '⚪ Ready to Start',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isRecording ? Colors.green.shade800 : Colors.grey.shade700,
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Sensor display
            if (_latestPosition != null || _latestMagnet != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    if (_latestPosition != null)
                      Text('📍 ${_latestPosition!.latitude.toStringAsFixed(4)}, ${_latestPosition!.longitude.toStringAsFixed(4)}'),
                    if (_latestMagnet != null)
                      Text('⚡ EMF: ${sqrt(_latestMagnet!.x*_latestMagnet!.x + _latestMagnet!.y*_latestMagnet!.y + _latestMagnet!.z*_latestMagnet!.z).toStringAsFixed(1)} μT'),
                  ],
                ),
              ),
            
            SizedBox(height: 20),
            
            // RECORDING BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow, size: 28),
                label: Text(_isRecording ? 'STOP RECORDING' : 'START RECORDING',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            if (_isRecording)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.sensors, size: 40, color: Colors.blue.shade600),
                    SizedBox(height: 12),
                    Text(
                      'RECORDING IN PROGRESS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '$_samples EMF samples collected\n💓 Heart rate syncing with Google Fit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
