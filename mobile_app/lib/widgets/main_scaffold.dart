import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/client/profile.dart';
import '../../screens/client/transactions.dart';
import '../api/api_service.dart';
import '../api/auth_storage.dart';
import '../screens/notifications/notifications_page.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;
  final String? userName;
  const MainScaffold({Key? key, required this.child, this.userName})
    : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  String _drawerName = "";
  int _unreadCount = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _loadName();
    _refreshUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    if ((widget.userName ?? "").isNotEmpty) {
      setState(() => _drawerName = widget.userName!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _drawerName = prefs.getString('clientName') ?? '');
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();

    // Revoke device token before sign out (best-effort)
    final token = prefs.getString('fcmRegisteredToken');
    if (token != null && token.isNotEmpty) {
      try {
        final jwt = await getJwt();
        if (jwt != null && jwt.isNotEmpty) {
          await ApiService.delete(
            'notifications/me/device-tokens?token=$token',
            headers: {'Authorization': 'Bearer $jwt'},
          );
        }
      } catch (_) {
        // Best-effort token revocation; don't block logout if it fails
      }
    }

    await prefs.remove('jwt');
    await prefs.remove('clientName');
    await prefs.remove('fcmRegisteredToken');
    await prefs.remove('fcmRegisteredPlatform');
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/signin/client', (route) => false);
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final jwt = await getJwt();
      if (jwt == null || jwt.isEmpty) return;

      final data = await ApiService.get(
        'notifications/me/unread-count',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      final count = (data is Map && data['count'] is num)
          ? (data['count'] as num).toInt()
          : int.tryParse(data?['count']?.toString() ?? '') ?? 0;

      if (!mounted) return;
      setState(() => _unreadCount = count < 0 ? 0 : count);
    } catch (_) {
      // Best-effort refresh.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    _refreshUnreadCount();
  }

  // ---- ADD THIS: Reload name every time the Drawer opens ----
  void _onDrawerChanged(bool opened) {
    if (opened) {
      _loadName();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      onDrawerChanged: _onDrawerChanged, // <-- listen to drawer open/close
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 44,
                      color: Color(0xFF16807A),
                    ),
                    SizedBox(width: 10),
                    Text(
                      _drawerName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ClientProfileScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.receipt_long),
                title: Text('Transactions'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ClientTransactionsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Sign out'),
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo & Text
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10),
                  child: Row(
                    children: [
                      Image.asset("assets/images/logo.png", height: 56),
                      SizedBox(width: 12),
                    ],
                  ),
                ),
                // Hamburger Icon
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_none,
                              color: Color(0xFF1A1A1A),
                              size: 30,
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    _unreadCount > 99
                                        ? '99+'
                                        : _unreadCount.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: _openNotifications,
                      ),
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Color(0xFF1A1A1A),
                            size: 34,
                          ),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: widget.child,
    );
  }
}
