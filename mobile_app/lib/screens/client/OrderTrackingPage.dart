import 'package:flutter/material.dart';
import '../../models/client_order.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../../api/auth_storage.dart';
import '../../constants/api.dart';

LatLng? parseLatLng(String loc) {
  if (loc.isEmpty) return null;
  final parts = loc.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

class LatLng {
  final double lat, lng;
  LatLng(this.lat, this.lng);
}

String getDistanceText(LatLng? a, LatLng? b) {
  if (a == null || b == null) return '';
  final distanceMeters = Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

String getEtaText(LatLng? a, LatLng? b) {
  if (a == null || b == null) return '';
  final distanceMeters = Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);

  final averageDriverSpeed = 25 * 1000 / 60;
  final etaMinutes = (distanceMeters / averageDriverSpeed).ceil();
  return "$etaMinutes min";
}

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({required this.orderId, Key? key})
    : super(key: key);

  // Status mapping
  int statusIndexFor(String status) {
    switch (status) {
      case 'ORDER_ACCEPTED':
        return 0;
      case 'PICKED_UP':
        return 1;
      case 'ON_THE_WAY':
        return 2;
      case 'ARRIVED':
        return 3;
      case 'DELIVERED':
        return 4;
      default:
        return 0;
    }
  }

  Future<ClientOrder> fetchTracking(String orderId) async {
    print('fetchTracking called for $orderId');
    final token = await getJwt();
    final response = await http.get(
      Uri.parse(apiUrl('orders/$orderId/tracking')),
      headers: {if (token != null) "Authorization": "Bearer $token"},
    );
    print('HTTP response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      print("TRACKING ORDER RAW: ${response.body}");
      return ClientOrder.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load tracking');
  }

  @override
  Widget build(BuildContext context) {
    print('OrderTrackingScreen build called');
    return FutureBuilder<ClientOrder>(
      future: fetchTracking(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(child: Text('Order not found or failed to load')),
          );
        }
        final order = snapshot.data!;
        print(
          "### UI DEBUG - name: ${order.restaurantName}, img: ${order.imageUrl}, label: ${order.partnerLabel}, price: ${order.price}, qty: ${order.quantity}",
        );
        LatLng? clientLatLng = parseLatLng(order.clientLocation);
        LatLng? driverLatLng = parseLatLng(order.delivererLocation);
        final driverDistanceText = getDistanceText(clientLatLng, driverLatLng);
        final driverEtaText = getEtaText(clientLatLng, driverLatLng);

        return OrderTrackingPage(
          order: order,
          statusIndex: statusIndexFor(order.status),
          driverEtaText: driverEtaText,
          driverDistanceText: driverDistanceText,
        );
      },
    );
  }
}

class OrderTrackingPage extends StatelessWidget {
  final ClientOrder order;
  final int statusIndex;
  final String driverEtaText;
  final String driverDistanceText;

  const OrderTrackingPage({
    Key? key,
    required this.order,
    this.statusIndex = 0,
    this.driverEtaText = "",
    this.driverDistanceText = "",
  }) : super(key: key);

  static const Color primary = Color(0xFF199060);
  static const Color primaryGradientLeft = Color(0xFF22AE6B);
  static const Color greyBg = Color(0xFFF6FAF7);

  static const steps = [
    "Order Accepted",
    "Picked Up",
    "On the Way",
    "Arrived",
    "Delivered",
  ];

  static const stepIcons = [
    Icons.check,
    Icons.inventory_2,
    Icons.local_shipping,
    Icons.location_on,
    Icons.check_circle,
  ];

  Future<void> _confirmDelivery(BuildContext context) async {
    final token = await getJwt();
    if (token == null) {
      throw Exception('Missing session token');
    }

    final response = await http.patch(
      Uri.parse(apiUrl('orders/${order.id}/confirm-delivery')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Confirm delivery response: ${response.statusCode} ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        ),
      );
      return;
    }

