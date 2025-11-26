import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleFitService {
  static const String _baseUrl = 'https://www.googleapis.com/fitness/v1';
  String? _accessToken;

  // Google Fit API scopes
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/fitness.activity.read',
    'https://www.googleapis.com/auth/fitness.body.read',
    'https://www.googleapis.com/auth/fitness.location.read',
  ];

  Future<bool> authenticate() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: _scopes,
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) return false;

      final GoogleSignInAuthentication auth = await account.authentication;
      _accessToken = auth.accessToken;

      return _accessToken != null;
    } catch (e) {
      print('Google Fit authentication error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getHeartRateData(
      DateTime startTime, DateTime endTime) async {
    if (_accessToken == null) return null;

    try {
      final url = '$_baseUrl/users/me/dataset:aggregate';
      final headers = {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

      final body = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.heart_rate.bpm',
          }
        ],
        'bucketByTime': {
          'durationMillis': 60000, // 1 minute buckets
        },
        'startTimeMillis': startTime.millisecondsSinceEpoch,
        'endTimeMillis': endTime.millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print(
            'Heart rate API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Heart rate data error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStepData(
      DateTime startTime, DateTime endTime) async {
    if (_accessToken == null) return null;

    try {
      final url = '$_baseUrl/users/me/dataset:aggregate';
      final headers = {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

      final body = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.step_count.delta',
          }
        ],
        'bucketByTime': {
          'durationMillis': 60000, // 1 minute buckets
        },
        'startTimeMillis': startTime.millisecondsSinceEpoch,
        'endTimeMillis': endTime.millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Step data API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Step data error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getHeartRatePoints(
      DateTime startTime, DateTime endTime) async {
    final data = await getHeartRateData(startTime, endTime);
    if (data == null) return [];

    List<Map<String, dynamic>> points = [];

    try {
      final buckets = data['bucket'] as List<dynamic>? ?? [];
      for (final bucket in buckets) {
        final dataset = bucket['dataset'] as List<dynamic>? ?? [];
        for (final ds in dataset) {
          final point = ds['point'] as List<dynamic>? ?? [];
          for (final p in point) {
            final value = p['value'] as List<dynamic>? ?? [];
            if (value.isNotEmpty) {
              final bpm = value[0]['fpVal'] as double? ?? 0.0;
              final timestamp = p['startTimeNanos'] as String? ?? '';

              if (bpm > 0 && timestamp.isNotEmpty) {
                points.add({
                  'timestamp': DateTime.fromMillisecondsSinceEpoch(
                    int.parse(timestamp) ~/ 1000000,
                  ).toIso8601String(),
                  'heartRate': bpm,
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing heart rate data: $e');
    }

    return points;
  }

  Future<List<Map<String, dynamic>>> getStepPoints(
      DateTime startTime, DateTime endTime) async {
    final data = await getStepData(startTime, endTime);
    if (data == null) return [];

    List<Map<String, dynamic>> points = [];

    try {
      final buckets = data['bucket'] as List<dynamic>? ?? [];
      for (final bucket in buckets) {
        final dataset = bucket['dataset'] as List<dynamic>? ?? [];
        for (final ds in dataset) {
          final point = ds['point'] as List<dynamic>? ?? [];
          for (final p in point) {
            final value = p['value'] as List<dynamic>? ?? [];
            if (value.isNotEmpty) {
              final steps = value[0]['intVal'] as int? ?? 0;
              final timestamp = p['startTimeNanos'] as String? ?? '';

              if (steps > 0 && timestamp.isNotEmpty) {
                points.add({
                  'timestamp': DateTime.fromMillisecondsSinceEpoch(
                    int.parse(timestamp) ~/ 1000000,
                  ).toIso8601String(),
                  'steps': steps,
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing step data: $e');
    }

    return points;
  }
}

