import 'package:flutter/material.dart';
import 'dart:async';
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _fetchOrders(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => isLoading = true);
    }
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
          if (!silent) {
            isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => isLoading = false);
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

  Future<void> _viewOrderDetails({
    required String orderId,
    required String displayCode,
    required int itemsCount,
  }) async {
    try {
      final token = await getJwt();
      final response = await ApiService.get(
        'orders/$orderId/tracking',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      final details = Map<String, dynamic>.from(response as Map);
      final method = (details['collectionMethod'] ?? '').toString();
      final fallbackCode =
          (details['orderDisplayCode'] ??
                  details['pickupQrDisplay'] ??
                  details['reference'] ??
                  details['id'] ??
                  '')
              .toString();
      final normalizedDisplayCode = displayCode.isNotEmpty
          ? displayCode
          : _formatOrderCode(fallbackCode, method);
      final parsedItems = int.tryParse((details['quantity'] ?? '').toString());
      final normalizedItems = parsedItems ?? itemsCount;
      final isDelivery =
          (details['collectionMethod'] ?? '').toString().toUpperCase() ==
          'DELIVERY';

      showDialog(
        context: context,
        builder: (dialogContext) {
          final statusText = (details['status'] ?? '').toString().toUpperCase();
          final methodText = (details['collectionMethod'] ?? '')
              .toString()
              .toUpperCase();
          final statusColor = _statusColor(statusText);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 22,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 26,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF0F9D7A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Order Details',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          icon: Icons.confirmation_number_outlined,
                          label: normalizedDisplayCode,
                          color: const Color(0xFF0F9D7A),
                          bg: const Color(0xFFE8F5F0),
                        ),
                        _buildInfoChip(
                          icon: Icons.flag_outlined,
                          label: statusText,
                          color: statusColor,
                          bg: statusColor.withOpacity(0.14),
                        ),
                        _buildInfoChip(
                          icon: methodText == 'DELIVERY'
                              ? Icons.delivery_dining
                              : Icons.store_mall_directory_outlined,
                          label: methodText,
                          color: const Color(0xFF4B5563),
                          bg: const Color(0xFFF3F4F6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Order',
                      child: Column(
                        children: [
                          _buildDataLine(
                            Icons.schedule_outlined,
                            'Pickup time',
                            (details['timeSlot'] ?? '').toString(),
                          ),
                          _buildDataLine(
                            Icons.inventory_2_outlined,
                            'Items',
                            normalizedItems.toString(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSectionCard(
                      title: 'Client',
                      child: Column(
                        children: [
                          _buildDataLine(
                            Icons.person_outline,
                            'Full name',
                            (details['clientName'] ?? 'N/A').toString(),
                          ),
                          _buildDataLine(
                            Icons.phone_outlined,
                            'Phone',
                            (details['clientPhone'] ?? 'N/A').toString(),
                          ),
                        ],
                      ),
                    ),
                    if (isDelivery) ...[
                      const SizedBox(height: 10),
                      _buildSectionCard(
                        title: 'Deliverer',
                        child: Column(
                          children: [
                            _buildDataLine(
                              Icons.two_wheeler_outlined,
                              'Full name',
                              (details['delivererName'] ?? 'Not assigned')
                                  .toString(),
                            ),
                            _buildDataLine(
                              Icons.phone_outlined,
                              'Phone',
                              (details['delivererPhone'] ?? 'N/A').toString(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildSectionCard(
                      title: 'Offer',
                      child: Column(
                        children: [
                          _buildDataLine(
                            Icons.restaurant_menu,
                            'Meal',
                            (details['mealName'] ?? '').toString(),
                          ),
                          _buildDataLine(
                            Icons.payments_outlined,
                            'Price',
                            '\$${(details['price'] ?? 0).toString()}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFE8F5F0),
                          foregroundColor: const Color(0xFF0F9D7A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load order details.')),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF374151), fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value.isEmpty ? 'N/A' : value),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildDataLine(IconData icon, String label, String value) {
    final safeValue = value.isEmpty ? 'N/A' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: safeValue,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return const Color(0xFF2563EB);
      case 'READY':
        return const Color(0xFFD97706);
      case 'PICKED_UP':
        return const Color(0xFF7C3AED);
      case 'DELIVERED':
        return const Color(0xFF059669);
      case 'EXPIRED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String _formatOrderCode(String rawCode, String method) {
    final code = rawCode.toString();
    final normalizedMethod = method.toUpperCase();

    if (normalizedMethod == 'PICKUP') {
      return code.replaceFirst(
        RegExp(r'^(DEL|DEV)', caseSensitive: false),
        'PUP',
      );
    }

    if (normalizedMethod == 'DELIVERY') {
      return code.replaceFirst(
        RegExp(r'^(DEL|PUP)', caseSensitive: false),
        'DEV',
      );
    }

    return code;
  }

  String _displayOrderCode(Map<String, dynamic> order) {
    final method = (order['method'] ?? '').toString().toUpperCase();
    final code =
        (order['orderDisplayCode'] ??
                order['orderCode'] ??
                order['reference'] ??
                order['id'])
            .toString();

    return _formatOrderCode(code, method);
  }

  bool _isPickupWindowExpired(String pickupTime) {
    final raw = pickupTime.trim();
    if (raw.isEmpty) return false;

    final parts = raw.split('-');
    final endPart = parts.length >= 2 ? parts.last.trim() : raw;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(endPart);
    if (match == null) return false;

    final endHour = int.tryParse(match.group(1)!);
    final endMinute = int.tryParse(match.group(2)!);
    if (endHour == null || endMinute == null) return false;

    final now = DateTime.now();
    final endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
    return now.isAfter(endTime);
  }

  String _effectiveStatus(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toUpperCase();
    if (status == 'PENDING') {
      final method = (order['method'] ?? '').toString().toUpperCase();
      final pickupTime = (order['pickupTime'] ?? '').toString();
      if (method == 'PICKUP' && _isPickupWindowExpired(pickupTime)) {
        return 'EXPIRED';
      }
    }
    return status;
  }

  Widget _buildFilteredOrderList() {
    final keyword = searchQuery.trim().toLowerCase();

    final filteredOrders = orders.where((order) {
      final code = _displayOrderCode(order).toLowerCase();
      final name = (order['customerName'] ?? '').toString().toLowerCase();
      final status = _effectiveStatus(order).toLowerCase();

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
        final displayCode = _displayOrderCode(o);
        return _buildOrderCard(
          context: context,
          rawOrderId: (o['id'] ?? '').toString(),
          orderId: displayCode,
          status: _effectiveStatus(o),
          customer: o['customerName'] ?? '',
          items: o['itemsCount'] ?? 1,
          fulfillmentType: (o['method'] == 'DELIVERY') ? 'Delivery' : 'Pickup',
          time: o['pickupTime'] ?? '',
          mealPhotoUrl: (o['offerPhoto'] ?? '').toString(),
          displayCode: displayCode,
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
    required String rawOrderId,
    required String orderId,
    required String status,
    required String customer,
    required int items,
    required String fulfillmentType,
    required String time,
    required String mealPhotoUrl,
    required String displayCode,
    required VoidCallback? onReady,
    required VoidCallback? onCancel,
  }) {
    bool isDelivery = fulfillmentType.toLowerCase().contains("delivery");
    final normalizedStatus = status.toUpperCase();
    // Status styling and button logic
    Color statusColor;
    String statusLabel;
    IconData orderIcon;
    String actionLabel = "";
    IconData actionIcon = Icons.check;
    VoidCallback? actionCallback;

    if (normalizedStatus == "PENDING") {
      statusColor = Color(0xFF10B981); // Green
      statusLabel = "New";
      orderIcon = Icons.notifications_none_outlined;
      actionLabel = "";
      actionIcon = Icons.done_all;
      actionCallback = null;
    } else if (normalizedStatus == "CONFIRMED" ||
        normalizedStatus == "ASSIGNED") {
      statusColor = Color(0xFF2563EB); // Blue
      statusLabel = "Preparing";
      orderIcon = Icons.qr_code_2_rounded;
      actionLabel = "Mark as Ready";
      actionIcon = Icons.check_circle;
      actionCallback = onReady;
    } else if (normalizedStatus == "READY") {
      statusColor = Color(0xFFFFA726); // Orange
      statusLabel = "Ready";
      orderIcon = Icons.check_circle_outline;
      actionLabel = "";
      actionIcon = Icons.done_all;
      actionCallback = null;
    } else if (normalizedStatus == "EXPIRED") {
      statusColor = Color(0xFF6B7280); // Gray
      statusLabel = "Expired";
      orderIcon = Icons.hourglass_disabled_rounded;
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
          if (mealPhotoUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 18 / 7,
                child: Image.network(
                  mealPhotoUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
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
                  child: OutlinedButton.icon(
                    onPressed: () => _viewOrderDetails(
                      orderId: rawOrderId,
                      displayCode: displayCode,
                      itemsCount: items,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    label: const Text(
                      'View',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: actionCallback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: normalizedStatus == "READY"
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
          if (actionLabel.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _viewOrderDetails(
                  orderId: rawOrderId,
                  displayCode: displayCode,
                  itemsCount: items,
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  foregroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 20),
                label: const Text(
                  'View',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
