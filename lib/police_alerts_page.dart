import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/alert_card.dart';

class PoliceAlertsPage extends StatefulWidget {
  @override
  _PoliceAlertsPageState createState() => _PoliceAlertsPageState();
}

class _PoliceAlertsPageState extends State<PoliceAlertsPage> {
  final DatabaseReference alertsRef = FirebaseDatabase.instance.ref("alerts");

  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  void _fetchAlerts() {
    alertsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      alerts.clear(); // Clear previous alerts to avoid duplicates
      if (data != null) {
        data.forEach((key, value) {
          final alert = Map<String, dynamic>.from(value);
          alerts.add({
            "alertType": alert["type"] == "accident_alert" ? "Accident" : "Human Safety",
            "time": alert["timestamp"],
            "confidence": alert["confidence"].toString(),
            "bbox": "x1: ${alert["bbox"]["x1"]}, y1: ${alert["bbox"]["y1"]}, x2: ${alert["bbox"]["x2"]}, y2: ${alert["bbox"]["y2"]}",
            "image": alert["image"], // May be null for accident_alert
          });
        });
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Police Alerts 🚔")),
      body: alerts.isEmpty
          ? Center(child: Text("No alerts."))
          : ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return AlertCard(
            alertType: alert["alertType"]!,
            location: alert["bbox"]!, // Using bbox as location for now
            status: "Confidence: ${alert["confidence"]}",
            time: alert["time"]!,
            image: alert["image"], // Pass image if available
          );
        },
      ),
    );
  }
}