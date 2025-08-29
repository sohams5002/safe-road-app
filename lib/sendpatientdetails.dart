import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendPatientDetailsPage extends StatefulWidget {
  @override
  _SendPatientDetailsPageState createState() => _SendPatientDetailsPageState();
}

class _SendPatientDetailsPageState extends State<SendPatientDetailsPage> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _conditionController = TextEditingController();

  Future<void> _sendPatientDetails() async {
    String patientId = _nameController.text.trim(); // Using name as the document ID
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference patients = firestore.collection("patient_details");

    // 🔹 Step 1: Remove any existing entry for the patient (Avoids duplicates)
    await patients.doc(patientId).delete().catchError((error) {
      print("Error deleting duplicate: $error");
    });

    // 🔹 Step 2: Add new patient details with a timestamp
    await patients.doc(patientId).set({
      "name": _nameController.text,
      "age": _ageController.text,
      "condition": _conditionController.text,
      "timestamp": FieldValue.serverTimestamp(), // Stores server timestamp
    });

    print("Patient Details Sent");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send Patient Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter Patient Details",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),
            _buildTextField("Name", _nameController),
            SizedBox(height: 20),
            _buildTextField("Age", _ageController),
            SizedBox(height: 20),
            _buildTextField("Condition", _conditionController),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _sendPatientDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                "Send Details",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
