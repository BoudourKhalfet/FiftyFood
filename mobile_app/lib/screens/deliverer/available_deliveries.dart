import 'package:flutter/material.dart';

class AvailableDeliveries extends StatefulWidget {
  const AvailableDeliveries({Key? key}) : super(key: key);

  @override
  _AvailableDeliveriesState createState() => _AvailableDeliveriesState();
}

class _AvailableDeliveriesState extends State<AvailableDeliveries> {
  int _selectedTab = 0;

  // These values will be populated from backend
  double _earnings = 0.0;
  int _deliveries = 0;
  double _rating = 0.0;
  int _activeHours = 0;

  // List to be populated from backend
  final List<Map<String, dynamic>> _deliveryOrders = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Available_Deliveries',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 16),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 70,
                  errorBuilder: (context, error, stack) => const Icon(Icons.fastfood, size: 48),
                ),
              ),
            ),
            // Stats Section
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thomas R.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1F9D7A)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('€${_earnings.toStringAsFixed(2)}', 'Earnings'),
                      _buildStatItem(_deliveries.toString(), 'Deliveries'),
                      _buildStatItem(_rating.toStringAsFixed(1), 'Rating'),
                      _buildStatItem('${_activeHours}h', 'Active'),
                    ],
                  ),
                ],
              ),
            ),
            // Deliveries List - Populated from backend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No available deliveries',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Available'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1F9D7A),
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
