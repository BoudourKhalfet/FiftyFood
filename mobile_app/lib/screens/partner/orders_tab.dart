import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../api/auth_storage.dart';

class PartnerOrdersTab extends StatefulWidget {
  const PartnerOrdersTab({Key? key}) : super(key: key);

  @override
  State<PartnerOrdersTab> createState() => _PartnerOrdersTabState();
}

class _PartnerOrdersTabState extends State<PartnerOrdersTab> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String? error;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => isLoading = true);
    try {
      final token = await getJwt();

      final response = await ApiService.getList(
        'orders/partner',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (mounted) {
        setState(() {
          orders = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final token = await getJwt();
      await ApiService.patch(
        'orders/$orderId/confirm',
        {},
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      await _fetchOrders();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept order: $e')));
    }
  }

  Future<void> _markReady(String orderId) async {
    try {
      final token = await getJwt();
      await ApiService.patch(
        'orders/$orderId/ready',
        {},

        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      await _fetchOrders();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark as ready: $e')));
    }
  }

  Widget _buildFilteredOrderList() {
    final keyword = searchQuery.trim().toLowerCase();

    final filteredOrders = orders.where((order) {
      final code = (order['orderCode'] ?? order['reference'] ?? order['id'])
          .toString()
          .toLowerCase();
      final name = (order['customerName'] ?? '').toString().toLowerCase();
      final status = (order['status'] ?? '').toString().toLowerCase();

      return keyword.isEmpty ||
          code.contains(keyword) ||
          name.contains(keyword) ||
          status.contains(keyword);
    }).toList();

    if (filteredOrders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('No orders match your search.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final o = filteredOrders[i];
        return _buildOrderCard(
          context: context,
          orderId: o['orderCode'] ?? o['reference'] ?? o['id'],
          status: o['status'] ?? '',
          customer: o['customerName'] ?? '',
          items: o['itemsCount'] ?? 1,
          fulfillmentType: (o['method'] == 'DELIVERY') ? 'Delivery' : 'Pickup',
          time: o['pickupTime'] ?? '',
          onAccept: () => _acceptOrder(o['id']),
          onReady: () => _markReady(o['id']),
          onCancel: () {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text('Error: $error'));
    }
    if (orders.isEmpty) {
      return Center(child: Text('No orders yet!'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by order, customer, or status...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        _buildFilteredOrderList(),
      ],
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required String orderId,
    required String status,
    required String customer,
    required int items,
    required String fulfillmentType,
    required String time,
    required VoidCallback? onAccept,
    required VoidCallback? onReady,
    required VoidCallback? onCancel,
  }) {
    bool isDelivery = fulfillmentType.toLowerCase().contains("delivery");
    // Status styling and button logic
    Color statusColor;
    String statusLabel;
    IconData orderIcon;
    String actionLabel = "";
    IconData actionIcon = Icons.check;
    VoidCallback? actionCallback;

    if (status == "PENDING") {
      statusColor = Color(0xFF10B981); // Green
      statusLabel = "New";
      orderIcon = Icons.notifications_none_outlined;
      actionLabel = "Accept Order";
      actionIcon = Icons.check;
      actionCallback = onAccept;
    } else if (status == "CONFIRMED" || status == "ASSIGNED") {
      statusColor = Color(0xFF2563EB); // Blue
      statusLabel = "Preparing";
      orderIcon = Icons.qr_code_2_rounded;
      actionLabel = "Mark as Ready";
      actionIcon = Icons.check_circle;
      actionCallback = onReady;
    } else if (status == "READY") {
      statusColor = Color(0xFFFFA726); // Orange
      statusLabel = "Ready";
      orderIcon = Icons.check_circle_outline;
      actionLabel = "";
      actionIcon = Icons.done_all;
      actionCallback = null;
    } else {
      statusColor = Color(0xFFBDBDBD);
      statusLabel = status;
      orderIcon = Icons.qr_code_2_rounded;
      actionLabel = "";
      actionIcon = Icons.done_all;
      actionCallback = null;
    }

    final fulfillColor = isDelivery ? Color(0xFFFF7849) : Color(0xFF1F9D7A);
    final fulfillIcon = isDelivery
        ? Icons.local_shipping_rounded
        : Icons.storefront_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.018),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section: badge, title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(orderIcon, color: Color(0xFF6B7280), size: 22),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "#$orderId",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF222B45),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "$customer • $items item(s)",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fulfillColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(fulfillIcon, color: fulfillColor, size: 16),
                    SizedBox(width: 4),
                    Text(
                      fulfillmentType,
                      style: TextStyle(
                        color: fulfillColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Icon(
                Icons.access_time_rounded,
                size: 15,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(width: 3),
              Text(
                (isDelivery ? '' : 'Pickup at ') + time,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Button or nothing
          if (actionLabel.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: actionCallback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == "READY"
                          ? Color(0xFFFFA726)
                          : Color(0xFF10B981),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(actionIcon, size: 20, color: Colors.white),
                    label: Text(
                      actionLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
