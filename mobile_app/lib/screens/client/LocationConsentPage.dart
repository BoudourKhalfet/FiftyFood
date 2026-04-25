import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';
import 'dart:convert';
import 'package:location/location.dart';
import '../../constants/api.dart';

class LocationConsentPage extends StatefulWidget {
  final VoidCallback? onCompleted;

  const LocationConsentPage({Key? key, this.onCompleted}) : super(key: key);

  @override
  State<LocationConsentPage> createState() => _LocationConsentPageState();
}

class _LocationConsentPageState extends State<LocationConsentPage> {
  bool consented = false;
  bool loading = false;
  Color get primary => const Color(0xFF199060);

  Future<void> _submitConsent(bool value) async {
    setState(() => loading = true);
    final token = await getJwt();
    try {
      final res = await http.patch(
        Uri.parse(apiUrl('users/me/location-consent')),
        headers: {
          if (token != null) "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({'consented': value}),
      );
      print("Consent PATCH: ${res.statusCode} ${res.body}");
      if (!(res.statusCode >= 200 && res.statusCode < 300)) {
        throw Exception('Failed to set location consent');
      }

      final location = Location();
      final serviceEnabled =
          await location.serviceEnabled() || await location.requestService();
      if (serviceEnabled) {
        var permission = await location.hasPermission();
        if (permission == PermissionStatus.denied) {
          permission = await location.requestPermission();
        }
        if (permission == PermissionStatus.granted ||
            permission == PermissionStatus.grantedLimited) {
          final current = await location.getLocation();
          if (current.latitude != null && current.longitude != null) {
            await http.patch(
              Uri.parse(apiUrl('users/me/location')),
              headers: {
                if (token != null) 'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'latitude': current.latitude,
                'longitude': current.longitude,
              }),
            );
          }
        }
      }

      // Call navigation callback after the PATCH and *after* loading set to false
      if (!mounted) return;
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        Navigator.of(context).pushReplacementNamed('/offers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update location consent')),
        );
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top icon
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3F4DF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: primary,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Title
                  const Text(
                    "Enable Location Services",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 13),
                  // Subtitle
                  Text(
                    "Allow FiftyFood to use your location to find nearby offers and track your deliveries.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Features box
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            "WHAT YOU GET",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16.2,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _featureRow(
                          primary,
                          Icons.location_on,
                          "Nearby offers",
                          "Discover restaurants with surplus food near you",
                        ),
                        const SizedBox(height: 17),
                        _featureRow(
                          primary,
                          Icons.remove_red_eye_outlined,
                          "Live delivery tracking",
                          "Track your delivery driver in real time on a map",
                        ),
                        const SizedBox(height: 17),
                        _featureRow(
                          primary,
                          Icons.eco,
                          "Accurate distance",
                          "See exact distance to each restaurant and offer",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Consent box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F8),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 19,
                      horizontal: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: consented,
                          onChanged: (v) => setState(() => consented = true),
                          activeColor: primary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            "I consent to FiftyFood accessing my device location to show nearby offers, calculate distances, and enable live delivery tracking. My location data is used only within the app and is never sold to third parties.",
                            style: TextStyle(
                              fontSize: 15.3,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    "Your data is protected under our Privacy Policy. You can change this anytime in Settings.",
                    style: TextStyle(fontSize: 12.7, color: Colors.grey[600]),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 19),
                  // Main Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !consented || loading
                          ? null
                          : () async {
                              await _submitConsent(true);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Enable & Continue'),
                                const SizedBox(width: 7),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 21,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: loading
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/offers');
                          },
                    child: Text(
                      "Skip for now",
                      style: TextStyle(
                        color: primary,
                        fontSize: 15.0,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
    Color color,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD3F4DF),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color.withOpacity(0.9), size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13.7, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
