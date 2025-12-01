import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

class EMFReaderScreen extends StatefulWidget {
  const EMFReaderScreen({Key? key}) : super(key: key);

  @override
  State<EMFReaderScreen> createState() => _EMFReaderScreenState();
}

class _EMFReaderScreenState extends State<EMFReaderScreen>
    with TickerProviderStateMixin {
  double _currentReading = 0.0;
  bool _isScanning = false;
  Timer? _scanTimer;
  late AnimationController _pulseController;
  late AnimationController _needleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _needleAnimation;

  // EMF levels and colors matching the image
  final List<EMFLevel> _emfLevels = [
    EMFLevel(0.0, 1.5, Colors.teal.shade600, 'Safe'),
    EMFLevel(1.5, 2.5, Colors.green, 'Low'),
    EMFLevel(2.5, 10.0, Colors.yellow.shade600, 'Moderate'),
    EMFLevel(10.0, 30.0, Colors.orange, 'Elevated'),
    EMFLevel(30.0, double.infinity, Colors.red, 'High Risk'),
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _needleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _needleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _needleController,
      curve: Curves.elasticOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _pulseController.dispose();
    _needleController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });

    HapticFeedback.lightImpact();
    
    _scanTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      // Simulate EMF readings with some randomness
      final random = math.Random();
      final baseReading = random.nextDouble() * 25; // 0-25 mG
      final noise = (random.nextDouble() - 0.5) * 2; // ±1 mG noise
      
      setState(() {
        _currentReading = (baseReading + noise).clamp(0.0, 25.0);
      });

      _needleController.reset();
      _needleController.forward();

      // Add haptic feedback for high readings
      if (_currentReading > 25.0) {
        HapticFeedback.mediumImpact();
      } else if (_currentReading > 15.0) {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    
    _scanTimer?.cancel();
    HapticFeedback.lightImpact();
  }

  EMFLevel _getCurrentLevel() {
    return _emfLevels.firstWhere(
      (level) => _currentReading >= level.min && _currentReading < level.max,
      orElse: () => _emfLevels.last,
    );
  }

  Color _getCurrentLevelColor() {
    return _getCurrentLevel().color;
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _getCurrentLevel();
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Dark background like the device
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 28, color: Colors.white),
            const SizedBox(width: 12),
            const Text(
              'EMF Detector',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 5),
            
            // Device Frame
            Container(
              width: 250,
              height: 340,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF5A5A5A), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  
                  // Level Indicators (Top Lights)
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _emfLevels.map((level) {
                        final isActive = _currentReading >= level.min;
                        return Column(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: isActive ? 20 * _pulseAnimation.value : 20,
                                  height: isActive ? 20 * _pulseAnimation.value : 20,
                                  decoration: BoxDecoration(
                                    color: isActive 
                                        ? level.color
                                        : Colors.grey.shade700,
                                    shape: BoxShape.circle,
                                    boxShadow: isActive ? [
                                      BoxShadow(
                                        color: level.color.withOpacity(0.6),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ] : null,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              level.max == double.infinity 
                                  ? '${level.min.toInt()}+'
                                  : '${level.min}-${level.max}',
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.grey,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // Unit Label
                  const Text(
                    'MILLIGAUSS (mG)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Digital Display
                  Container(
                    width: 170,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade600),
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _needleAnimation,
                        builder: (context, child) {
                          return Text(
                            '${(_currentReading * _needleAnimation.value).toStringAsFixed(1)}',
                            style: TextStyle(
                              color: _getCurrentLevelColor(),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              shadows: [
                                Shadow(
                                  color: _getCurrentLevelColor().withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Unit
                  const Text(
                    'mG',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Status Text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentLevel.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: currentLevel.color, width: 1),
                    ),
                    child: Text(
                      currentLevel.label.toUpperCase(),
                      style: TextStyle(
                        color: currentLevel.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Power Button
                  GestureDetector(
                    onTap: _isScanning ? _stopScanning : _startScanning,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isScanning ? Colors.red.shade600 : Colors.green.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: (_isScanning ? Colors.red : Colors.green).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isScanning ? Icons.stop : Icons.power_settings_new,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isScanning ? 'SCANNING...' : 'TAP TO START',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Simulated EMF Detector',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fun simulation for demonstration purposes only.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }
}

class EMFLevel {
  final double min;
  final double max;
  final Color color;
  final String label;

  EMFLevel(this.min, this.max, this.color, this.label);
}
