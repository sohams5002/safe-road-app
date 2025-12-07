import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'alerts.dart';
import 'sendpatientdetails.dart';
import 'nearby_hospitals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool loggedIn = prefs.getBool("ambulance_logged_in") ?? false;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: loggedIn ? AmbulanceHomePage() : AmbulanceLoginPage(),
  ));
}

// ------------------------------------------------------
// 🚑 LOGIN PAGE (HARDCODED LOGIN)
// ------------------------------------------------------
class AmbulanceLoginPage extends StatefulWidget {
  @override
  _AmbulanceLoginPageState createState() => _AmbulanceLoginPageState();
}

class _AmbulanceLoginPageState extends State<AmbulanceLoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // Hardcoded login credentials
  final Map<String, String> loginData = {
    "1001": "ambu123",
    "1002": "ambu456",
    "1003": "ambu789",
  };

  Future<void> login() async {
    String user = _userController.text.trim();
    String pass = _passController.text.trim();

    if (loginData.containsKey(user) && loginData[user] == pass) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("ambulance_logged_in", true);
      await prefs.setString("ambulance_userid", user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AmbulanceHomePage()),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Login Failed"),
          content: Text("Invalid ID or Password."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital, size: 90, color: Colors.white),
                  SizedBox(height: 30),
                  Text("Ambulance Login",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 40),

                  _field("User ID", _userController),
                  SizedBox(height: 20),
                  _field("Password", _passController, obscure: true),

                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text("Login",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        labelText: label,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

// ------------------------------------------------------
// 🚑 HOME PAGE
// ------------------------------------------------------
class AmbulanceHomePage extends StatelessWidget {
  Future<void> _openNearbyHospitals(BuildContext context) async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Enable GPS first")));
      return;
    }

    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Location permission denied")));
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => NearbyHospitalPage(
            userLat: pos.latitude,
            userLon: pos.longitude,
            userId: "ambulance_user",
          )),
    );
  }

  Future<void> logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("ambulance_logged_in", false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => AmbulanceLoginPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // block back button
      child: Scaffold(
        appBar: AppBar(title: Text("Ambulance Dashboard")),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _card(context, "Alerts", Icons.notifications, AlertsPage()),
              SizedBox(height: 20),
              _card(context, "Send Patient Details", Icons.medical_services,
                  SendPatientDetailsPage()),
              SizedBox(height: 20),

              GestureDetector(
                onTap: () => _openNearbyHospitals(context),
                child: _cardUI("Nearby Hospitals", Icons.local_hospital),
              ),

              Spacer(),
              ElevatedButton(
                onPressed: () => logout(context),
                child: Text("Logout"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext ctx, String title, IconData icon, Widget page) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => page)),
      child: _cardUI(title, icon),
    );
  }

  Widget _cardUI(String title, IconData icon) {
    return Card(
      elevation: 5,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:
          LinearGradient(colors: [Colors.redAccent, Colors.orange]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 50, color: Colors.white),
            SizedBox(width: 20),
            Text(title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
