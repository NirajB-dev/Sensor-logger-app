import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../widgets/custom_app_bar.dart';

// EMF Cluster for spatial aggregation
class EMFCluster {
  final String gridKey;
  final LatLng centerPoint;
  double totalMagnitude = 0;
  int readingCount = 0;
  double maxMagnitude = 0;
  
  EMFCluster(this.gridKey, this.centerPoint);
  
  void addReading(double magnitude) {
    totalMagnitude += magnitude;
    readingCount++;
    maxMagnitude = math.max(maxMagnitude, magnitude);
  }
  
  double get averageMagnitude => readingCount > 0 ? totalMagnitude / readingCount : 0;
  
  // Use max magnitude for risk assessment, but consider density too
  double get riskScore => maxMagnitude * math.log(readingCount + 1) / 2;
}

class EMFMapScreen extends StatefulWidget {
  const EMFMapScreen({Key? key}) : super(key: key);

  @override
  State<EMFMapScreen> createState() => _EMFMapScreenState();
}

class _EMFMapScreenState extends State<EMFMapScreen> {
  final MapController _mapController = MapController();
  List<CircleMarker> _emfZones = [];
  List<Marker> _weatherMarkers = [];
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  int _totalSessions = 0;
  int _totalDataPoints = 0;
  
  // Layer visibility controls
  bool _showRoutes = false;
  bool _showWeather = false;
  bool _showEmfZones = true;
  double _emfOpacity = 0.3;
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _loadAllSessionsData();
  }

  Future<void> _loadAllSessionsData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load data from ALL users - no user limit for maximum data
      final usersRef = FirebaseDatabase.instance
          .ref()
          .child('users');

      final snapshot = await usersRef.get();
      
      if (snapshot.exists) {
        final allUsers = Map<String, dynamic>.from(snapshot.value as Map);
        
        List<LatLng> allRoutePoints = [];
        List<CircleMarker> allEmfZones = [];
        List<Marker> allWeatherMarkers = [];
        Map<String, EMFCluster> emfClusters = {}; // Grid-based clustering
        int sessionCount = 0;
        int dataPointCount = 0;
        int userCount = 0;
        
        // Process each user (limited to improve performance)
        for (final userEntry in allUsers.entries) {
          final userData = Map<String, dynamic>.from(userEntry.value);
          userCount++;
          
          // Check if user has sessions
          if (userData['sessions'] != null) {
            final userSessions = Map<String, dynamic>.from(userData['sessions']);
            
            // Process ALL sessions for maximum data coverage
            final sessionEntries = userSessions.entries.toList();
            for (final sessionEntry in sessionEntries) {
              final sessionData = Map<String, dynamic>.from(sessionEntry.value);
              sessionCount++;
          
          // Load location data for routes from this session (sample every 10th point for performance)
          if (sessionData['locationData'] != null) {
            final locations = Map<String, dynamic>.from(sessionData['locationData']);
            final sortedLocations = locations.values.toList()
              ..sort((a, b) => (a['seconds'] ?? 0).compareTo(b['seconds'] ?? 0));
            
            // Sample route points based on zoom level and total points
            final sampleRate = sortedLocations.length > 500 ? 5 : 
                              sortedLocations.length > 200 ? 3 : 2;
            
            for (int i = 0; i < sortedLocations.length; i += sampleRate) {
              final location = sortedLocations[i];
              if (location['latitude'] != null && location['longitude'] != null) {
                allRoutePoints.add(LatLng(
                  location['latitude'].toDouble(),
                  location['longitude'].toDouble(),
                ));
              }
            }
          }

          // Load magnetometer data and pair with locations from this session
          if (sessionData['magnetometerData'] != null && sessionData['locationData'] != null) {
            final magnetData = Map<String, dynamic>.from(sessionData['magnetometerData']);
            final locationData = Map<String, dynamic>.from(sessionData['locationData']);
            
            // Convert to sorted lists
            final sortedMagnet = magnetData.values.toList()
              ..sort((a, b) => (a['seconds'] ?? 0).compareTo(b['seconds'] ?? 0));
            final sortedLocations = locationData.values.toList()
              ..sort((a, b) => (a['seconds'] ?? 0).compareTo(b['seconds'] ?? 0));

            // Smart sampling of magnetometer data based on data density
            final magnetSampleRate = sortedMagnet.length > 1000 ? 4 : 
                                   sortedMagnet.length > 500 ? 3 : 2;
            
            for (int i = 0; i < sortedMagnet.length; i += magnetSampleRate) {
              final magnetPoint = sortedMagnet[i];
              final magnetTime = magnetPoint['seconds']?.toDouble() ?? 0.0;
              dataPointCount++;
              
              // Quick calculation of magnitude first to filter early
              final x = magnetPoint['x']?.toDouble() ?? 0.0;
              final y = magnetPoint['y']?.toDouble() ?? 0.0;
              final z = magnetPoint['z']?.toDouble() ?? 0.0;
              final magnitude = math.sqrt(x * x + y * y + z * z);
              
              // Process significant EMF readings and cluster them
              if (magnitude >= 25) { // Only process meaningful readings
                // Find nearest location point (within 3 seconds for better accuracy)
                dynamic nearestLocation;
                double minTimeDiff = double.infinity;
                
                for (final locationPoint in sortedLocations) {
                  final locationTime = locationPoint['seconds']?.toDouble() ?? 0.0;
                  final timeDiff = (magnetTime - locationTime).abs();
                  
                  if (timeDiff < minTimeDiff && timeDiff <= 3.0) {
                    minTimeDiff = timeDiff;
                    nearestLocation = locationPoint;
                  }
                }
                
                if (nearestLocation != null) {
                  final lat = nearestLocation['latitude']?.toDouble();
                  final lon = nearestLocation['longitude']?.toDouble();
                  
                  if (lat != null && lon != null) {
                    // Create grid-based clustering (approximately 100m grid cells)
                    final gridLat = (lat * 1000).round() / 1000; // ~111m resolution
                    final gridLon = (lon * 1500).round() / 1500; // ~74m resolution at Dublin latitude
                    final gridKey = '${gridLat}_${gridLon}';
                    
                    if (!emfClusters.containsKey(gridKey)) {
                      emfClusters[gridKey] = EMFCluster(gridKey, LatLng(gridLat, gridLon));
                    }
                    emfClusters[gridKey]!.addReading(magnitude);
                  }
                }
              }
            }
          }

          // Load ALL weather markers from this session
          if (sessionData['openWeather'] != null) {
            final weatherData = Map<String, dynamic>.from(sessionData['openWeather']);
            final weatherEntries = weatherData.values.toList();
            
            for (final weather in weatherEntries) {
              final lat = weather['lat']?.toDouble();
              final lon = weather['lon']?.toDouble();
              
              if (lat != null && lon != null) {
                allWeatherMarkers.add(Marker(
                  point: LatLng(lat, lon),
                  width: 30,
                  height: 30,
                  child: GestureDetector(
                    onTap: () => _showWeatherPopup(weather),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ));
              }
            }
          }
            } // End session loop
          } // End user sessions check
        } // End user loop

        // Convert EMF clusters to optimized zone markers
        for (final cluster in emfClusters.values) {
          if (cluster.readingCount >= 2) { // Only show areas with multiple readings
            final riskLevel = cluster.riskScore;
            allEmfZones.add(CircleMarker(
              point: cluster.centerPoint,
              radius: _getClusterRadius(cluster.readingCount, riskLevel),
              color: _getEMFColorFromRisk(riskLevel).withOpacity(_emfOpacity),
              borderColor: _getEMFColorFromRisk(riskLevel),
              borderStrokeWidth: riskLevel >= 60 ? 3 : riskLevel >= 45 ? 2 : 1,
            ));
          }
        }

        setState(() {
          _routePoints = allRoutePoints;
          _emfZones = allEmfZones;
          _weatherMarkers = allWeatherMarkers;
          _totalSessions = sessionCount;
          _totalDataPoints = dataPointCount;
        });
        
        print('✅ Optimized clustering: $userCount users, $sessionCount sessions → ${allEmfZones.length} EMF zones (from ${emfClusters.length} clusters), ${allRoutePoints.length} route points, ${allWeatherMarkers.length} weather markers');

        // Center map on Dublin or first location if available
        if (allRoutePoints.isNotEmpty) {
          // Calculate center of all points
          double sumLat = 0;
          double sumLon = 0;
          for (final point in allRoutePoints) {
            sumLat += point.latitude;
            sumLon += point.longitude;
          }
          final centerLat = sumLat / allRoutePoints.length;
          final centerLon = sumLon / allRoutePoints.length;
          _currentZoom = 12.0;
          _mapController.move(LatLng(centerLat, centerLon), _currentZoom);
        } else {
          _currentZoom = 13.0;
          _mapController.move(const LatLng(53.3498, -6.2603), _currentZoom); // Dublin
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading all sessions data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }



  double _getCircleRadius(double magnitude) {
    // Smaller, zoom-responsive circles to reduce clutter
    const double k = 0.8; // Reduced scale factor
    const double minRadius = 8.0;
    const double maxRadius = 25.0;
    
    // Make circles smaller at lower zoom levels
    double zoomFactor = (_currentZoom / 15.0).clamp(0.5, 1.5);
    
    return ((minRadius + (k * magnitude)) * zoomFactor).clamp(minRadius, maxRadius);
  }

  Color _getEMFColor(double magnitude) {
    if (magnitude < 30) return Colors.blue; // Very low readings
    if (magnitude < 45) return Colors.green; // Safe readings
    if (magnitude < 70) return Colors.orange; // Moderate risk
    return Colors.red; // High risk
  }

  // Optimized color function for clustered risk scores
  Color _getEMFColorFromRisk(double riskScore) {
    if (riskScore < 35) return Colors.green; // Safe zones
    if (riskScore < 50) return Colors.yellow; // Low-moderate risk
    if (riskScore < 75) return Colors.orange; // Moderate risk
    return Colors.red; // High risk zones
  }

  // Dynamic radius based on cluster density and risk
  double _getClusterRadius(int readingCount, double riskScore) {
    const double baseRadius = 50.0; // Larger base for zone coverage
    const double maxRadius = 150.0;
    
    // Scale by zoom for better visibility
    double zoomFactor = (_currentZoom / 13.0).clamp(0.7, 1.8);
    
    // Combine density and risk for radius calculation
    double densityFactor = math.log(readingCount) + 1;
    double riskFactor = math.sqrt(riskScore / 50);
    
    return ((baseRadius * densityFactor * riskFactor) * zoomFactor).clamp(30, maxRadius);
  }

  void _showWeatherPopup(dynamic weather) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weather Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperature: ${weather['temp']?.toStringAsFixed(1)}°C'),
            Text('Humidity: ${weather['humidity']}%'),
            Text('Wind: ${weather['wind_ms']?.toStringAsFixed(1)} m/s'),
            Text('Pressure: ${weather['pressure_hpa']} hPa'),
            Text('Condition: ${weather['cond']}'),
            Text('Time: ${weather['ts']?.substring(11, 19)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'EMF Map',
        leadingIcon: Icons.map,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'routes':
                    _showRoutes = !_showRoutes;
                    break;
                  case 'weather':
                    _showWeather = !_showWeather;
                    break;
                  case 'emf_zones':
                    _showEmfZones = !_showEmfZones;
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'emf_zones',
                child: Row(
                  children: [
                    Icon(_showEmfZones ? Icons.check_box : Icons.check_box_outline_blank),
                    const SizedBox(width: 8),
                    const Text('EMF Zones'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'routes',
                child: Row(
                  children: [
                    Icon(_showRoutes ? Icons.check_box : Icons.check_box_outline_blank),
                    const SizedBox(width: 8),
                    const Text('Routes'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'weather',
                child: Row(
                  children: [
                    Icon(_showWeather ? Icons.check_box : Icons.check_box_outline_blank),
                    const SizedBox(width: 8),
                    const Text('Weather'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllSessionsData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Compact Statistics Header with Layer Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Community EMF Safety',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            '${_emfZones.length} EMF zones • Zoom: ${_currentZoom.toStringAsFixed(1)}x',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Opacity Control
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.opacity, size: 16, color: Colors.grey),
                        SizedBox(
                          width: 60,
                          child: Slider(
                            value: _emfOpacity,
                            min: 0.1,
                            max: 0.8,
                            divisions: 7,
                            onChanged: (value) {
                              setState(() {
                                _emfOpacity = value;
                                _loadAllSessionsData(); // Refresh with new opacity
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF6366F1)),
                        SizedBox(height: 16),
                        Text('Loading map data...'),
                      ],
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(53.3498, -6.2603), // Dublin
                      initialZoom: 13.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            _currentZoom = position.zoom;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.emf_logger',
                      ),
                      
                      // Route polylines (show if enabled, regardless of zoom)
                      if (_showRoutes && _routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              strokeWidth: 1.5,
                            ),
                          ],
                        ),
                      
                      // EMF zones (only show high-risk zones)
                      if (_showEmfZones)
                        CircleLayer(circles: _emfZones),
                      
                      // Weather markers (show if enabled, regardless of zoom)
                      if (_showWeather)
                        MarkerLayer(markers: _weatherMarkers),
                    ],
                  ),
          ),
          
          // Compact Legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EMF Risk Levels',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      'Smart clustering: ${_emfZones.length} risk zones',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactLegendItem(Colors.green, 'Safe Zone', 'Low Risk'),
                    _buildCompactLegendItem(Colors.yellow, 'Caution', 'Moderate'),
                    _buildCompactLegendItem(Colors.orange, 'Warning', 'High Risk'),
                    _buildCompactLegendItem(Colors.red, 'Danger', 'Very High'),
                    if (_showRoutes) _buildCompactLegendItem(const Color(0xFF6366F1), 'Routes', 'Paths'),
                    if (_showWeather) _buildCompactLegendItem(Colors.blue, 'Weather', 'Data'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLegendItem(Color color, String title, String subtitle) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
