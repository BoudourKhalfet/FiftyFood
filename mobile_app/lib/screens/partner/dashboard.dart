import 'package:flutter/material.dart';
import 'dart:async';

class PartnerDashboardPage extends StatefulWidget {
  const PartnerDashboardPage({Key? key}) : super(key: key);

  @override
  State<PartnerDashboardPage> createState() => _PartnerDashboardPageState();
}

class _PartnerDashboardPageState extends State<PartnerDashboardPage> {
  int _activeTab = 0; // 0: offers, 1: orders, 2: stats, 3: profile
  bool _showCreateOffer = false;
  bool _showQrScanner = false;
  bool _showModeFete = false;
  bool _modeFeteActive = false;
  String _modeFeteRemaining = '';
  Timer? _modeFeteTimer;
  DateTime? _modeFeteEndsAt;

  // New Offer Form
  String _offerDescription = '';
  String _originalPrice = '';
  String _discountedPrice = '';
  String _quantity = '';
  String _pickupTime = '';
  String _visibility = 'identified';
  bool _deliveryAvailable = false;

  // Image Upload
  String? _offerImagePreview;
  bool _aiVerifying = false;
  Map<String, dynamic>? _aiResult;

  // Mode Fête Form
  String _modeFeteDuration = '60';
  String _modeFeteMessage = '';

  // QR Scanner
  String _qrInput = '';
  Map<String, dynamic>? _qrResult;

  // Empty Data (No Backend Yet)
  final List<Map<String, dynamic>> _offers = [];

  final Map<String, dynamic> _stats = {
    'totalSales': 0,
    'mealsSaved': 0,
    'avgRating': 0,
    'activeOffers': 0,
  };

  final List<Map<String, dynamic>> _orders = [];

  final Map<String, dynamic> _restaurantInfo = {
    'name': 'Restaurant Name',
    'address': 'Address not set',
    'phone': '+1 (000) 000-0000',
    'email': 'email@example.com',
    'trustScore': 0,
    'documentsVerified': false,
  };

  @override
  void dispose() {
    _modeFeteTimer?.cancel();
    super.dispose();
  }

  void _startModeFete() {
    final duration = int.parse(_modeFeteDuration);
    final endsAt = DateTime.now().add(Duration(minutes: duration));
    
    setState(() {
      _modeFeteActive = true;
      _modeFeteEndsAt = endsAt;
      _showModeFete = false;
      _modeFeteDuration = '60';
      _modeFeteMessage = '';
    });

    _modeFeteTimer?.cancel();
    _modeFeteTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_modeFeteActive) {
        timer.cancel();
        return;
      }

