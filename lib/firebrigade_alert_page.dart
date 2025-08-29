import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/alert_card.dart';
import 'dart:convert';

class FireBrigadeAlertsPage extends StatefulWidget {
  @override
  _FireBrigadeAlertsPageState createState() => _FireBrigadeAlertsPageState();
}

class _FireBrigadeAlertsPageState extends State<FireBrigadeAlertsPage> {
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
          // Filter for accident_alert (and optionally others if relevant)
          if (alert["type"] == "accident_alert") {
            alerts.add({
              "alertType": "Accident",
              "location": "BBox: x1:${alert["bbox"]["x1"]}, y1:${alert["bbox"]["y1"]}, x2:${alert["bbox"]["x2"]}, y2:${alert["bbox"]["y2"]}",
              "time": alert["timestamp"],
              "status": "Confidence: ${(alert["confidence"] * 100).toStringAsFixed(2)}%",
              "image": alert["image"], // Include image
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
      appBar: AppBar(title: Text("Fire Brigade Alerts 🔥")),
      body: alerts.isEmpty
          ? Center(child: Text("No accident alerts for fire brigade."))
          : ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Column(
            children: [
              AlertCard(
                alertType: alert["alertType"]!,
                location: alert["location"]!,
                status: alert["status"]!,
                time: alert["time"]!,
                image: null,
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
}