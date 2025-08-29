import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/alert_card.dart';
import 'dart:convert';

class HospitalAlertsPage extends StatefulWidget {
  @override
  _HospitalAlertsPageState createState() => _HospitalAlertsPageState();
}

class _HospitalAlertsPageState extends State<HospitalAlertsPage> {
  final DatabaseReference alertsRef = FirebaseDatabase.instance.ref("alerts");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hospital Alerts 🚑")),
      body: StreamBuilder(
        stream: alertsRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text("No alerts available."));
          }

          final data = snapshot.data!.snapshot.value as Map;
          List<Map<String, dynamic>> alerts = [];

          data.forEach((key, value) {
            final alert = Map<String, dynamic>.from(value);
            // Filter for hospital-relevant alerts (accident_alert and human_safety_alert)
            if (alert["type"] == "accident_alert" || alert["type"] == "human_safety_alert") {
              alerts.add({
                "alertType": alert["type"] == "accident_alert" ? "Accident" : "Human Safety",
                "location": "BBox: x1:${alert["bbox"]["x1"]}, y1:${alert["bbox"]["y1"]}, x2:${alert["bbox"]["x2"]}, y2:${alert["bbox"]["y2"]}",
                "time": alert["timestamp"],
                "status": "Confidence: ${(alert["confidence"] * 100).toStringAsFixed(2)}%",
                "image": alert["image"], // Optional image field
              });
            }
          });

          if (alerts.isEmpty) {
            return Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No hospital-related alerts available.")));
          }

          return ListView.builder(
            padding: EdgeInsets.all(10),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
          );
        },
      ),
    );
  }
}