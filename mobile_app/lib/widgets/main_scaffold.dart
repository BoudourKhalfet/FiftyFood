import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/client/profile.dart';

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

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    if ((widget.userName ?? "").isNotEmpty) {
      setState(() => _drawerName = widget.userName!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _drawerName = prefs.getString('clientName') ?? '');
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('clientName');
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/signin/client', (route) => false);
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
                leading: Icon(Icons.logout),
                title: Text('Sign out'),
                onTap: () => _signOut(context),
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
                  child: Builder(
                    builder: (context) => IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: Color(0xFF1A1A1A),
                        size: 34,
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
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
