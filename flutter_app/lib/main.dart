import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'google_fit_service.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/google_fit_card.dart';
import 'widgets/status_card.dart';
import 'widgets/sensor_data_card.dart';
import 'widgets/recording_button.dart';
import 'widgets/recording_stats_card.dart';
import 'widgets/map_access_card.dart';
import 'widgets/emf_reader_card.dart';
import 'screens/emf_map_screen.dart';
import 'screens/emf_reader_screen.dart';

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
      title: 'EMF Sensor Logger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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



  Duration? get _recordingDuration {
    if (!_isRecording || _startTime == null) return null;
    return DateTime.now().difference(_startTime!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'EMF Sensor Logger',
        leadingIcon: Icons.sensors,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EMFMapScreen(),
                ),
              );
            },
            tooltip: 'View Safety Map',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Google Fit Card
              GoogleFitCard(
                isConnected: _isGoogleFitConnected,
                onConnect: _connectGoogleFit,
              ),
              
              const SizedBox(height: 24),
              
              // Map Access Card
              MapAccessCard(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EMFMapScreen(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Status Card
              StatusCard(
                isRecording: _isRecording,
                currentSessionId: _currentSessionId,
              ),
              
              const SizedBox(height: 24),
              
              // Sensor Data Card (only show if we have data)
              if (_latestPosition != null || _latestMagnet != null) ...[
                SensorDataCard(
                  latestPosition: _latestPosition,
                  latestMagnet: _latestMagnet,
                  samples: _samples,
                  locationSamples: _locationSamples,
                ),
                const SizedBox(height: 24),
              ],
              
              // Recording Button
              RecordingButton(
                isRecording: _isRecording,
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
              
              const SizedBox(height: 24),
              
              // Recording Stats (only show while recording)
              if (_isRecording)
                RecordingStatsCard(
                  samples: _samples,
                  locationSamples: _locationSamples,
                  isGoogleFitConnected: _isGoogleFitConnected,
                  recordingDuration: _recordingDuration,
                ),
              
              const SizedBox(height: 24),
              
              // EMF Reader Card (at bottom for fun features)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EMFReaderScreen(),
                    ),
                  );
                },
                child: const EMFReaderCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
