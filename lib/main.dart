import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

// Import your login pages
import 'ambulance_login.dart';
import 'hospital_login.dart';
import 'police_login.dart';
import 'fire_brigade_login.dart';
import 'public_user_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  await deleteOldPatientRecords(); // Cleanup Firestore on app start
  runApp(MyApp());
}

// 🔥 Function to delete patient records older than 12 hours
Future<void> deleteOldPatientRecords() async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference patients = firestore.collection("patient_details");

    QuerySnapshot querySnapshot = await patients.get();
    DateTime now = DateTime.now();

    for (var doc in querySnapshot.docs) {
      Timestamp timestamp = doc["timestamp"];
      DateTime recordTime = timestamp.toDate();

      if (now.difference(recordTime).inHours >= 12) {
        await patients.doc(doc.id).delete();
        print("🔥 Deleted old patient record: ${doc.id}");
      }
    }
  } catch (e) {
    print("Failed to delete old patient records: $e"); // Log error, don’t crash
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
      ),
      home: HomePage(),
      routes: {
        'ambulance': (context) => AmbulanceLoginPage(),
        'hospital': (context) => HospitalLoginPage(),
        'police': (context) => PoliceLoginPage(),
        'fire_brigade': (context) => FireBrigadeLoginPage(),
        'public_user': (context) => PublicHomePage(),
      },
    );
  }
}

// Rest of your HomePage class remains unchanged
class HomePage extends StatelessWidget {
  final List<Map<String, dynamic>> modules = [
    {
      "title": "Ambulance",
      "image": "assets/images/ambulance.png",
      "gradient": [Colors.redAccent, Colors.deepOrange],
      "route": 'ambulance',
    },
    {
      "title": "Hospital",
      "image": "assets/images/hospital.png",
      "gradient": [Colors.blueAccent, Colors.lightBlue],
      "route": 'hospital',
    },
    {
      "title": "Police",
      "image": "assets/images/police.png",
      "gradient": [Colors.indigo, Colors.blueGrey],
      "route": 'police',
    },
    {
      "title": "Fire Brigade",
      "image": "assets/images/fire_brigade.png",
      "gradient": [Colors.deepOrange, Colors.red],
      "route": 'fire_brigade',
    },
    {
      "title": "Public User",
      "image": "assets/images/public.png",
      "gradient": [Colors.green, Colors.teal],
      "route": 'public_user',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            return _buildModuleCard(
              context,
              title: modules[index]["title"],
              imagePath: modules[index]["image"],
              gradientColors: modules[index]["gradient"],
              routeName: modules[index]["route"],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context,
      {required String title,
        required String imagePath,
        required List<Color> gradientColors,
        required String routeName}) {
    return GestureDetector(
      onTap: () => _navigateTo(context, routeName),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              spreadRadius: 2,
              offset: Offset(4, 4),
            ),
          ],
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black45, blurRadius: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }
}