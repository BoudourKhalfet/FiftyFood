import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../api/auth_storage.dart';

class PartnerTransactionsScreen extends StatefulWidget {
  const PartnerTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<PartnerTransactionsScreen> createState() => _PartnerTransactionsScreenState();
}

class _PartnerTransactionsScreenState extends State<PartnerTransactionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final jwt = await getJwt();
      final data = await ApiService.getList(
        'orders/partner',
        headers: jwt != null ? {'Authorization': 'Bearer $jwt'} : null,
      );
      final mapped = data
          .whereType<Map<String, dynamic>>()
          .map((item) => item)
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = mapped;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    try {
      if (value is String) {
        return DateTime.parse(value).toLocal().toString();
      }
      return value?.toString() ?? '';
    } catch (_) {
      return value?.toString() ?? '';
    }
  }

  bool _isConfirmedStatus(String? status) {
    if (status == null) return false;
    const allowed = ['CONFIRMED', 'ASSIGNED', 'READY', 'PICKED_UP', 'DELIVERED'];
    return allowed.contains(status.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final confirmedOrders = _orders
        .where((order) => _isConfirmedStatus(order['status']?.toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: const Color(0xFF1F9D7A),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Failed to load transactions: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : confirmedOrders.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No payments yet.'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: confirmedOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = confirmedOrders[index];

                      final clientName = order['customerName']?.toString() ?? 'Client';
                      final amount = order['amount'] is num
                          ? (order['amount'] as num).toDouble()
                          : double.tryParse(order['amount']?.toString() ?? '') ?? 0.0;
                      final createdAt = _formatDate(order['createdAt']);
                      final method = order['paymentMethod']?.toString() ?? 'CARD';
                      final orderId = order['id']?.toString() ?? '';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Order: $orderId',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Amount: ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Method: $method',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              createdAt,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
