import 'package:flutter/material.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorDataCard extends StatelessWidget {
  final Position? latestPosition;
  final MagnetometerEvent? latestMagnet;
  final int samples;
  final int locationSamples;

  const SensorDataCard({
    Key? key,
    this.latestPosition,
    this.latestMagnet,
    required this.samples,
    required this.locationSamples,
  }) : super(key: key);

  double get _emfMagnitude {
    if (latestMagnet == null) return 0.0;
    return sqrt(latestMagnet!.x * latestMagnet!.x +
        latestMagnet!.y * latestMagnet!.y +
        latestMagnet!.z * latestMagnet!.z);
  }

  Color get _emfColor {
    final magnitude = _emfMagnitude;
    if (magnitude < 45) return Colors.green;
    if (magnitude < 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Sensor Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          
          // EMF Data
          if (latestMagnet != null) ...[
            _buildSensorRow(
              icon: Icons.electric_bolt,
              iconColor: _emfColor,
              title: 'EMF Magnitude',
              value: '${_emfMagnitude.toStringAsFixed(1)} μT',
              subtitle: 'X: ${latestMagnet!.x.toStringAsFixed(1)} Y: ${latestMagnet!.y.toStringAsFixed(1)} Z: ${latestMagnet!.z.toStringAsFixed(1)}',
            ),
            const SizedBox(height: 16),
          ],
          
          // Location Data
          if (latestPosition != null) ...[
            _buildSensorRow(
              icon: Icons.location_on,
              iconColor: Colors.blue,
              title: 'GPS Location',
              value: '${latestPosition!.latitude.toStringAsFixed(4)}, ${latestPosition!.longitude.toStringAsFixed(4)}',
              subtitle: 'Accuracy: ${latestPosition!.accuracy.toStringAsFixed(1)}m • Speed: ${(latestPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
            ),
            const SizedBox(height: 16),
          ],
          
          // Sample Counts
          Row(
            children: [
              Expanded(
                child: _buildCounterChip(
                  'EMF Samples',
                  samples.toString(),
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCounterChip(
                  'GPS Samples',
                  locationSamples.toString(),
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounterChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
