import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'main.dart';

class ChartScreen extends StatelessWidget {
  final List<LocationDataPoint> locationPoints;
  final List<MagnetometerDataPoint> magnetPoints;
  const ChartScreen({Key? key, required this.locationPoints, required this.magnetPoints}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Data Charts'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        children: [
          const Text('Location Parameters vs. Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          locationPoints.isEmpty ? const Center(child: Text('No location data recorded.')) :
          SizedBox(
            height: 320,
            child: SfCartesianChart(
              legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
              primaryXAxis: NumericAxis(title: AxisTitle(text: 'Time (s)')),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <LineSeries<LocationDataPoint, double>>[
                LineSeries<LocationDataPoint, double>(
                  name: 'Latitude',
                  color: Colors.teal,
                  dataSource: locationPoints,
                  xValueMapper: (d, _) => d.seconds,
                  yValueMapper: (d, _) => d.latitude,
                ),
                LineSeries<LocationDataPoint, double>(
                  name: 'Longitude',
                  color: Colors.orange,
                  dataSource: locationPoints,
                  xValueMapper: (d, _) => d.seconds,
                  yValueMapper: (d, _) => d.longitude,
                ),
                LineSeries<LocationDataPoint, double>(
                  name: 'Altitude (m)',
                  color: Colors.blue,
                  dataSource: locationPoints,
                  xValueMapper: (d, _) => d.seconds,
                  yValueMapper: (d, _) => d.altitude,
                ),
                LineSeries<LocationDataPoint, double>(
                  name: 'Velocity (m/s)',
                  color: Colors.deepPurple,
                  dataSource: locationPoints,
                  xValueMapper: (d, _) => d.seconds,
                  yValueMapper: (d, _) => d.velocity,
                ),
                LineSeries<LocationDataPoint, double>(
                  name: 'Direction (°)',
                  color: Colors.green,
                  dataSource: locationPoints,
                  xValueMapper: (d, _) => d.seconds,
                  yValueMapper: (d, _) => d.direction,
                ),
                LineSeries<LocationDataPoint, double>(
                  name: 'Horiz. Accuracy',
                  color: Colors.red,
                  dataSource: locationPoints,
                  xValueMapper: (d, _) => d.seconds,
                  yValueMapper: (d, _) => d.horizAcc,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Magnetometer (µT) vs. Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          magnetPoints.isEmpty ? const Center(child: Text('No magnetometer data recorded.')) :
          SizedBox(
            height: 320,
            child: SfCartesianChart(
              legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
              primaryXAxis: NumericAxis(title: AxisTitle(text: 'Time (s)')),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <LineSeries<MagnetometerDataPoint, double>>[
                LineSeries<MagnetometerDataPoint, double>(
                  name: 'X (µT)', color: Colors.teal,
                  dataSource: magnetPoints,
                  xValueMapper: (d, _) => d.seconds, yValueMapper: (d, _) => d.x,
                ),
                LineSeries<MagnetometerDataPoint, double>(
                  name: 'Y (µT)', color: Colors.orange,
                  dataSource: magnetPoints,
                  xValueMapper: (d, _) => d.seconds, yValueMapper: (d, _) => d.y,
                ),
                LineSeries<MagnetometerDataPoint, double>(
                  name: 'Z (µT)', color: Colors.blue,
                  dataSource: magnetPoints,
                  xValueMapper: (d, _) => d.seconds, yValueMapper: (d, _) => d.z,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
