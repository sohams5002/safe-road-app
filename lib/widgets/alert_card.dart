import 'package:flutter/material.dart';

class AlertCard extends StatelessWidget {
  final String alertType;
  final String location;
  final String status;
  final String time;

  AlertCard({
    required this.alertType,
    required this.location,
    required this.status,
    required this.time, required image,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alertType,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            SizedBox(height: 8),
            Text("Location: $location", style: TextStyle(fontSize: 16)),
            SizedBox(height: 4),
            Text("Status: $status", style: TextStyle(fontSize: 16, color: Colors.blue)),
            SizedBox(height: 4),
            Text("Time: $time", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