    throw Exception('Failed to confirm delivery (${response.statusCode})');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: BackButton(color: Colors.black),
        titleSpacing: 0,
        title: Text(
          "Your order is on the way",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 23,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ETA
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 8, right: 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF37C490), size: 15),
                    SizedBox(width: 7),
                    Text(
                      "Estimated arrival in",
                      style: TextStyle(fontSize: 17, color: Colors.black87),
                    ),
                    SizedBox(width: 6),
                    Text(
                      order.timeSlot,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              // Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, color: primary, size: 19),
                    SizedBox(width: 7),
                    Text(
                      order.partnerLabel.isNotEmpty
                          ? order.partnerLabel[0] +
                                order.partnerLabel.substring(1).toLowerCase()
                          : '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.home, color: primary, size: 19),
                    SizedBox(width: 7),
                    Text(
                      "Your Home",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 7,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: LinearProgressIndicator(
                    value: (statusIndex + 1) / steps.length,
                    backgroundColor: Color(0xFFE5E6EC),
                    valueColor: AlwaysStoppedAnimation(primary),
                    minHeight: 7,
                  ),
                ),
              ),

              // Track driver location panel
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(vertical: 17, horizontal: 18),
                  margin: EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: primary, size: 35),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deliverer location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              statusIndex < steps.length - 1
                                  ? "Deliverer is ${driverDistanceText.isNotEmpty ? driverDistanceText : '...'} • ETA ${driverEtaText.isNotEmpty ? driverEtaText : '...'}"
                                  : "Deliverer has arrived at your location",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 7),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                        ),
                        icon: Icon(
                          Icons.open_in_new,
                          size: 19,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Open Map',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),

              // Timeline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Container(
                  decoration: BoxDecoration(
                    color: greyBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 3, vertical: 20),
                  margin: EdgeInsets.only(bottom: 12),
                  child: _buildTimeline(),
                ),
              ),

              // Order Details Card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.all(20),
                  margin: EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order Details",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 14),
                      // From (restaurant and address)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.store, color: primary, size: 20),
                          SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "From: ${order.restaurantName}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (order.restaurantAddress.isNotEmpty)
                                  Text(
                                    order.restaurantAddress,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // To (destination and address)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.place_outlined, color: primary, size: 20),
                          SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "To: Your Home",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  order.deliveryAddress,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // ETA
                      Row(
                        children: [
                          Icon(Icons.access_time, color: primary, size: 20),
                          SizedBox(width: 9),
                          Text(
                            "ETA: ${driverEtaText.isNotEmpty ? driverEtaText : '...'}",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 28, thickness: 0.9),
                      // Product details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meal image
                          if (order.imageUrl.isNotEmpty)
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(order.imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.mealName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (order.restaurantName.isNotEmpty)
                                  Text(
                                    order.restaurantName,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.black54,
                                    ),
                                  ),
                                SizedBox(height: 2),
                                Text(
                                  "€${order.price.toStringAsFixed(2)} x ${order.quantity}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Driver Card
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 17),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 17),
                  margin: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFFE8F5F0),
                        radius: 25,
                        child: Icon(Icons.person, color: primary, size: 31),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.delivererName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Row(
                              children: [
                                Text("Scooter", style: TextStyle(fontSize: 14)),
                                SizedBox(width: 4),
                                Icon(Icons.star, size: 16, color: Colors.amber),
                                Text(
                                  order.delivererRating.toString(),
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.phone, color: primary),
                          SizedBox(width: 5),
                          Text(
                            order.delivererPhone,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Footer buttons (vertical on mobile!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                  children: [
                    if (statusIndex < steps.length - 1) ...[
                      _confirmDeliveryGradientButton(
                        onPressed: () async {
                          try {
                            await _confirmDelivery(context);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                      ),
                      SizedBox(height: 11),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary, width: 2),
                              minimumSize: Size.fromHeight(47),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Browse More",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 13),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary, width: 2),
                              minimumSize: Size.fromHeight(47),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Contact Deliverer",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (i) {
        final isCurrent = i == statusIndex;
        final isDone = i < statusIndex;
        final isLast = i == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDone || isCurrent ? primary : Colors.white,
                    border: Border.all(color: primary, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    stepIcons[i],
                    color: isDone
                        ? Colors.white
                        : (isCurrent ? Colors.white : primary),
                    size: 21.5,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 4,
                    height: 40,
                    color: primary.withOpacity(0.18),
                  ),
              ],
            ),
            SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 9.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontWeight: (isCurrent)
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 17,
                      color: (isCurrent || isDone) ? primary : Colors.grey[500],
                    ),
                  ),
                  if (isCurrent)
                    Text(
                      "In progress...",
                      style: TextStyle(fontSize: 14.2, color: primary),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _confirmDeliveryGradientButton({required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 51,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryGradientLeft, primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Confirm Delivery",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
