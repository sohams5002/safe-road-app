// --------------------------------------------------------
// IMPORTS
// --------------------------------------------------------
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'police_login.dart';

// --------------------------------------------------------
// SOS MODEL
// --------------------------------------------------------
class SosAlert {
  final String id;
  final String device;
  final String time;
  final double lat;
  final double lon;
  final String frontVideo;
  final String rearVideo;
  String location = "Loading...";

  Uint8List? frontThumb;
  Uint8List? rearThumb;

  SosAlert({
    required this.id,
    required this.device,
    required this.time,
    required this.lat,
    required this.lon,
    required this.frontVideo,
    required this.rearVideo,
  });
}

// --------------------------------------------------------
// POLICE ALERTS PAGE
// --------------------------------------------------------
class PoliceAlertsPage extends StatefulWidget {
  const PoliceAlertsPage({super.key});

  @override
  State<PoliceAlertsPage> createState() => _PoliceAlertsPageState();
}

class _PoliceAlertsPageState extends State<PoliceAlertsPage>
    with WidgetsBindingObserver {
  final DatabaseReference alertsRef =
  FirebaseDatabase.instance.ref("police_alerts");

  final FlutterLocalNotificationsPlugin _notif =
  FlutterLocalNotificationsPlugin();

  List<SosAlert> all = [];
  bool loading = true;
  String cameraFilter = "All";
  bool sortLatestFirst = true;

  bool _mapOpened = false;
  SosAlert? _returnAlert;

  Timer? _respTimer;
  bool _showRespBtn = false;

  Set<String> notified = {};

  String? _policeDeviceId;

  // --------------------------------------------------------
  // INIT
  // --------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadDeviceId();
    _setupNotifications();
    _listenAlerts();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _policeDeviceId = prefs.getString("police_device_id");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _respTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------
  // WHEN RETURNING FROM GOOGLE MAPS
  // --------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    super.didChangeAppLifecycleState(s);

    if (s == AppLifecycleState.resumed) {
      if (_mapOpened && _returnAlert != null) {
        _startResponseTimer(_returnAlert!.id);

        _mapOpened = false;
        _returnAlert = null;
      }
    }
  }

  // --------------------------------------------------------
  // INITIALIZE DEVICE NOTIFICATION CHANNEL
  // --------------------------------------------------------
  Future<void> _setupNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notif.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      "sos_channel",
      "SOS Alerts",
      description: "SOS alert notifications",
      importance: Importance.max,
      playSound: true,
    );

    await _notif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // --------------------------------------------------------
  // SHOW NOTIFICATION (ONLY ON LOGGED IN DEVICE)
  // --------------------------------------------------------
  Future<void> _sendDeviceNotification(SosAlert a) async {
    if (_policeDeviceId == null) return;

    final androidDetails = AndroidNotificationDetails(
      "sos_channel",
      "SOS Alerts",
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _notif.show(
      a.id.hashCode,
      "🚨 New SOS Alert!",
      "${a.device} • ${a.location}",
      NotificationDetails(android: androidDetails),
    );
  }

  // --------------------------------------------------------
  // LISTEN FOR NEW ALERTS
  // --------------------------------------------------------
  void _listenAlerts() {
    alertsRef.onValue.listen((event) async {
      final previousIds = all.map((e) => e.id).toSet();

      final data = event.snapshot.value as Map?;
      all.clear();

      if (data != null) {
        for (var e in data.entries) {
          final map = Map<String, dynamic>.from(e.value);

          final alert = SosAlert(
            id: e.key,
            device: map["device"],
            time: map["timestamp"],
            lat: (map["lat"] as num).toDouble(),
            lon: (map["lon"] as num).toDouble(),
            frontVideo: map["frontVideo"],
            rearVideo: map["rearVideo"],
          );

          alert.location = await _reverse(alert.lat, alert.lon);

          all.add(alert);
        }
      }

      final newOnes =
      all.where((a) => !previousIds.contains(a.id)).toList();

      for (var n in newOnes) {
        if (!notified.contains(n.id)) {
          notified.add(n.id);

          await _sendDeviceNotification(n);
          _vibrate();
        }
      }

      for (var a in all) {
        _genThumbs(a);
      }

      _sortAlerts();

      setState(() => loading = false);
    });
  }

  // --------------------------------------------------------
  // VIBRATION
  // --------------------------------------------------------
  void _vibrate() async {
    if ((await Vibration.hasVibrator()) ?? false) {
      Vibration.vibrate(pattern: [0, 800, 300, 800], amplitude: 255);
    }
  }

  void _stopVibration() async {
    if ((await Vibration.hasVibrator()) ?? false) {
      Vibration.cancel();
    }
  }

  // --------------------------------------------------------
  // REVERSE GEOCODING
  // --------------------------------------------------------
  Future<String> _reverse(double lat, double lon) async {
    try {
      final p = await placemarkFromCoordinates(lat, lon);
      final place = p.first;
      return "${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}";
    } catch (_) {
      return "Unknown";
    }
  }

  // --------------------------------------------------------
  // LOGOUT
  // --------------------------------------------------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("police_logged_in");
    await prefs.remove("police_device_id");

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PoliceLoginPage()),
          (_) => false,
    );
  }

  // --------------------------------------------------------
  // GOOGLE MAPS LAUNCH + DELAY TIMER
  // --------------------------------------------------------
  Future<void> _openMap(SosAlert a) async {
    _stopVibration();

    final geo =
    Uri.parse("geo:${a.lat},${a.lon}?q=${a.lat},${a.lon}(SOS Alert)");

    if (await canLaunchUrl(geo)) {
      _mapOpened = true;
      _returnAlert = a;

      await launchUrl(geo, mode: LaunchMode.externalApplication);
    }
  }

  // --------------------------------------------------------
  // START RESPONSE TIMER AFTER RETURNING TO APP
  // --------------------------------------------------------
  void _startResponseTimer(String id) {
    setState(() => _showRespBtn = true);

    _respTimer = Timer(const Duration(seconds: 10), () async {
      await alertsRef.child(id).remove();
      setState(() => _showRespBtn = false);
    });
  }

  // --------------------------------------------------------
  // NOT RESPONDED
  // --------------------------------------------------------
  void _markNotResponded() {
    _respTimer?.cancel();
    setState(() => _showRespBtn = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alert marked as NOT Responded")),
    );
  }

  // --------------------------------------------------------
  // SORTING
  // --------------------------------------------------------
  void _sortAlerts() {
    all.sort((a, b) => sortLatestFirst
        ? b.time.compareTo(a.time)
        : a.time.compareTo(b.time));
  }

  // --------------------------------------------------------
  // THUMBNAILS
  // --------------------------------------------------------
  Future<void> _genThumbs(SosAlert a) async {
    if (a.frontVideo.isNotEmpty && a.frontThumb == null) {
      a.frontThumb = await _thumbFromUrl(a.frontVideo);
    }
    if (a.rearVideo.isNotEmpty && a.rearThumb == null) {
      a.rearThumb = await _thumbFromUrl(a.rearVideo);
    }
    setState(() {});
  }

  Future<Uint8List?> _thumbFromUrl(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final dir = await getTemporaryDirectory();
    final filePath = "${dir.path}/${DateTime.now().microsecondsSinceEpoch}.mp4";
    final file = File(filePath)..writeAsBytesSync(res.bodyBytes);

    return await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 60,
    );
  }

  // --------------------------------------------------------
  // UI BUILD
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("SOS Alerts"),
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            )
          ],
        ),
        body: Stack(
          children: [
            loading
                ? const Center(child: CircularProgressIndicator())
                : _alertsList(),

            if (_showRespBtn)
              Positioned(
                bottom: 25,
                left: 20,
                right: 20,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(15),
                  ),
                  onPressed: _markNotResponded,
                  child: const Text(
                    "Mark as NOT Responded",
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // ALERTS LIST
  // --------------------------------------------------------
  Widget _alertsList() {
    return ListView.builder(
      itemCount: all.length,
      itemBuilder: (_, i) {
        final a = all[i];
        return _alertCard(a);
      },
    );
  }

  // --------------------------------------------------------
  // SINGLE ALERT CARD
  // --------------------------------------------------------
  Widget _alertCard(SosAlert a) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.device,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(a.time, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),

            Text("📍 ${a.location}",
                style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),

            Row(
              children: [
                _thumb("Front", a.frontThumb, a.frontVideo),
                const SizedBox(width: 10),
                _thumb("Rear", a.rearThumb, a.rearVideo),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _playBtn("Front", a.frontVideo)),
                const SizedBox(width: 10),
                Expanded(child: _playBtn("Rear", a.rearVideo)),
                const SizedBox(width: 10),

                InkWell(
                  onTap: () => _openMap(a),
                  child: const Row(
                    children: [
                      Icon(Icons.map, size: 20),
                      SizedBox(width: 5),
                      Text("Map"),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // THUMBNAIL WIDGET
  // --------------------------------------------------------
  Widget _thumb(String label, Uint8List? bytes, String url) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 5),
          Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black12,
            ),
            child: bytes != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes, fit: BoxFit.cover),
            )
                : const Icon(Icons.videocam),
          )
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // PLAY BUTTON
  // --------------------------------------------------------
  Widget _playBtn(String label, String url) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.play_arrow),
      label: Text(label),
      onPressed: url.isEmpty
          ? null
          : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoScreen(url: url, title: label),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------
// VIDEO PLAYER SCREEN
// --------------------------------------------------------
class VideoScreen extends StatefulWidget {
  final String url;
  final String title;

  const VideoScreen({super.key, required this.url, required this.title});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController c;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => ready = true);
        c.play();
      });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ready
            ? AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            c.value.isPlaying ? c.pause() : c.play();
          });
        },
        child: Icon(
          c.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
