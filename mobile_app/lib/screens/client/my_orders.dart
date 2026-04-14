import 'package:flutter/material.dart';
import '../../widgets/order_card.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';
import '../../widgets/RatingModal.dart';
import '../../widgets/ComplaintModal.dart';
import 'OrderTrackingPage.dart';

void _openRatingModal(BuildContext ctx, String who) {
  showDialog(
    context: ctx,
    builder: (_) => RatingModal(
      title: 'Rate $who',
      subtitle: who == "Restaurant"
          ? 'Share your experience'
          : 'How was your delivery?',
      onSubmit: (rating, comment) {
        // handle submit rating, with who ("Restaurant" or "Deliverer")
      },
    ),
  );
}

void _openComplaintModal(BuildContext ctx, String who) {
  showDialog(
    context: ctx,
    builder: (_) => ComplaintModal(
      title: 'Submit a Complaint',
      subtitle: who == "Restaurant"
          ? 'Report an issue with the restaurant'
          : 'Report an issue with the deliverer',
      reasons: who == "Restaurant"
          ? ["Order not ready", "Rude staff", "Food quality issue", "Other"]
          : [
              "Late delivery",
              "Rude deliverer",
              "Food not handled well",
              "Other",
            ],
      onSubmit: (reason, desc) {
        // handle submit complaint
      },
    ),
  );
}

Future<List<Map<String, dynamic>>> fetchMyOrders() async {
  final uri = Uri.parse('http://localhost:3000/users/me/orders');

  final token = await getJwt();

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body);
    return data
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  } else {
    throw Exception('Failed to fetch orders: ${response.statusCode}');
  }
}

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchMyOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Failed to load orders',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text("No orders yet.")),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final o = orders[i];

            final rawStatus = (o['status'] ?? '').toString();
            final rawCollectionMethod = (o['collectionMethod'] ?? '')
                .toString();

            String normalize(String s) {
              return s
                  .replaceAll(RegExp(r'\s+'), '')
                  .replaceAll(RegExp(r'[^A-Za-z_]'), '')
                  .toUpperCase();
            }

            final status = normalize(rawStatus);
            final collectionMethod = normalize(rawCollectionMethod);

            final canRateRestaurant =
                (status == 'PICKED_UP' && collectionMethod == 'PICKUP') ||
                (status == 'DELIVERED' && collectionMethod == 'DELIVERY');

            final canReportRestaurant = canRateRestaurant;

            final canRateDeliverer =
                (status == 'DELIVERED' && collectionMethod == 'DELIVERY');

            final canReportDeliverer = canRateDeliverer;
            final canTrack =
                (collectionMethod == 'DELIVERY') && (status == 'ASSIGNED');

            return OrderCard(
              key: ValueKey(o['reference']),
              status: status,
              collectionMethod: collectionMethod,
              mealName: o['mealName'] ?? '',
              restaurantName: o['restaurantName'] ?? '',
              timeSlot: o['timeSlot'] ?? '',
              date: (o['date'] ?? '').toString(),
              imageUrl: o['imageUrl'] ?? '',
              price: (o['price'] is num)
                  ? o['price'].toDouble()
                  : (double.tryParse(o['price']?.toString() ?? '') ?? 0),
              reference: o['reference'] ?? '',

              canViewQR: status == 'CONFIRMED' && collectionMethod == 'PICKUP',
              canRateRestaurant: canRateRestaurant,
              canReportRestaurant: canReportRestaurant,
              canRateDeliverer: canRateDeliverer,
              canReportDeliverer: canReportDeliverer,

              onRateRestaurant: () => _openRatingModal(context, "Restaurant"),
              onReportRestaurant: () =>
                  _openComplaintModal(context, "Restaurant"),
              onRateDeliverer: () => _openRatingModal(context, "Deliverer"),
              onReportDeliverer: () =>
                  _openComplaintModal(context, "Deliverer"),

              bottomButton: canTrack
                  ? ElevatedButton.icon(
                      icon: Icon(Icons.location_searching),
                      label: Text('Track Delivery'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderTrackingScreen(
                              orderId: o['id'] ?? o['reference'],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: MyOrdersPage(),
        ),
      ),
    );
  }
}
