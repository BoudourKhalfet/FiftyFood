import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../api/auth_storage.dart';

class DelivererTransactionsPage extends StatefulWidget {
  const DelivererTransactionsPage({super.key});

  @override
  State<DelivererTransactionsPage> createState() => _DelivererTransactionsPageState();
}

class _DelivererTransactionsPageState extends State<DelivererTransactionsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];

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
      if (jwt == null) throw Exception('Missing session token');

      final res = await ApiService.get(
        'orders/deliverer/history',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      final items = res is List
          ? res
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _transactions = items;
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

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: const Color(0xFF28C76F),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load transactions: $_error'),
                  ),
                )
              : _transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions yet'),
                    )
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final totalRevenue = _transactions.fold<double>(0, (sum, transaction) {
      final total = _toDouble(transaction['amount'] ?? transaction['total']);
      final delivererFee = _toDouble(transaction['delivererFee']);
      return sum + (total - delivererFee);
    });

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF28C76F), Color(0xFF20A55A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF28C76F).withOpacity(0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Revenue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${totalRevenue.toStringAsFixed(2)} DT',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_transactions.length} transaction${_transactions.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              final transaction = _transactions[index];
              final orderCode = transaction['orderCode']?.toString() ?? '-';
              final date = _formatDate(
                transaction['date'] ?? transaction['createdAt'],
              );
              final total = _toDouble(
                transaction['amount'] ?? transaction['total'],
              );
              final delivererFee = _toDouble(transaction['delivererFee']);
              final net = total - delivererFee;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E0D4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #$orderCode',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1B1B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7F8F87),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${net.toStringAsFixed(2)} DT',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1DB57A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F5F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5E6D66),
                                ),
                              ),
                              Text(
                                '${total.toStringAsFixed(2)} DT',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Delivery fee:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5E6D66),
                                ),
                              ),
                              Text(
                                '-${delivererFee.toStringAsFixed(2)} DT',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Your amount:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B1B1B),
                                  ),
                                ),
                                Text(
                                  '${net.toStringAsFixed(2)} DT',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1DB57A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
