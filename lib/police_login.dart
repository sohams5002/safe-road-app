import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'police_alerts_page.dart';

/// Key used in SharedPreferences
const String _kPoliceLoggedInKey = 'police_logged_in';

/// Helper: check from anywhere if police is logged in
Future<bool> isPoliceLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPoliceLoggedInKey) ?? false;
}

/// Helper: clear police session (used from logout)
Future<void> clearPoliceSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPoliceLoggedInKey, false);
}

/// Login page widget (route: 'police')
class PoliceLoginPage extends StatefulWidget {
  const PoliceLoginPage({super.key});

  @override
  State<PoliceLoginPage> createState() => _PoliceLoginPageState();
}

class _PoliceLoginPageState extends State<PoliceLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _checkingSession = true;

  // Hardcoded username and password
  final String _validUsername = 'police@city.com';
  final String _validPassword = 'police123';

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// If already logged in, skip login screen and go straight to alerts
  Future<void> _checkExistingSession() async {
    final loggedIn = await isPoliceLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      _openAlertsAndLockBack();
    } else {
      setState(() => _checkingSession = false);
    }
  }

  /// Save session & redirect to PoliceAlertsPage
  Future<void> _login() async {
    if (_emailController.text == _validUsername &&
        _passwordController.text == _validPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPoliceLoggedInKey, true);

      if (!mounted) return;
      _openAlertsAndLockBack();
    } else {
      _showErrorDialog();
    }
  }

  /// Navigate to alerts page and remove login from stack
  void _openAlertsAndLockBack() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PoliceAlertsPage()),
          (route) => false, // remove all previous routes
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Login Failed"),
          content: const Text("Invalid username or password."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      // Small splash while checking SharedPreferences
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.blueGrey],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_police,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    "Police Login",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField("Email", _emailController),
                  const SizedBox(height: 20),
                  _buildTextField("Password", _passwordController,
                      obscureText: true),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Colors.indigo,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String hint,
      TextEditingController controller, {
        bool obscureText = false,
      }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// Optional: old PoliceHomePage isn’t needed anymore, but keeping it here
/// in case you still want a simple dashboard elsewhere.
class PoliceHomePage extends StatelessWidget {
  const PoliceHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Police Dashboard')),
      body: const Center(
        child: Text("Welcome Police Officer", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
