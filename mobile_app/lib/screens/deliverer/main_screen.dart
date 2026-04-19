import 'package:flutter/material.dart';
import 'dart:async';
import 'package:location/location.dart';

import 'available_deliveries.dart';
import 'active_deliveries.dart';
import 'active_order_detail.dart';
import 'history_page.dart';
import 'profile_page.dart';
import '../../api/api_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedTab = 0;
  String? selectedActiveOrderId;
  Timer? _onlinePingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pingOnline();
    _onlinePingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pingOnline();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pingOnline();
    }
  }

  Future<void> _pingOnline() async {
    try {
      await ApiService.post('livreur/onboarding/ping', {});
    } catch (_) {
      // Keep ping best-effort; no UI disruption for transient errors.
    }

    try {
      final location = Location();
      final serviceEnabled =
          await location.serviceEnabled() || await location.requestService();
      if (!serviceEnabled) return;

      var permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        return;
      }

      final current = await location.getLocation();
      if (current.latitude == null || current.longitude == null) return;

      await ApiService.post('livreur/onboarding/location', {
        'latitude': current.latitude,
        'longitude': current.longitude,
      });
    } catch (_) {
      // Keep location updates best-effort.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlinePingTimer?.cancel();
    super.dispose();
  }

  void _showActiveOrderDetail(Map<String, dynamic> order) {
    setState(() {
      selectedActiveOrderId = order['id'];
    });
  }

  void _popActiveOrderDetail() {
    setState(() {
      selectedActiveOrderId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget middleContent;
    if (_selectedTab == 1 && selectedActiveOrderId != null) {
      middleContent = ActiveOrderDetail(
        onBack: _popActiveOrderDetail,
        orderId: selectedActiveOrderId!,
      );
    } else {
      switch (_selectedTab) {
        case 0:
          middleContent = AvailableDeliveries();
          break;
        case 1:
          middleContent = ActiveDeliveries(onOrderTap: _showActiveOrderDetail);
          break;
        case 2:
          middleContent = const DelivererHistoryPage();
          break;
        case 3:
          middleContent = const DelivererProfilePage();
          break;
        default:
          middleContent = Center(child: Text('Coming soon!'));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      top: 10,
                      bottom: 10,
                    ),
                    child: Row(
                      children: [
                        Image.asset("assets/images/logo.png", height: 56),
                        SizedBox(width: 12),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 0,
                      right: 0,
                      top: 2,
                      bottom: 10,
                    ),
                    child: Row(
                      children: [
                        _buildStatItem('0.0 DT', "Earnings"),
                        _buildStatItem('0', "Deliveries"),
                        _buildStatItem('0.0', "Rating"),
                        _buildStatItem('0h', "Active"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: middleContent),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Available',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Active',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF16AA6B),
        unselectedItemColor: Color(0xFFB6B6B6),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
