import 'package:flutter/material.dart';

class RecordingStatsCard extends StatelessWidget {
  final int samples;
  final int locationSamples;
  final bool isGoogleFitConnected;
  final Duration? recordingDuration;

  const RecordingStatsCard({
    Key? key,
    required this.samples,
    required this.locationSamples,
    required this.isGoogleFitConnected,
    this.recordingDuration,
  }) : super(key: key);

  String get _formatDuration {
    if (recordingDuration == null) return '00:00';
    final minutes = recordingDuration!.inMinutes;
    final seconds = recordingDuration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.indigo.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Recording Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Duration
          if (recordingDuration != null) ...[
            _buildStatRow(
              icon: Icons.timer,
              label: 'Recording Time',
              value: _formatDuration,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
          ],
          
          // Sample counts in a grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.electric_bolt,
                  label: 'EMF Samples',
                  value: samples.toString(),
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.location_on,
                  label: 'GPS Samples',
                  value: locationSamples.toString(),
                  color: Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Google Fit Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isGoogleFitConnected ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGoogleFitConnected ? Colors.green.shade200 : Colors.orange.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isGoogleFitConnected ? Icons.favorite : Icons.heart_broken,
                  color: isGoogleFitConnected ? Colors.green.shade600 : Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isGoogleFitConnected 
                        ? '💓 Heart rate syncing with Google Fit'
                        : '⚠️ Google Fit not connected - heart rate unavailable',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isGoogleFitConnected ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
