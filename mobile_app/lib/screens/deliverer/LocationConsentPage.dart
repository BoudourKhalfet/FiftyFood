import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';
import 'dart:convert';
import 'package:location/location.dart';
import '../../constants/api.dart';

class LocationConsentPage extends StatefulWidget {
  const LocationConsentPage({Key? key}) : super(key: key);

  @override
  State<LocationConsentPage> createState() => _LocationConsentPageState();
}

class _LocationConsentPageState extends State<LocationConsentPage> {
  bool consented = false;
  bool loading = false;
  Color get primaryRed => const Color(0xFFE65151);

  Future<void> _submitConsent(bool value) async {
    setState(() => loading = true);
    final token = await getJwt();
    try {
      final res = await http.post(
        Uri.parse(apiUrl('livreur/onboarding/location-consent')),
        headers: {
          if (token != null) "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({'consented': value}),
      );
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
            await http.post(
              Uri.parse(apiUrl('livreur/onboarding/location')),
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

      if (!mounted) return;
      // On success, send deliverer to dashboard
      Navigator.of(context).pushReplacementNamed('/deliverer/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update location consent')),
      );
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
                      color: const Color(0xFFFBE6E7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: primaryRed,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Title
                  const Text(
                    "Enable Location Sharing",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 13),
                  // Subtitle
                  Text(
                    "As a delivery partner, your live location helps customers track their orders and allows us to optimize your routes.",
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
                      border: Border.all(color: const Color(0xFFF2CCCC)),
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
                            "WHY WE NEED YOUR LOCATION",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16.2,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 17),
                        _featureRow(
                          primaryRed,
                          const Color(0xFFFBE6E7),
                          Icons.remove_red_eye_rounded,
                          "Real-time customer tracking",
                          "Customers can see your live position during delivery, reducing calls and complaints",
                        ),
                        const SizedBox(height: 16),
                        _featureRow(
                          primaryRed,
                          const Color(0xFFFBE6E7),
                          Icons.alt_route_rounded,
                          "Optimized routes",
                          "Get delivery requests closest to your current location to save time and fuel",
                        ),
                        const SizedBox(height: 16),
                        _featureRow(
                          primaryRed,
                          const Color(0xFFFBE6E7),
                          Icons.flash_on_rounded,
                          "More delivery requests",
                          "Nearby orders are prioritized to you, increasing your earning potential",
                        ),
                        const SizedBox(height: 16),
                        _featureRow(
                          primaryRed,
                          const Color(0xFFFBE6E7),
                          Icons.lock_outline_rounded,
                          "Privacy protected",
                          "Your location is only shared during active deliveries — never stored or sold",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Important info box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      border: Border.all(color: const Color(0xFFFED4D5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Important: Location sharing is required to receive delivery requests. Without it, you won't appear as available to customers.",
                      style: TextStyle(
                        color: const Color(0xFFB23636),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Consent box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F8),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 13,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: consented,
                          onChanged: (v) => setState(() => consented = true),
                          activeColor: primaryRed,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            "I consent to sharing my live location with FiftyFood customers during active deliveries. I understand my location is only shared while I'm on a delivery and is not stored permanently.",
                            style: TextStyle(
                              fontSize: 15.3,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
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
                        backgroundColor: primaryRed,
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
                                const Text('Enable & Start Delivering'),
                                const SizedBox(width: 7),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 21,
                                ),
                              ],
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
    Color bg,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 22),
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
