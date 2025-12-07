import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyHospitalPage extends StatelessWidget {
  final double userLat;
  final double userLon;

  const NearbyHospitalPage({
    required this.userLat,
    required this.userLon,
    Key? key, required String userId,
  }) : super(key: key);

  /// Opens Google Maps with nearby hospitals around us//er location
  Future<void> _openNearbyHospitals() async {
    final url =
        "https://www.google.com/maps/search/hospitals/@$userLat,$userLon,15z";

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      debugPrint("❌ Could not launch Google Maps");
    }
  }

  /// Opens navigation directly to selected hospital
  Future<void> _navigateToHospital({
    required double lat,
    required double lon,
  }) async {
    final url =
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving";

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      debugPrint("❌ Could not launch Google Maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Hospitals"),
        backgroundColor: Colors.teal,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_hospital, size: 100, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text(
              "Find Hospitals Near You",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // MAIN BUTTON: Opens Google Maps Nearby Hospitals
            ElevatedButton.icon(
              icon: const Icon(Icons.map, size: 28),
              label: const Text("Open Nearby Hospitals in Google Maps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _openNearbyHospitals,
            ),

            const SizedBox(height: 50),

            // EXAMPLE: Direct navigation (you can remove if not needed)
            ElevatedButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text("Test Direct Navigation (Sample)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                _navigateToHospital(
                  lat: userLat + 0.001, // sample nearby point
                  lon: userLon + 0.001,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
