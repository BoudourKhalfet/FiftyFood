import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../api/auth_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ClientTransactionsScreen extends StatefulWidget {
  const ClientTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<ClientTransactionsScreen> createState() => _ClientTransactionsScreenState();
}

class _ClientTransactionsScreenState extends State<ClientTransactionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  String _clientType = 'NORMAL';
  String? _societyName;
  String? _fiscalNumber;

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
      final profileData = await ApiService.get(
        'users/me',
        headers: jwt != null ? {'Authorization': 'Bearer $jwt'} : null,
      );
      final ordersData = await ApiService.getList(
        'orders/client',
        headers: jwt != null ? {'Authorization': 'Bearer $jwt'} : null,
      );
      final mapped = ordersData
          .whereType<Map<String, dynamic>>()
          .map((item) => item)
          .toList();
      
      final clientProfile = profileData?['clientProfile'] as Map<String, dynamic>?;
      
      if (!mounted) return;
      setState(() {
        _orders = mapped;
        _clientType = clientProfile?['clientType']?.toString() ?? 'NORMAL';
        _societyName = clientProfile?['societyName']?.toString();
        _fiscalNumber = clientProfile?['fiscalNumber']?.toString();
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

  bool _isSuccessfulPayment(String? status) {
    if (status == null) return false;
    const successStatuses = ['CONFIRMED', 'PICKED_UP', 'DELIVERED', 'READY'];
    return successStatuses.contains(status.toUpperCase());
  }

  Future<void> _printReceipt(Map<String, dynamic> order) async {
    try {
      final pdf = pw.Document();
      final restaurantName = order['restaurantName']?.toString() ?? 'Restaurant';
      final total = order['total'] is num
          ? (order['total'] as num).toDouble()
          : double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
      final orderId = order['id']?.toString() ?? '';
      final method = order['paymentMethod']?.toString() ?? 'CARD';
      final createdAt = order['createdAt'] is String
          ? DateTime.parse(order['createdAt']).toLocal()
          : DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('FiftyFood',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 10),
                pw.Text('Receipt / Reçu',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_clientType == 'PRO')
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Client: ${_societyName ?? '-'}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 3),
                            pw.Text('Fiscal #: ${_fiscalNumber ?? '-'}'),
                            pw.SizedBox(height: 8),
                          ],
                        ),
                      pw.Text('Order ID: $orderId'),
                      pw.SizedBox(height: 5),
                      pw.Text('Restaurant: $restaurantName'),
                      pw.SizedBox(height: 5),
                      pw.Text('Date: $formattedDate'),
                      pw.SizedBox(height: 5),
                      pw.Text('Payment Method: $method'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('\$${total.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          )),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Thank you for your order!',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 5),
                pw.Text('Merci pour votre commande!',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'receipt_$orderId.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                : _orders.isEmpty
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
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final restaurantName =
                              order['restaurantName']?.toString() ?? 'Restaurant';
                          final total = order['total'] is num
                              ? (order['total'] as num).toDouble()
                              : double.tryParse(order['total']?.toString() ?? '') ??
                                  0.0;
                          final status = order['status']?.toString() ?? '';
                          if (!_isSuccessfulPayment(status)) {
                            return const SizedBox.shrink();
                          }
                          final createdAt = _formatDate(order['createdAt']);
                          final method =
                              order['paymentMethod']?.toString() ?? 'CARD';
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
                                  restaurantName,
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
                                  'Amount: ${total.toStringAsFixed(2)}',
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
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _printReceipt(order),
                                    icon: const Icon(Icons.print, size: 16),
                                    label: const Text('Print Receipt'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1F9D7A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
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