      final remaining = _modeFeteEndsAt!.difference(DateTime.now());
      if (remaining.isNegative) {
        setState(() {
          _modeFeteActive = false;
          _modeFeteRemaining = '';
        });
        timer.cancel();
      } else {
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        final seconds = remaining.inSeconds % 60;
        
        if (hours > 0) {
          _modeFeteRemaining = '$hours h ${minutes.toString().padLeft(2, '0')} m';
        } else {
          _modeFeteRemaining = '$minutes m ${seconds.toString().padLeft(2, '0')} s';
        }
        setState(() {});
      }
    });
  }

  void _endModeFete() {
    _modeFeteTimer?.cancel();
    setState(() {
      _modeFeteActive = false;
      _modeFeteRemaining = '';
    });
  }

  void _simulateAiVerification() async {
    setState(() => _aiVerifying = true);
    
    await Future.delayed(Duration(milliseconds: 2500));

    List<String> reasons = [];
    bool passed = true;

    if (passed) {
      reasons.addAll([
        '✅ Metadata verified — photo is recent',
        '✅ Image quality check passed',
        '✅ Food content detected (confidence: ${85 + (DateTime.now().millisecond % 14)}%)',
      ]);
    }

    setState(() {
      _aiResult = {'passed': passed, 'reasons': reasons};
      _aiVerifying = false;
    });
  }

  void _toggleOfferStatus(int index) {
    setState(() {
      if (_offers[index]['status'] == 'active') {
        _offers[index]['status'] = 'paused';
      } else {
        _offers[index]['status'] = 'active';
      }
    });
  }

  void _createOffer() {
    if (_aiResult?['passed'] != true) return;

    setState(() {
      _showCreateOffer = false;
      _offerImagePreview = null;
      _aiResult = null;
      _offerDescription = '';
      _originalPrice = '';
      _discountedPrice = '';
      _quantity = '';
      _pickupTime = '';
      _visibility = 'identified';
      _deliveryAvailable = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Offer published successfully!'), backgroundColor: Color(0xFF1F9D7A)),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 20)),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        if (_offers.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF9CA3AF)), SizedBox(height: 8), Text('No offers yet', style: TextStyle(color: Color(0xFF9CA3AF)))])),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              final offer = _offers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      decoration: const BoxDecoration(color: Color(0xFFEFEFEF), borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10))),
                      child: const Center(child: Icon(Icons.fastfood, size: 40, color: Color(0xFF9CA3AF))),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(offer['description'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: offer['status'] == 'active' ? const Color(0xFF10B981) : (offer['status'] == 'sold_out' ? const Color(0xFFE5E7EB) : const Color(0xFFFFA500)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  offer['status'] == 'active' ? 'Active' : (offer['status'] == 'sold_out' ? 'Sold Out' : 'Paused'),
                                  style: TextStyle(color: offer['status'] == 'active' ? Colors.white : const Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(children: [
                                  TextSpan(text: '€${offer['discountedPrice'].toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF1F9D7A), fontWeight: FontWeight.w800, fontSize: 16)),
                                  TextSpan(text: ' €${offer['originalPrice'].toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF9CA3AF), decoration: TextDecoration.lineThrough, fontSize: 12)),
                                ]),
                              ),
                              Text('${offer['quantity']} left', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text(offer['pickupTime'], style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(offer['deliveryAvailable'] ? Icons.local_shipping : Icons.store, size: 14, color: offer['deliveryAvailable'] ? const Color(0xFF10B981) : const Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text(offer['deliveryAvailable'] ? 'Delivery available' : 'Pickup only', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 14), label: const Text('Edit'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), foregroundColor: const Color(0xFF1F9D7A), side: const BorderSide(color: Color(0xFF1F9D7A))))),
                              const SizedBox(width: 8),
                              OutlinedButton(onPressed: () => _toggleOfferStatus(index), child: Icon(offer['status'] == 'active' ? Icons.visibility_off : Icons.visibility, size: 14), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), foregroundColor: const Color(0xFF1F9D7A), side: const BorderSide(color: Color(0xFF1F9D7A)))),
                              const SizedBox(width: 8),
                              OutlinedButton(onPressed: () {}, child: const Icon(Icons.delete, size: 14, color: Colors.red), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today\'s Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.qr_code, size: 20, color: Color(0xFF9CA3AF)))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('${order['customer']} • ${order['quantity']} item(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order['deliveryMethod'] == 'delivery' ? const Color(0xFF1F9D7A).withOpacity(0.1) : Colors.transparent,
                          border: Border.all(color: order['deliveryMethod'] == 'delivery' ? const Color(0xFF1F9D7A) : const Color(0xFF9CA3AF)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(order['deliveryMethod'] == 'delivery' ? Icons.local_shipping : Icons.store, size: 12, color: order['deliveryMethod'] == 'delivery' ? const Color(0xFF1F9D7A) : const Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(order['deliveryMethod'] == 'delivery' ? 'Delivery' : 'Pickup', style: TextStyle(fontSize: 11, color: order['deliveryMethod'] == 'delivery' ? const Color(0xFF1F9D7A) : const Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Time', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            Text(order['time'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order['status'] == 'collected' ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFFFA500).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order['status'] == 'collected' ? 'Collected' : 'Pending',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: order['status'] == 'collected' ? const Color(0xFF10B981) : const Color(0xFFFFA500)),
                        ),
                      ),
                    ],
                  ),
                  if (order['status'] == 'pending') ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, child: const Text('Mark Collected'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)))),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Performance Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales This Week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              const Text('Revenue from rescued meals', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              Container(height: 150, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bar_chart, size: 32, color: Color(0xFF9CA3AF)), SizedBox(height: 8), Text('Chart placeholder', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))]))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Environmental Impact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              const Text('Your contribution to reducing waste', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              _buildImpactRow('CO₂ Saved', '234 kg'),
              const SizedBox(height: 8),
              _buildImpactRow('Water Saved', '1,250 L'),
              const SizedBox(height: 8),
              _buildImpactRow('Meals Rescued', '156'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImpactRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))), Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1F9D7A)))]),
    );
  }

  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Restaurant Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.business, size: 18, color: Color(0xFF1F9D7A)), SizedBox(width: 8), Text('Restaurant Information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
              const SizedBox(height: 12),
              _buildInfoField('Restaurant Name', _restaurantInfo['name']),
              const SizedBox(height: 8),
              _buildInfoField('Email', _restaurantInfo['email']),
              const SizedBox(height: 8),
              _buildInfoField('Phone', _restaurantInfo['phone']),
              const SizedBox(height: 8),
              _buildInfoField('Address', _restaurantInfo['address']),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.description, size: 18, color: Color(0xFF1F9D7A)), SizedBox(width: 8), Text('Legal Documents', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
              const SizedBox(height: 12),
              _buildDocumentRow('Business Registration'),
              const SizedBox(height: 8),
              _buildDocumentRow('Hygiene Certificate'),
              const SizedBox(height: 8),
              _buildDocumentRow('Ownership/Rental Proof'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.star, size: 18, color: Color(0xFFFFA500)), SizedBox(width: 8), Text('Trust Score', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
                    child: Center(child: Text(_restaurantInfo['trustScore'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF10B981)))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Excellent Standing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 2), const Text('Your trust score is based on document verification & ratings', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))])),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)), child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)))),
      ],
    );
  }

  Widget _buildDocumentRow(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)), child: const Text('Verified', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))), const SizedBox(width: 8), Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)))]),
        OutlinedButton(onPressed: () {}, child: const Text('View'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), side: const BorderSide(color: Color(0xFF1F9D7A)), foregroundColor: const Color(0xFF1F9D7A))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('FiftyFood Partner', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu, color: Color(0xFF1A1A1A)))),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(isSmallScreen ? 14 : 20, 14, isSmallScreen ? 14 : 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text('Welcome back, ${_restaurantInfo['name']} 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 2),
              const Text('Manage your offers and track your impact', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),

              // Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showQrScannerDialog,
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Scan QR'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1F9D7A), side: const BorderSide(color: Color(0xFF1F9D7A)), padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateOfferDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Offer'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stats Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(width: 160, child: _buildStatCard('Total Sales', '€${_stats['totalSales'].toStringAsFixed(0)}', Icons.euro, const Color(0xFF1F9D7A))),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: _buildStatCard('Meals Saved', '${_stats['mealsSaved']}', Icons.eco, const Color(0xFF1F9D7A))),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: _buildStatCard('Avg Rating', '${_stats['avgRating']}', Icons.star, const Color(0xFFFFA500))),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: _buildStatCard('Active Offers', '${_stats['activeOffers']}', Icons.trending_up, const Color(0xFFFF7A59))),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mode Fête Section
              if (_modeFeteActive)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFFFEAA7), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration, color: Color(0xFFFFA500), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mode Fête Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 12, color: Color(0xFFFFA500)),
                                const SizedBox(width: 4),
                                Text(_modeFeteRemaining, style: const TextStyle(fontSize: 11, color: Color(0xFFFFA500), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(onTap: _endModeFete, child: const Icon(Icons.close, size: 18, color: Color(0xFFFFA500))),
                    ],
                  ),
                ),

              // Tab Navigation
              Row(
                children: [
                  _buildTabButton(0, 'Offers'),
                  _buildTabButton(1, 'Orders'),
                  _buildTabButton(2, 'Stats'),
                  _buildTabButton(3, 'Profile'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Content
              if (_activeTab == 0) _buildOffersTab() else if (_activeTab == 1) _buildOrdersTab() else if (_activeTab == 2) _buildStatsTab() else _buildProfileTab(),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildTabButton(int index, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _activeTab == index ? const Color(0xFF1F9D7A) : Colors.transparent, width: 3)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _activeTab == index ? const Color(0xFF1F9D7A) : const Color(0xFF6B7280))),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              children: [
                Center(
                  child: Image.asset('assets/images/logo.png', width: 120, height: 80, fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => Container(width: 120, height: 80, decoration: BoxDecoration(color: const Color(0xFF1F9D7A), borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.spa, color: Colors.white, size: 40))),
                  ),
                ),
                const SizedBox(height: 24),
                Material(color: Colors.transparent, child: Container(decoration: BoxDecoration(color: _activeTab == 0 ? const Color(0xFF1F9D7A) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: ListTile(leading: const Icon(Icons.inventory_2, color: Colors.white), title: const Text('My Offers', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)), onTap: () { setState(() => _activeTab = 0); Navigator.pop(context); }))),
                const SizedBox(height: 12),
                Container(decoration: BoxDecoration(color: _activeTab == 1 ? const Color(0xFF1F9D7A).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: ListTile(leading: const Icon(Icons.widgets, color: Color(0xFF9CA3AF)), title: const Text('Orders', style: TextStyle(color: Color(0xFF6B7280))), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFF7A59), borderRadius: BorderRadius.circular(12)), child: Text('${_orders.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))), onTap: () { setState(() => _activeTab = 1); Navigator.pop(context); })),
                Container(decoration: BoxDecoration(color: _activeTab == 2 ? const Color(0xFF1F9D7A).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: ListTile(leading: const Icon(Icons.bar_chart, color: Color(0xFF9CA3AF)), title: const Text('Statistics', style: TextStyle(color: Color(0xFF6B7280))), onTap: () { setState(() => _activeTab = 2); Navigator.pop(context); })),
                Container(decoration: BoxDecoration(color: _activeTab == 3 ? const Color(0xFF1F9D7A).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: ListTile(leading: const Icon(Icons.person, color: Color(0xFF9CA3AF)), title: const Text('Profile', style: TextStyle(color: Color(0xFF6B7280))), onTap: () { setState(() => _activeTab = 3); Navigator.pop(context); })),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.celebration, color: Color(0xFF1F9D7A), size: 18), const SizedBox(width: 8), Expanded(child: const Text('Mode Fête', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1F9D7A))))]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () { Navigator.pop(context); setState(() => _showModeFete = true); },
                        icon: const Icon(Icons.celebration, size: 14),
                        label: const Text('Déclarer'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                ListTile(leading: const Icon(Icons.settings, color: Color(0xFF6B7280)), title: const Text('Settings')),
                ListTile(leading: const Icon(Icons.logout, color: Color(0xFFEF4444)), title: const Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateOfferDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => Container(
          color: Colors.white,
          child: SingleChildScrollView(
            controller: controller,
            child: Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create New Offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  const Text('List your surplus food and help reduce waste', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 16),

                  // Image Upload
                  const Text('Food Photo (required)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (_offerImagePreview == null)
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9CA3AF), style: BorderStyle.none), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF3F4F6)),
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 32, color: Color(0xFF9CA3AF)), SizedBox(height: 8), Text('Upload Food Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), SizedBox(height: 2), Text('Take a fresh photo or select from gallery', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))]),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(height: 150, width: double.infinity, color: const Color(0xFFE5E7EB), child: Stack(alignment: Alignment.topRight, children: [Container(color: const Color(0xFFE5E7EB), height: 150, width: double.infinity), Padding(padding: const EdgeInsets.all(8), child: IconButton(onPressed: () => setState(() { _offerImagePreview = null; _aiResult = null; }), icon: const Icon(Icons.close), style: IconButton.styleFrom(backgroundColor: Colors.white), iconSize: 18))]))),
                        const SizedBox(height: 8),
                        if (!_aiVerifying && _aiResult == null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _simulateAiVerification,
                              icon: const Icon(Icons.shield_outlined, size: 16),
                              label: const Text('Verify Photo with AI'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                            ),
                          )
                        else if (_aiVerifying)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AI Verification in progress...', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)), Text('Checking metadata, quality, and food content', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)))]))]),
                          )
                        else if (_aiResult != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _aiResult!['passed'] ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10), border: Border.all(color: _aiResult!['passed'] ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_aiResult!['passed'] ? Icons.check_circle : Icons.cancel, size: 18, color: _aiResult!['passed'] ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                    const SizedBox(width: 8),
                                    Text(_aiResult!['passed'] ? 'Verification Passed' : 'Verification Failed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _aiResult!['passed'] ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...(_aiResult!['reasons'] as List).map((r) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(r, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))))).toList(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Form Fields
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(onChanged: (v) => _offerDescription = v, decoration: InputDecoration(hintText: 'Describe your offer...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF9CA3AF))), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Original Price (€)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(onChanged: (v) => _originalPrice = v, decoration: InputDecoration(hintText: '18.50', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF9CA3AF))), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))), keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Discounted Price (€)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(onChanged: (v) => _discountedPrice = v, decoration: InputDecoration(hintText: '6.90', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF9CA3AF))), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))), keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(onChanged: (v) => _quantity = v, decoration: InputDecoration(hintText: '5', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF9CA3AF))), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))), keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pickup Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButton<String>(
                              value: _pickupTime.isEmpty ? null : _pickupTime,
                              isExpanded: true,
                              underline: Container(),
                              items: ['18-19', '19-20', '20-21', '21-22'].map((v) => DropdownMenuItem(value: v, child: Text(v == '18-19' ? '18:00 - 19:00' : (v == '19-20' ? '19:00 - 20:00' : (v == '20-21' ? '20:00 - 21:00' : '21:00 - 22:00')), style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _pickupTime = v ?? ''),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Visibility
                  const Text('Offer Visibility', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildVisibilityOption('identified', 'Identified Restaurant', 'Your restaurant name and branding will be visible'),
                  const SizedBox(height: 8),
                  _buildVisibilityOption('anonymous', 'Anonymous', 'Only price, quantity, pickup time and distance shown'),
                  const SizedBox(height: 16),

                  // Delivery Toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [const Icon(Icons.local_shipping, size: 16, color: Color(0xFF9CA3AF)), const SizedBox(width: 8), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Enable Delivery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)), Text('Allow customers to order delivery', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))])]),
                        Switch(value: _deliveryAvailable, onChanged: (v) => setState(() => _deliveryAvailable = v), activeColor: const Color(0xFF1F9D7A)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1F9D7A), padding: const EdgeInsets.symmetric(vertical: 10)))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _aiResult?['passed'] == true ? _createOffer : null,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), disabledBackgroundColor: const Color(0xFF9CA3AF)),
                          child: Text(_aiResult?['passed'] == true ? 'Publish Offer' : 'Verify photo first'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(String value, String title, String subtitle) {
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: _visibility == value ? const Color(0xFF1F9D7A) : const Color(0xFF9CA3AF)),
          borderRadius: BorderRadius.circular(8),
          color: _visibility == value ? const Color(0xFF1F9D7A).withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<String>(value: value, groupValue: _visibility, onChanged: (v) => setState(() => _visibility = v!), activeColor: const Color(0xFF1F9D7A)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)), SizedBox(height: 2, child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))))]))
          ],
        ),
      ),
    );
  }

  void _showQrScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Validate Customer QR Code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter or scan the customer\'s QR code', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF9CA3AF), style: BorderStyle.solid)), child: const Center(child: Icon(Icons.qr_code, size: 40, color: Color(0xFF9CA3AF)))),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) { _qrInput = v; },
                decoration: InputDecoration(hintText: 'Paste QR token here...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              ),
              const SizedBox(height: 12),
              if (_qrResult != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _qrResult!['success'] ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8), border: Border.all(color: _qrResult!['success'] ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                  child: Row(
                    children: [
                      Icon(_qrResult!['success'] ? Icons.check_circle : Icons.cancel, size: 18, color: _qrResult!['success'] ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_qrResult!['message'], style: TextStyle(fontSize: 11, color: _qrResult!['success'] ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { _qrInput = ''; _qrResult = null; Navigator.pop(context); }, child: const Text('Close')),
          ElevatedButton(onPressed: _qrInput.isNotEmpty ? () { setState(() => _qrResult = {'success': true, 'message': 'QR Code validated successfully!'}); } : null, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A)), child: const Text('Validate', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
