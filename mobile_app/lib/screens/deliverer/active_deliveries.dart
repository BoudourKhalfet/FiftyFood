import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';
import '../../constants/api.dart';

class ActiveDeliveries extends StatefulWidget {
  final Function(Map<String, dynamic>)? onOrderTap;

  const ActiveDeliveries({Key? key, this.onOrderTap}) : super(key: key);

  @override
  _ActiveDeliveriesState createState() => _ActiveDeliveriesState();
}

class _ActiveDeliveriesState extends State<ActiveDeliveries> {
  List<Map<String, dynamic>> _activeDeliveries = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchActiveDeliveries();
  }

  Future<void> fetchActiveDeliveries() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final url = Uri.parse(apiUrl('orders/deliverer/active'));
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
        // For meta/stats, adjust according to your backend structure
        if (data is Map && data.containsKey('data')) {
          _activeDeliveries = List<Map<String, dynamic>>.from(data['data']);
        } else {
          _activeDeliveries = List<Map<String, dynamic>>.from(data);
        }
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          error = 'Failed to load active deliveries (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Error fetching active deliveries: $e';
      });
    }
  }

  Widget _buildActiveCard(Map<String, dynamic> order) {
    final orderCode = order['orderCode'] ?? '';
    final restaurantName =
        order['restaurant']?['restaurantProfile']?['restaurantName'] ??
        order['restaurantName'] ??
        '';
    final customerName =
        order['client']?['clientProfile']?['fullName'] ??
        order['userName'] ??
        '';
    final distance =
        (order['distance']?.toString() ?? order['km']?.toString() ?? '');
    final price = order['deliveryFee'] ?? order['amount'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCDCD6)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6F3),
              borderRadius: BorderRadius.circular(14),
            ),
            width: 44,
            height: 44,
            child: const Icon(
              Icons.all_inbox_rounded,
              color: Color(0xFF14C38E),
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderCode — $restaurantName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: Color(0xFF3E554B),
                        fontSize: 14,
                      ),
                    ),
                    if (distance.isNotEmpty) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(color: Color(0xFFBED6CD)),
                      ),
                      Text(
                        '$distance km',
                        style: const TextStyle(
                          color: Color(0xFF3E554B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {}, // TODO: action for go to pickup
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDC140),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Go to pickup",
                  style: TextStyle(
                    color: Color(0xFF3E554B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${price.toStringAsFixed(2)} DT', // or € if you're in euro
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF16AA6B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveDelivery() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      padding: const EdgeInsets.symmetric(vertical: 38),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.near_me_rounded, size: 58, color: Color(0xFF3E554B)),
          const SizedBox(height: 20),
          const Text(
            'No active delivery',
            style: TextStyle(fontSize: 17, color: Color(0xFF3E554B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Accept a delivery to get started',
            style: TextStyle(fontSize: 14, color: Color(0xFF7FA19A)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(19, 20, 0, 15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Active Delivery",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text(error!))
                : _activeDeliveries.isEmpty
                ? _buildEmptyActiveDelivery()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 5,
                    ),
                    itemCount: _activeDeliveries.length,
                    itemBuilder: (context, idx) {
                      return GestureDetector(
                        onTap: () {
                          if (widget.onOrderTap != null) {
                            widget.onOrderTap!(_activeDeliveries[idx]);
                          }
                        },
                        child: _buildActiveCard(_activeDeliveries[idx]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
