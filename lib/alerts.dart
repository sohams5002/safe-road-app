import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class AlertsPage extends StatefulWidget {
  @override
  _AlertsPageState createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final DatabaseReference alertsRef = FirebaseDatabase.instance.ref("alerts");
  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  void _fetchAlerts() {
    alertsRef.onValue.listen((event) {
      final alertData = event.snapshot.value as Map?;
      alerts.clear(); // Clear previous alerts to avoid duplicates
      if (alertData != null) {
        alertData.forEach((key, value) {
          final alert = Map<String, dynamic>.from(value);
          // Include accident_alert and human_safety_alert (adjust as needed)
          if (alert["type"] == "accident_alert" || alert["type"] == "human_safety_alert") {
            alerts.add({
              "alertType": alert["type"] == "accident_alert" ? "Accident Alert" : "Human Safety Alert",
              "location": "BBox: x1:${alert["bbox"]["x1"]}, y1:${alert["bbox"]["y1"]}, x2:${alert["bbox"]["x2"]}, y2:${alert["bbox"]["y2"]}",
              "details": "Confidence: ${(alert["confidence"] * 100).toStringAsFixed(2)}%\nTime: ${alert["timestamp"]}",
              "time": alert["timestamp"], // Kept for potential future use
              "image": alert["image"],    // Include image
            });
          }
        });
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ambulance Alerts 🚑')),
      body: alerts.isEmpty
          ? Center(child: Text("No emergency alerts."))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Column(
            children: [
              _buildAlertCard(
                alert["alertType"]!,
                alert["location"]!,
                alert["details"]!,
              ),
              if (alert["image"] != null) ...[
                SizedBox(height: 5),
                Image.memory(
                  base64Decode(alert["image"]),
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ],
              SizedBox(height: 10), // Space between alerts
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(String title, String location, String details) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.redAccent, Colors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Location: $location",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              details,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}