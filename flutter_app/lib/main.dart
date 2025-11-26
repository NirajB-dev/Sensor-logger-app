import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'google_fit_service.dart';

class LocationDataPoint {
  final double seconds,
      latitude,
      longitude,
      altitude,
      velocity,
      direction,
      horizAcc;
  LocationDataPoint(
      {required this.seconds,
      required this.latitude,
      required this.longitude,
      required this.altitude,
      required this.velocity,
      required this.direction,
      required this.horizAcc});
}

class MagnetometerDataPoint {
  final double seconds, x, y, z;
  MagnetometerDataPoint(
      {required this.seconds,
      required this.x,
      required this.y,
      required this.z});
}

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
      title: 'Optimal Sensor Logger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
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
  // Recording logic
  bool _isRecording = false;
  DateTime? _startTime;
  Timer? _timer;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  List<LocationDataPoint> locationHistory = [];
  List<MagnetometerDataPoint> magnetHistory = [];

  String? _locationError;
  String? _magnetometerError;

  // Live values
  Position? _latestPosition;
  MagnetometerEvent? _latestMagnet;

  int samples = 0;

  // Weather (Open-Meteo, no API key required)
  static const String _weatherProvider = 'open_meteo';
  DateTime? _lastWeatherFetch;
  Position? _lastWeatherPosition;

  // Firebase
  late DatabaseReference _databaseRef;
  String? _currentSessionId;
  String? _userId;

  // Google Fit
  final GoogleFitService _googleFitService = GoogleFitService();
  bool _isGoogleFitConnected = false;
  List<Map<String, dynamic>> _heartRateData = [];
  List<Map<String, dynamic>> _stepData = [];

  @override
  void initState() {
    super.initState();
    _databaseRef = FirebaseDatabase.instance.ref();
    _initializeAuthAndLocation();
  }

  Future<void> _initializeAuthAndLocation() async {
    // Ensure anonymous sign-in to get a stable userId
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        final cred = await auth.signInAnonymously();
        _userId = cred.user?.uid;
      } else {
        _userId = auth.currentUser?.uid;
      }
    } catch (e) {
      // leave _userId null; writes will be session scoped only
    }

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _locationError = 'Location permission denied.');
        return;
      }

      // Get initial position
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _latestPosition = position;
        _locationError = null;
      });
    } catch (e) {
      setState(() => _locationError = 'Location error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _magnetometerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Prevent double-starts
    if (_isRecording) return;
    // Ensure previous timers/subscriptions are cancelled
    _timer?.cancel();
    _timer = null;
    await _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      setState(() => _locationError = 'Location permission denied.');
      return;
    }
    // Create Firebase session
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final baseRef = _userId != null
        ? _databaseRef
            .child('users')
            .child(_userId!)
            .child('sessions')
            .child(_currentSessionId!)
        : _databaseRef.child('sessions').child(_currentSessionId!);
    await baseRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'recording',
      'locationData': <Map<String, dynamic>>[],
      'magnetometerData': <Map<String, dynamic>>[],
    });

    setState(() {
      _locationError = null;
      _magnetometerError = null;
      _isRecording = true;
      locationHistory.clear();
      magnetHistory.clear();
      samples = 0;
      _startTime = DateTime.now();
    });
    // Fetch initial weather snapshot immediately (best-effort)
    try {
      final initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      await _maybeFetchAndStoreWeather(initialPos);
    } catch (_) {}
    // Start location polling
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isRecording) return; // extra safety
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);
        final nowS =
            DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
        final locationPoint = LocationDataPoint(
          seconds: nowS,
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          velocity: pos.speed,
          direction: pos.heading,
          horizAcc: pos.accuracy,
        );

        setState(() {
          _latestPosition = pos;
          locationHistory.add(locationPoint);
          samples++;
          print('Location data added: ${locationHistory.length} total');
        });

        // Weather polling: every 60s or moved > 100m
        await _maybeFetchAndStoreWeather(pos);

        // Upload to Firebase in real-time
        if (_currentSessionId != null) {
          final locRef = _userId != null
              ? _databaseRef
                  .child('users')
                  .child(_userId!)
                  .child('sessions')
                  .child(_currentSessionId!)
                  .child('locationData')
              : _databaseRef
                  .child('sessions')
                  .child(_currentSessionId!)
                  .child('locationData');
          await locRef.push().set({
            'seconds': locationPoint.seconds,
            'latitude': locationPoint.latitude,
            'longitude': locationPoint.longitude,
            'altitude': locationPoint.altitude,
            'velocity': locationPoint.velocity,
            'direction': locationPoint.direction,
            'horizAcc': locationPoint.horizAcc,
          });
        }
      } catch (e) {
        setState(() {
          _locationError = 'Location error: $e';
        });
      }
    });
    // Start magnetometer
    _magnetometerSubscription = magnetometerEvents.listen((event) async {
      if (!_isRecording) return; // ignore events after stop
      final nowS =
          DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
      final magnetPoint = MagnetometerDataPoint(
          seconds: nowS, x: event.x, y: event.y, z: event.z);

      setState(() {
        _latestMagnet = event;
        magnetHistory.add(magnetPoint);
        print('Magnetometer data added: ${magnetHistory.length} total');
      });

      // Upload to Firebase in real-time
      if (_currentSessionId != null) {
        final magRef = _userId != null
            ? _databaseRef
                .child('users')
                .child(_userId!)
                .child('sessions')
                .child(_currentSessionId!)
                .child('magnetometerData')
            : _databaseRef
                .child('sessions')
                .child(_currentSessionId!)
                .child('magnetometerData');
        await magRef.push().set({
          'seconds': magnetPoint.seconds,
          'x': magnetPoint.x,
          'y': magnetPoint.y,
          'z': magnetPoint.z,
        });
      }
    });
  }

  Future<void> _connectGoogleFit() async {
    try {
      _isGoogleFitConnected = await _googleFitService.authenticate();
      if (_isGoogleFitConnected) {
        print('Google Fit connected successfully');
      } else {
        print('Google Fit connection failed');
      }
    } catch (e) {
      print('Google Fit error: $e');
      _isGoogleFitConnected = false;
    }
  }

  Future<void> _fetchGoogleFitData() async {
    if (!_isGoogleFitConnected || _currentSessionId == null) return;

    try {
      final sessionStart = DateTime.now().subtract(Duration(minutes: 30));
      final sessionEnd = DateTime.now();

      // Fetch heart rate data
      final heartRatePoints =
          await _googleFitService.getHeartRatePoints(sessionStart, sessionEnd);
      _heartRateData = heartRatePoints;

      // Fetch step data
      final stepPoints =
          await _googleFitService.getStepPoints(sessionStart, sessionEnd);
      _stepData = stepPoints;

      // Upload to Firebase
      if (_userId != null && _currentSessionId != null) {
        final baseRef = _databaseRef
            .child('users')
            .child(_userId!)
            .child('sessions')
            .child(_currentSessionId!);

        await baseRef.child('googleFit').set({
          'heartRate': _heartRateData,
          'steps': _stepData,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        print(
            'Google Fit data uploaded: ${_heartRateData.length} HR points, ${_stepData.length} step points');
      }
    } catch (e) {
      print('Error fetching Google Fit data: $e');
    }
  }

  Future<void> _maybeFetchAndStoreWeather(Position current) async {
    final now = DateTime.now();
    final timeOk = _lastWeatherFetch == null ||
        now.difference(_lastWeatherFetch!).inSeconds >= 60;
    final distOk = _lastWeatherPosition == null ||
        Geolocator.distanceBetween(
                _lastWeatherPosition!.latitude,
                _lastWeatherPosition!.longitude,
                current.latitude,
                current.longitude) >
            100.0;
    if (!timeOk && !distOk) return;

    // Open-Meteo current weather endpoint
    final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${current.latitude}&longitude=${current.longitude}&current=temperature_2m,relative_humidity_2m,pressure_msl,wind_speed_10m,wind_direction_10m,precipitation,cloud_cover&timezone=auto');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final cur = (data['current'] ?? {}) as Map<String, dynamic>;
        final weatherRecord = {
          'provider': _weatherProvider,
          'ts': DateTime.now().toIso8601String(),
          'lat': current.latitude,
          'lon': current.longitude,
          'temp': cur['temperature_2m'],
          'humidity': cur['relative_humidity_2m'],
          'pressure_hpa': cur['pressure_msl'],
          'wind_ms': cur['wind_speed_10m'],
          'wind_deg': cur['wind_direction_10m'],
          'rain_1h_mm': cur['precipitation'],
          'clouds_pct': cur['cloud_cover'],
        };
        if (_currentSessionId != null) {
          final wRef = _userId != null
              ? _databaseRef
                  .child('users')
                  .child(_userId!)
                  .child('sessions')
                  .child(_currentSessionId!)
                  .child('openWeather')
              : _databaseRef
                  .child('sessions')
                  .child(_currentSessionId!)
                  .child('openWeather');
          await wRef.push().set(weatherRecord);
          // debug log
          // ignore: avoid_print
          print('Weather snapshot uploaded: $weatherRecord');
        }
        _lastWeatherFetch = now;
        _lastWeatherPosition = current;
      } else {
        // ignore: avoid_print
        print('Weather HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Weather fetch error: $e');
    }
  }

  void _stopRecording() async {
    // Flip flag first so any in-flight callbacks are ignored
    setState(() {
      _isRecording = false;
    });
    _timer?.cancel();
    _timer = null;
    await _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;

    // Update Firebase session status
    if (_currentSessionId != null) {
      final sessionRef = _userId != null
          ? _databaseRef
              .child('users')
              .child(_userId!)
              .child('sessions')
              .child(_currentSessionId!)
          : _databaseRef.child('sessions').child(_currentSessionId!);
      await sessionRef.update({
        'status': 'completed',
        'endTime': DateTime.now().toIso8601String(),
        'totalSamples': samples,
      });
      // Clear session id to stop any further uploads
      setState(() {
        _currentSessionId = null;
      });
    }
  }

  Future<void> _exportCsv() async {
    if (locationHistory.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }
    List<List<dynamic>> rows = [];
    rows.add([
      'Time (s)',
      'Latitude',
      'Longitude',
      'Altitude (m)',
      'Velocity (m/s)',
      'Direction (°)',
      'Horiz Accuracy (m)',
      'Mag X (μT)',
      'Mag Y (μT)',
      'Mag Z (μT)',
      'Temp (C)',
      'Humidity (%)',
      'Pressure (hPa)',
      'Wind (m/s)',
      'Wind Dir (°)',
      'Rain 1h (mm)',
      'Clouds (%)'
    ]);
    int magIdx = 0;
    for (final loc in locationHistory) {
      double? magX, magY, magZ;
      while (magIdx + 1 < magnetHistory.length &&
          magnetHistory[magIdx + 1].seconds <= loc.seconds) {
        magIdx++;
      }
      if (magIdx < magnetHistory.length) {
        magX = magnetHistory[magIdx].x;
        magY = magnetHistory[magIdx].y;
        magZ = magnetHistory[magIdx].z;
      }
      rows.add([
        loc.seconds.toStringAsFixed(2),
        loc.latitude,
        loc.longitude,
        loc.altitude,
        loc.velocity,
        loc.direction,
        loc.horizAcc,
        magX,
        magY,
        magZ,
        null, // temp (fill in analysis by matching nearest weather ts)
        null, // humidity
        null, // pressure
        null, // wind speed
        null, // wind dir
        null, // rain 1h
        null // clouds
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    try {
      // Use app documents directory (more reliable)
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/sensor_log_$timestamp.csv');
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'CSV saved!\nFile: sensor_log_$timestamp.csv\nPath: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Optimal Sensor Logger'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Firebase Status Card
                Card(
                  color: _currentSessionId != null
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          _currentSessionId != null
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: _currentSessionId != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          _currentSessionId != null
                              ? 'Firebase: User: ${_userId?.substring(0, 6) ?? 'anon'} · Session: ${_currentSessionId!.substring(0, 8)}'
                              : 'Firebase: ${_userId != null ? 'Signed-in' : 'Disconnected'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currentSessionId != null
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Location Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Live Location',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 10),
                        if (_locationError != null)
                          Text(_locationError!,
                              style: const TextStyle(color: Colors.red)),
                        if (_latestPosition != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Latitude: ${_latestPosition!.latitude.toStringAsFixed(6)}'),
                              Text(
                                  'Longitude: ${_latestPosition!.longitude.toStringAsFixed(6)}'),
                              Text(
                                  'Altitude: ${_latestPosition!.altitude.toStringAsFixed(2)} m'),
                              Text(
                                  'Velocity: ${_latestPosition!.speed.toStringAsFixed(2)} m/s'),
                              Text(
                                  'Direction: ${_latestPosition!.heading.toStringAsFixed(2)} °'),
                              Text(
                                  'Horiz. Acc.: ${_latestPosition!.accuracy.toStringAsFixed(2)} m'),
                            ],
                          ),
                        if (_latestPosition == null && _locationError == null)
                          const Text('Fetching location...'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Magnetometer Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Live Magnetometer',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 10),
                        if (_latestMagnet != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'X: ${_latestMagnet!.x.toStringAsFixed(2)} μT'),
                              Text(
                                  'Y: ${_latestMagnet!.y.toStringAsFixed(2)} μT'),
                              Text(
                                  'Z: ${_latestMagnet!.z.toStringAsFixed(2)} μT'),
                            ],
                          ),
                        if (_latestMagnet == null)
                          const Text('Waiting for sensor data...'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Start/Stop Button
                SizedBox(
                  width: double.infinity,
                  child: _isRecording
                      ? ElevatedButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Recording'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48)),
                        )
                      : ElevatedButton.icon(
                          onPressed: _startRecording,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                        ),
                ),
                const SizedBox(height: 16),
                // Google Fit Buttons
                ElevatedButton.icon(
                  onPressed: _connectGoogleFit,
                  icon: Icon(_isGoogleFitConnected ? Icons.check : Icons.link),
                  label: Text(_isGoogleFitConnected
                      ? 'Google Fit Connected'
                      : 'Connect Google Fit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isGoogleFitConnected ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _fetchGoogleFitData,
                  icon: const Icon(Icons.favorite),
                  label: const Text('Fetch Health Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),
                // Status Text
                if (_isRecording)
                  Text('Recording: $samples samples',
                      style: const TextStyle(
                          color: Colors.teal, fontWeight: FontWeight.w600))
                else
                  Column(
                    children: [
                      Text('Location data: ${locationHistory.length} points',
                          style: const TextStyle(fontSize: 12)),
                      Text('Magnetometer data: ${magnetHistory.length} points',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                const SizedBox(height: 20),
                // Action Buttons (stacked to avoid horizontal overflow)
                ElevatedButton.icon(
                  icon: const Icon(Icons.show_chart),
                  label: const Text('View Charts'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChartScreen(
                          locationPoints: locationHistory,
                          magnetPoints: magnetHistory,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  onPressed: _exportCsv,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
