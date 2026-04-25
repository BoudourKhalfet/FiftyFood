import 'package:flutter/material.dart';
import '../../widgets/order_card.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api/auth_storage.dart';
import '../../api/api_service.dart';
import '../../api/client_profile_service.dart';
import '../../widgets/RatingModal.dart';
import '../../widgets/ComplaintModal.dart';
import 'OrderTrackingPage.dart';
import 'LocationConsentPage.dart' as client_consent;
import '../../constants/api.dart';

Future<List<Map<String, dynamic>>> fetchMyOrders() async {
  final uri = Uri.parse(apiUrl('orders/client'));

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

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  String searchQuery = '';
  Set<String> selectedStatuses = {};
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  // List of all possible statuses
  static const List<String> allStatuses = [
    'CONFIRMED',
    'ASSIGNED',
    'READY',
    'PICKED_UP',
    'DELIVERED',
    'EXPIRED',
  ];

  String _targetType(String who) {
    return who == 'Restaurant' ? 'RESTAURANT' : 'DELIVERER';
  }

  Future<void> _trackDelivery(Map<String, dynamic> order) async {
    final orderId = (order['id'] ?? order['reference'] ?? '').toString();
    if (orderId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open tracking: missing order id.'),
        ),
      );
      return;
    }

    try {
      final jwt = await getJwt();
      if (jwt == null) throw Exception('Missing session token');

      final profile = await ProfileService.getProfile(jwt);
      if (!mounted) return;

      if (profile.locationConsentGiven == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => client_consent.LocationConsentPage(
            onCompleted: () {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(orderId: orderId),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open tracking: $e')));
    }
  }

  Future<void> _submitReview(
    Map<String, dynamic> order,
    String who,
    int rating,
    String? comment,
  ) async {
    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot submit review: missing order id.'),
        ),
      );
      return;
    }

    try {
      await ApiService.post('feedback/reviews', {
        'orderId': orderId,
        'targetType': _targetType(who),
        'rating': rating,
        'comment': comment ?? '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$who review submitted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    }
  }

  Future<void> _submitComplaint(
    Map<String, dynamic> order,
    String who,
    String reason,
    String? description,
  ) async {
    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot submit complaint: missing order id.'),
        ),
      );
      return;
    }

    try {
      await ApiService.post('feedback/complaints', {
        'orderId': orderId,
        'targetType': _targetType(who),
        'reason': reason,
        'description': description ?? '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$who complaint submitted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit complaint: $e')));
    }
  }

  void _openRatingModal(Map<String, dynamic> order, String who) {
    showDialog(
      context: context,
      builder: (_) => RatingModal(
        title: 'Rate $who',
        subtitle: who == 'Restaurant'
            ? 'Share your experience'
            : 'How was your delivery?',
        onSubmit: (rating, comment) {
          _submitReview(order, who, rating, comment);
        },
      ),
    );
  }

  void _openComplaintModal(Map<String, dynamic> order, String who) {
    showDialog(
      context: context,
      builder: (_) => ComplaintModal(
        title: 'Submit a Complaint',
        subtitle: who == 'Restaurant'
            ? 'Report an issue with the restaurant'
            : 'Report an issue with the deliverer',
        reasons: who == 'Restaurant'
            ? ['Order not ready', 'Rude staff', 'Food quality issue', 'Other']
            : [
                'Late delivery',
                'Rude deliverer',
                'Food not handled well',
                'Other',
              ],
        onSubmit: (reason, desc) {
          _submitComplaint(order, who, reason, desc);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ordersFuture = fetchMyOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter orders based on search query and selected statuses
  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      final orderCode = (order['pickupQrDisplay'] ?? order['reference'] ?? '')
          .toString()
          .toLowerCase();
      final orderStatus = (order['status'] ?? '').toString().toUpperCase();
      final searchLower = searchQuery.toLowerCase();

      // Check if order matches search query (order code only)
      final matchesSearch =
          searchLower.isEmpty || orderCode.contains(searchLower);

      // Check if order matches selected statuses (if any selected)
      final matchesStatus =
          selectedStatuses.isEmpty || selectedStatuses.contains(orderStatus);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
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

        final filteredOrders = _filterOrders(orders);

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by restaurant name or order code...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF16807A)),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Color(0xFF16807A)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF16807A), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // Status Filter Chips
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text('All'),
                        selected: selectedStatuses.isEmpty,
                        onSelected: (_) {
                          setState(() {
                            selectedStatuses.clear();
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Color(0xFFE8F5F0),
                        labelStyle: TextStyle(
                          color: selectedStatuses.isEmpty
                              ? Color(0xFF16807A)
                              : Colors.grey[600],
                          fontWeight: selectedStatuses.isEmpty
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: selectedStatuses.isEmpty
                              ? Color(0xFF16807A)
                              : Color(0xFFE0E0E0),
                        ),
                      ),
                    ),
                    ...allStatuses.map((status) {
                      final isSelected = selectedStatuses.contains(status);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              if (isSelected) {
                                selectedStatuses.remove(status);
                              } else {
                                selectedStatuses.add(status);
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Color(0xFFE8F5F0),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Color(0xFF16807A)
                                : Colors.grey[600],
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? Color(0xFF16807A)
                                : Color(0xFFE0E0E0),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Empty orders message (when client has no orders yet)
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('No orders yet.')),
              )
            // No results message
            else if (filteredOrders.isEmpty && searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'No orders found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      Text(
                        'Try adjusting your search or filters',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredOrders.isEmpty && selectedStatuses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.filter_list_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No orders with selected status',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Orders List
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredOrders.length,
                itemBuilder: (_, i) {
                  final o = filteredOrders[i];

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
                      (collectionMethod == 'DELIVERY') &&
                      (status == 'ASSIGNED' ||
                          status == 'READY' ||
                          status == 'PICKED_UP');

                  return OrderCard(
                    key: ValueKey(o['reference']),
                    status: status,
                    collectionMethod: collectionMethod,
                    orderId: o['pickupQrDisplay']?.toString(),
                    mealName: o['mealName'] ?? '',
                    restaurantName: o['restaurantName'] ?? '',
                    timeSlot: o['timeSlot'] ?? '',
                    date: (o['date'] ?? '').toString(),
                    imageUrl: o['imageUrl'] ?? '',
                    price: (o['price'] is num)
                        ? o['price'].toDouble()
                        : (double.tryParse(o['price']?.toString() ?? '') ?? 0),
                    reference: o['reference'] ?? '',

                    canViewQR:
                        collectionMethod == 'PICKUP' &&
                        (status == 'CONFIRMED' || status == 'READY'),
                    canRateRestaurant: canRateRestaurant,
                    canReportRestaurant: canReportRestaurant,
                    canRateDeliverer: canRateDeliverer,
                    canReportDeliverer: canReportDeliverer,
                    pickupQrToken: o['pickupQrToken']?.toString(),
                    pickupQrDisplay: o['pickupQrDisplay']?.toString(),

                    onRateRestaurant: () => _openRatingModal(o, 'Restaurant'),
                    onReportRestaurant: () =>
                        _openComplaintModal(o, 'Restaurant'),
                    onRateDeliverer: () => _openRatingModal(o, 'Deliverer'),
                    onReportDeliverer: () =>
                        _openComplaintModal(o, 'Deliverer'),

                    bottomButton: canTrack
                        ? ElevatedButton.icon(
                            icon: Icon(Icons.location_searching),
                            label: Text('Track Delivery'),
                            onPressed: () => _trackDelivery(o),
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
              ),
          ],
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
