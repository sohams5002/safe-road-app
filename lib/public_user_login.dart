import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

/// Native channel from MainActivity for volume buttons
const EventChannel _volumeChannel = EventChannel('volume_button_events');

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({Key? key}) : super(key: key);

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage> {
  // UI state
  bool isSOSPressed = false;
  bool isProcessing = false; // recording+uploading flag
  int secondsLeft = 10;
  Timer? _countdownTimer;

  // Volume-press SOS trigger
  int _volumePressCount = 0;
  DateTime _lastPressTime = DateTime.now();
  StreamSubscription? _volumeSub;

  // Dropbox
  static const String _dropboxAccessToken =
      'sl.u.AGFAFKv1-KhlsppK4_IBmlcTcqqMIu9DoHILFb2zSSUuz1A9FEdsYz9LTxNgzWvXSW036nXS84qE5yTjmfFZPCJHh-FRpYa-ULae4s2zFiv4g7AKWLAHjd_nKlnMX5kGubzPJdI1PTFjSmGRaoukXGUyt7ac_XZNYSf45mc1ycCntH-QXdm7miZfDzxF8Ldr0j54D0wlv8-Y976QYPA0u-HwjabU-6niVlT3LLpNKyzwwbd_je95w5vMKea97jPivJ7oMtESmh_K82xkE-0_DcDvi13icJDFofKuFgU30ychTBTIqs_44us8Tf6p2OO98UBy95PY937bPneBNtWuhotfkiPD5KCR5HawDiBZkCSXdrmFwod9p_W5i6gVIfVjjnxDUoNoB6VajfzOgBnw0uzwK4w6JpYpRzPP89w61YnUnEXjNVqdn_yq6fpgWYnEMsM3RFMew7hvBnTFgEQPrikTbeHu1wLI2nyvc3v9xm7C26uRxD175CF-Nsy_OYmbVYMQywaW49ZS9oP6KIJ86gHQjwn5r19tzAkmOUZ2TVE03PMfJcxLYwhfQIQdTWgR053P5dEXMToKoz8Yv8TrgnQB6YokVjKAoesPwwJAx4zDqdkcQO6xwPQOAQgV3BQbPXbCdC69le_vOuxG2YRmw_fwSRogAcjisgXF5-f5yA930xw9KEBZZL2x8roePhj974P1mtPumJO4I_LyuiIw6XEIdYoT5LvE-vclVj4yHpFmuq1TnzGvKR0ZxlMbeK4kNUdzP1jP-2fI68jWz4ysv0oyFAayBWxI0E-YUY4ur1PlGZQfj61WsLAds0MmOaHAEc8daSzrC9rUGzgBdFe-I_CICJNKenqhXozQrWNrFEt9vTlf4Oee7rX6EggRvrVfs_-zixnF_IdPmWyCS93hXJi7PCPYD7i4urXYSnmiwgV1owcfjjgBXUBiT4bjsdgIqV32fQBrzXS-qXPl-ZTl11buk5Y3m9WIsHKYlH1u2OXCvgrxB_25-ayQoL5GSGy94ns4eCFheKMcp6ZDszbfD65R969gdNn7CY2i0-3CQ86ZTKLZViXwXoPf4tuXMmR2XkX15RX2yxetRdoI0SrLE299fKxqoIKYEczbEaFFwkMx3_xYiunxuNW7IIoUzMGuMfZ_1vsqsnwDIKdLsd7yyCkGdHU882aaahsZlm7oGYZlggLJaAjoho7DeNBbohpN4O-wcsu_MnxvFCMToQh-iL4e8dOWMU-hbE-oDbeZLLepLvKbQBwVAef9v2VPl6_UajOeMMh7JXMEQkSyjYDwLpIS'; // <-- put your real token

  // ---------------- PERMISSIONS ----------------
  Future<void> _requestAllPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.location.request();
    await Permission.storage.request();
  }

  // ---------------- DEVICE NAME ----------------
  Future<String> _getDeviceName() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.model ?? 'Unknown Device';
  }

  // ---------------- LOCATION ----------------
  Future<Position> _getLocation() async {
    await Geolocator.requestPermission();
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ---------------- RECORD VIDEO ----------------
  Future<String> _recordVideo(bool isFront) async {
    final cameras = await availableCameras();

    final camera = cameras.firstWhere(
          (c) =>
      c.lensDirection ==
          (isFront ? CameraLensDirection.front : CameraLensDirection.back),
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      await controller.initialize();

      await controller.startVideoRecording();
      await Future.delayed(const Duration(seconds: 5));
      final XFile file = await controller.stopVideoRecording();

      print('📹 Video saved at: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Video recording failed: $e');
      rethrow;
    } finally {
      await controller.dispose();
    }
  }

  // ---------------- DROPBOX UPLOAD ----------------
  Future<String?> _uploadToDropbox(
      String localPath,
      String dropboxPath,
      ) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        print('❌ Local file missing for Dropbox: $localPath');
        return null;
      }

      final bytes = await file.readAsBytes();

      // 1) Upload file
      final uploadResp = await http.post(
        Uri.parse('https://content.dropboxapi.com/2/files/upload'),
        headers: {
          'Authorization': 'Bearer $_dropboxAccessToken',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': jsonEncode({
            'path': dropboxPath,
            'mode': 'overwrite',
            'autorename': true,
            'mute': false,
          }),
        },
        body: bytes,
      );

      if (uploadResp.statusCode != 200) {
        print(
            '❌ Dropbox upload failed (${uploadResp.statusCode}): ${uploadResp.body}');
        return null;
      }

      print('✅ Dropbox upload success: $dropboxPath');

      // 2) Get temporary link
      final tempResp = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/files/get_temporary_link'),
        headers: {
          'Authorization': 'Bearer $_dropboxAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'path': dropboxPath,
        }),
      );

      if (tempResp.statusCode != 200) {
        print(
            '❌ Dropbox link fetch failed (${tempResp.statusCode}): ${tempResp.body}');
        return null;
      }

      final decoded = jsonDecode(tempResp.body);
      final link = decoded['link'] as String?;
      print('🔗 Dropbox temp link: $link');
      return link;
    } catch (e) {
      print('❌ Dropbox upload error: $e');
      return null;
    }
  }

  // Helper: record one camera & upload it
  Future<String?> _recordAndUploadOneCamera({
    required bool isFront,
    required String recordId,
  }) async {
    final localPath = await _recordVideo(isFront);
    final dropboxPath =
        '/safe_road_sos/$recordId/${isFront ? 'front' : 'rear'}.mp4';
    return _uploadToDropbox(localPath, dropboxPath);
  }

  // ---------------- SEND SOS (DIRECT UPLOAD MODE) ----------------
  Future<void> _sendFinalSOS() async {
    try {
      setState(() {
        isProcessing = true;
      });

      final location = await _getLocation();
      final deviceName = await _getDeviceName();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎥 Recording & uploading videos...'),
          backgroundColor: Colors.orange,
        ),
      );

      // 1️⃣ Record + upload front video
      final frontUrl =
      await _recordAndUploadOneCamera(isFront: true, recordId: id);
      if (frontUrl == null) {
        throw 'Front video upload failed';
      }

      // 2️⃣ Record + upload rear video
      final rearUrl =
      await _recordAndUploadOneCamera(isFront: false, recordId: id);
      if (rearUrl == null) {
        throw 'Rear video upload failed';
      }

      // 3️⃣ Create final SOS data (only URLs, no local paths)
      final Map<String, dynamic> data = {
        'id': id,
        'device': deviceName,
        'lat': location.latitude,
        'lon': location.longitude,
        'frontVideo': frontUrl,
        'rearVideo': rearUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'uploadedToCloud': true,
      };

      // 4️⃣ Send to Firebase (Realtime DB + Firestore)
      await FirebaseDatabase.instance.ref('police_alerts/$id').set(data);
      await FirebaseFirestore.instance
          .collection('police_alerts')
          .doc(id)
          .set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 SOS Sent Successfully!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('❌ SOS ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending SOS: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSOSPressed = false;
          isProcessing = false;
        });
      }
    }
  }

  // ---------------- COUNTDOWN ----------------
  void _startCountdown() {
    if (isSOSPressed || isProcessing) return;

    setState(() {
      isSOSPressed = true;
      secondsLeft = 10;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() => secondsLeft--);

      if (secondsLeft <= 0) {
        timer.cancel();
        _sendFinalSOS();
      }
    });
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    setState(() => isSOSPressed = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ SOS Cancelled')),
    );
  }

  // ---------------- VOLUME BUTTON LISTENER ----------------
  void _initVolumeListener() {
    _volumeSub = _volumeChannel.receiveBroadcastStream().listen(
          (event) {
        final now = DateTime.now();

        if (now.difference(_lastPressTime).inMilliseconds < 800) {
          _volumePressCount++;
        } else {
          _volumePressCount = 1;
        }

        _lastPressTime = now;

        if (_volumePressCount >= 3 && !isSOSPressed && !isProcessing) {
          _startCountdown();
        }
      },
      onError: (error) {
        print('❌ Volume stream error: $error');
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
    _initVolumeListener();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _volumeSub?.cancel();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public User Dashboard'),
      ),
      body: Center(
        child: isSOSPressed
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sending SOS in $secondsLeft sec',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isProcessing ? null : _cancelSOS,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              child: const Text(
                '❌ Cancel SOS',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome Public User',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isProcessing ? null : _startCountdown,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 20,
                ),
              ),
              child: Text(
                isProcessing ? 'Processing...' : '🚨 Send SOS',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
            if (isProcessing) ...[
              const SizedBox(height: 16),
              const Text(
                'Recording & uploading…',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
