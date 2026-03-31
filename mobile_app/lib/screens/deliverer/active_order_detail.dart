import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart';

class ActiveOrderDetail extends StatefulWidget {
  final String orderId;
  final VoidCallback onBack;

  const ActiveOrderDetail({
    Key? key,
    required this.orderId,
    required this.onBack,
  }) : super(key: key);

  @override
  State<ActiveOrderDetail> createState() => _ActiveOrderDetailState();
}

class _ActiveOrderDetailState extends State<ActiveOrderDetail> {
  late Future<Map<String, dynamic>> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = fetchOrderTracking(widget.orderId);
  }

  Future<Map<String, dynamic>> fetchOrderTracking(String orderId) async {
    final url = Uri.parse('http://localhost:3000/orders/$orderId/tracking');
    final jwt = await getJwt();
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (jwt != null) 'Authorization': 'Bearer $jwt',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load tracking info (${response.statusCode})');
    }
  }

  void showPickupQrDialog(BuildContext context, String qrData, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: const Icon(
                      Icons.close,
                      size: 28,
                      color: Color(0xFF7AA39E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Pickup QR Code",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
              ),
              const SizedBox(height: 2),
              const Text(
                "Show this code to the restaurant to confirm pickup",
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFFD9DFDB),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(25),
                child: QrImageView(
                  data: qrData,
                  size: 160,
                  foregroundColor: const Color(0xFF202F29),
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23A391),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  child: const Text("Done"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMapsToAddress(BuildContext context, String address) async {
    final destination = Uri.encodeComponent(address);

    // Step 1: Get current location!
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location service is not enabled!')),
        );
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission is required!')),
        );
        return;
      }
    }

    final currentLocation = await location.getLocation();
    final origin = "${currentLocation.latitude},${currentLocation.longitude}";

    // Step 2: Build route with both origin and destination
    final url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$origin'
        '&destination=$destination'
        '&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch Maps for:\n$address')),
      );
    }
  }

  Future<bool> updateLocationConsentOnBackend() async {
    final jwt = await getJwt();
    final response = await http.post(
      Uri.parse('http://localhost:3000/livreur/onboarding/location-consent'),
      headers: {
        'Content-Type': 'application/json',
        if (jwt != null) 'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({'consented': true}),
    );
    return response.statusCode == 200;
  }

  Future<bool> showLocationConsentDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Location Consent Needed'),
            content: Text(
              'To display navigation, please allow sharing your location.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('No'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final success = await updateLocationConsentOnBackend();
                  if (success) {
                    Navigator.of(ctx).pop(true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("Failed to update location consent."),
                      ),
                    );
                  }
                },
                child: Text('Allow'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String getOrderStageLabel(String status, String establishmentLabel) {
    if (status == "ASSIGNED") {
      // Capitalize establishment label for display
      final label = establishmentLabel.isNotEmpty
          ? establishmentLabel[0].toUpperCase() +
                establishmentLabel.substring(1)
          : "establishment";
      return "Go to $label";
    } else if (status == "PICKED_UP") {
      return "Deliver to client";
    } else {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _orderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No order details found.'));
        }

        final order = snapshot.data!;
        final orderCode = order['orderCode'] ?? "";
        final orderStatus = order['status'] ?? '';
        final establishmentLabel = order['partnerLabel'] ?? 'restaurant';
        final stageLabel = getOrderStageLabel(orderStatus, establishmentLabel);

        final restaurantName = order['restaurantName'] ?? '';
        final restaurantAddress = order['restaurantAddress'] ?? '';
        final restaurantPhone = order['restaurantPhone'] ?? '';
        final pickupTime = order['timeSlot'] ?? "";

        final customerName = order['clientName'] ?? '';
        final customerAddress = order['deliveryAddress'] ?? '';
        final customerPhone = order['clientPhone'] ?? '';
        bool canShowQr = order['pickupQrFor'] == 'DELIVERER';

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: widget.onBack, // Or: Navigator.of(context).pop()
            ),
            title: const Text('Order Details'),
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: Colors.black,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === Progress bar ===
                OrderProgressBar(status: order['status'] ?? 'ASSIGNED'),
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Order #$orderCode",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        stageLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    if (canShowQr)
                      OutlinedButton.icon(
                        onPressed: () {
                          showPickupQrDialog(
                            context,
                            order['pickupQrData'] ??
                                order['reference'] ??
                                order['id'] ??
                                '',
                            order['pickupQrDisplay'] ??
                                order['orderCode'] ??
                                '',
                          );
                        },
                        icon: const Icon(
                          Icons.qr_code,
                          size: 18,
                          color: Color(0xFF16AA6B),
                        ),
                        label: const Text(
                          "View QR Code",
                          style: TextStyle(color: Color(0xFF16AA6B)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF16AA6B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          foregroundColor: const Color(0xFF16AA6B),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // === Restaurant Card ===
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF09A98D)),
                  ),
                  padding: const EdgeInsets.all(13),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF16AA6B),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurantName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  restaurantAddress,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFFAAAAAA),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Pickup by $pickupTime",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              bool consentGiven =
                                  order['locationConsentGiven'] == true;
                              if (!consentGiven) {
                                bool accepted = await showLocationConsentDialog(
                                  context,
                                );
                                if (!accepted) return;
                                setState(() {
                                  order['locationConsentGiven'] = true;
                                });
                              }
                              openMapsToAddress(
                                context,
                                order['restaurantAddress'] ?? '',
                              );
                            },
                            icon: const Icon(
                              Icons.navigation,
                              color: Color(0xFF16AA6B),
                            ),
                            label: const Text(
                              "Navigate",
                              style: TextStyle(color: Color(0xFF16AA6B)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF16AA6B)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              minimumSize: const Size(0, 32),
                              foregroundColor: const Color(0xFF16AA6B),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            color: Color(0xFF16AA6B),
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            restaurantPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF16AA6B),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // === Customer Card ===
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAF8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF09A98D)),
                  ),
                  padding: const EdgeInsets.all(13),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person, color: Color(0xFFFF865E)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  customerAddress,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              bool consentGiven =
                                  order['locationConsentGiven'] == true;
                              if (!consentGiven) {
                                final accepted =
                                    await showLocationConsentDialog(context);
                                if (!accepted) return;
                                setState(() {
                                  order['locationConsentGiven'] = true;
                                });
                              }
                              openMapsToAddress(
                                context,
                                order['deliveryAddress'] ?? '',
                              );
                            },
                            icon: const Icon(
                              Icons.navigation,
                              color: Color(0xFF16AA6B),
                            ),
                            label: const Text(
                              "Navigate",
                              style: TextStyle(color: Color(0xFF16AA6B)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF16AA6B)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              minimumSize: const Size(0, 32),
                              foregroundColor: const Color(0xFF16AA6B),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            color: Color(0xFF16AA6B),
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            customerPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF16AA6B),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // === Mark as Delivered ===
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {}, // TODO: handle delivered
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text("Mark as Delivered"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF197144),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OrderProgressBar extends StatelessWidget {
  final String status;

  const OrderProgressBar({Key? key, required this.status}) : super(key: key);

  Color _stepColor(bool active) =>
      active ? Color(0xFF16AA6B) : Color(0xFFECECEC);
  Color _iconColor(bool active) => active ? Colors.white : Color(0xFFB6B6B6);
  Color _barColor(bool active) =>
      active ? Color(0xFF16AA6B) : Color(0xFFDADADA);
  Color _textColor(bool active) => active ? Colors.black : Color(0xFFB6B6B6);

  @override
  Widget build(BuildContext context) {
    final isAccepted =
        status == 'ASSIGNED' || status == 'PICKED_UP' || status == 'DELIVERED';
    final isPickedUp = status == 'PICKED_UP' || status == 'DELIVERED';
    final isDelivered = status == 'DELIVERED';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _stepColor(isAccepted),
              child: Icon(Icons.check, color: _iconColor(isAccepted), size: 28),
            ),
            SizedBox(height: 3),
            Text(
              "Accepted",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textColor(isAccepted),
              ),
            ),
          ],
        ),
        Container(width: 32, height: 3, color: _barColor(isPickedUp)),
        Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _stepColor(isPickedUp),
              child: Icon(
                Icons.inventory_2,
                color: _iconColor(isPickedUp),
                size: 28,
              ),
            ),
            SizedBox(height: 3),
            Text(
              "Picked Up",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textColor(isPickedUp),
              ),
            ),
          ],
        ),
        Container(width: 32, height: 3, color: _barColor(isDelivered)),
        Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _stepColor(isDelivered),
              child: Icon(
                Icons.done_all,
                color: _iconColor(isDelivered),
                size: 28,
              ),
            ),
            SizedBox(height: 3),
            Text(
              "Delivered",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textColor(isDelivered),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
