import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';

class AvailableDeliveries extends StatefulWidget {
  const AvailableDeliveries({Key? key}) : super(key: key);

  @override
  _AvailableDeliveriesState createState() => _AvailableDeliveriesState();
}

class _AvailableDeliveriesState extends State<AvailableDeliveries> {
  List<Map<String, dynamic>> _deliveryOrders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchDeliveryOrders();
  }

  Future<void> fetchDeliveryOrders() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final url = Uri.parse(
      'http://192.168.100.6:3000/orders/deliverer/available',
    );
    final jwt = await getJwt();

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (jwt != null) 'Authorization': 'Bearer $jwt',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _deliveryOrders = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          error = 'Failed to load deliveries (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Error fetching deliveries: $e';
      });
    }
  }

  Future<bool> acceptDelivery(String orderId) async {
    final url = Uri.parse('http://192.168.100.6:3000/orders/$orderId/accept');
    final jwt = await getJwt();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (jwt != null) 'Authorization': 'Bearer $jwt',
      },
    );
    print("Accept response: code=${response.statusCode} body=${response.body}");
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderCode = order['orderCode'] ?? '';
    final restaurantName =
        order['restaurant']?['restaurantProfile']?['restaurantName'] ?? '';
    final restaurantAddress =
        order['restaurant']?['restaurantProfile']?['address'] ?? '';
    final customerName = order['client']?['clientProfile']?['fullName'] ?? '';
    final customerAddress = order['deliveryAddress'] ?? '';
    final pickupTime = order['offer']?['pickupTime'] ?? '';

    final distance = order['distance']?.toString() ?? '';
    final items = (order['items']?['quantity'] ?? 0).toString();
    final totalPrice = order['total'] ?? 0.0;
    final deliveryFee = order['deliveryFee'] ?? 0.0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8ECE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF14C38E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: const Text(
                    'New',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '#$orderCode',
                  style: const TextStyle(
                    color: Color(0xFF8C8C8C),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF14C38E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF222325),
                        ),
                      ),
                      Text(
                        restaurantAddress,
                        style: const TextStyle(
                          color: Color(0xFF868686),
                          fontSize: 13.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.person_pin_circle_rounded,
                  color: Color(0xFFFF865E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.8,
                          color: Color(0xFF222325),
                        ),
                      ),
                      Text(
                        customerAddress,
                        style: const TextStyle(
                          color: Color(0xFF868686),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFFB6B6B6),
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text(pickupTime, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 15),
                const Icon(
                  Icons.near_me_rounded,
                  color: Color(0xFFB6B6B6),
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text(distance, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 15),
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFFB6B6B6),
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text('$items item(s)', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${totalPrice.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF222325),
                      ),
                    ),
                    Text(
                      '+${deliveryFee.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF14C38E),
                      ),
                    ),
                    const Text(
                      "Earnings",
                      style: TextStyle(fontSize: 10, color: Color(0xFF14C38E)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.close, color: Color(0xFF14C38E)),
                    label: const Text(
                      'Decline',
                      style: TextStyle(color: Color(0xFF14C38E)),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      side: const BorderSide(
                        color: Color(0xFF14C38E),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      print("Accepting order id: ${order['id']}");
                      final result = await acceptDelivery(order['id']);
                      if (result) {
                        setState(() {
                          _deliveryOrders.remove(order);
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to accept delivery.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14C38E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 1;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 3;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 2;
          }
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(19, 20, 0, 15),
                  child: Text(
                    "Available Deliveries",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
              ),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                SliverFillRemaining(child: Center(child: Text(error!)))
              else if (_deliveryOrders.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No available deliveries.')),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 800 ? 40 : 12,
                  ),
                  sliver: crossAxisCount == 1
                      ? SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildOrderCard(_deliveryOrders[index]),
                            ),
                            childCount: _deliveryOrders.length,
                          ),
                        )
                      : SliverGrid(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _buildOrderCard(_deliveryOrders[index]);
                          }, childCount: _deliveryOrders.length),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
