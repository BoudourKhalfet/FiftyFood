import 'package:flutter/material.dart';
import './my_orders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/client_profile_service.dart';
import '../../models/client_profile.dart';
import '../../models/client_order.dart';
import 'dart:convert';
import '../../widgets/main_scaffold.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({Key? key}) : super(key: key);

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  int _activeTab = 0;
  String? jwt;

  ClientProfile? profile;
  String email = "";
  bool loading = true;
  String? error;

  List<ClientOrder> orders = [];
  bool savingProfile = false, savingPrefs = false, savingNotifs = false;

  // For edit modal
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final List<String> allCategories = [
    "ITALIAN",
    "JAPANESE",
    "HEALTHY",
    "BURGERS",
    "BAKERY",
    "CAFE",
    "SANDWICHES",
    "VEGAN",
  ];
  final Map<String, String> categoryLabels = {
    "ITALIAN": "Italian",
    "JAPANESE": "Japanese",
    "HEALTHY": "Healthy",
    "BURGERS": "Burgers",
    "BAKERY": "Bakery",
    "CAFE": "Café",
    "SANDWICHES": "Sandwiches",
    "VEGAN": "Vegan",
  };

  // For dietary restrictions:
  final List<String> allDiets = [
    "VEGETARIAN",
    "VEGAN",
    "GLUTEN_FREE",
    "DAIRY_FREE",
    "NUT_FREE",
    "HALAL",
    "NO_RESTRICTIONS",
  ];
  final Map<String, String> dietLabels = {
    "VEGETARIAN": "Vegetarian",
    "VEGAN": "Vegan",
    "GLUTEN_FREE": "Gluten-Free",
    "DAIRY_FREE": "Dairy-Free",
    "NUT_FREE": "Nut-Free",
    "HALAL": "Halal",
    "NO_RESTRICTIONS": "No restrictions",
  };

  // For preferences editing
  late List<String> selectedCategories;
  late List<String> dietaryRestrictions;
  Map<String, bool> notificationSettings = {
    "newOffers": true,
    "orderUpdates": true,
    "promotions": false,
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('jwt');
    if (stored == null) {
      // Should redirect to sign in
      Navigator.of(context).pushReplacementNamed('/signin/client');
      return;
    }
    setState(() {
      jwt = stored;
      loading = true;
    });

    try {
      final fetchedProfile = await ProfileService.getProfile(stored);
      final fetchedOrders = await ProfileService.getOrders(stored);

      await prefs.setString('clientName', fetchedProfile.fullName);

      setState(() {
        profile = fetchedProfile; // ClientProfile!
        email = profile?.email ?? '';
        orders = fetchedOrders;
        selectedCategories = List.from(profile?.cuisinePreferences ?? []);
        dietaryRestrictions = List.from(profile?.dietaryRestrictions ?? []);
        notificationSettings = Map<String, bool>.from(
          profile?.notificationPreferences ?? notificationSettings,
        );
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Failed to load profile: $e";
        loading = false;
      });
    }
  }

  /// ----- UI/BUILD -----
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return MainScaffold(child: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return MainScaffold(
        child: Center(
          child: Text(error!, style: TextStyle(color: Colors.red)),
        ),
      );
    }
    return MainScaffold(
      userName: profile?.fullName ?? '',
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 15, bottom: 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ), // or Colors.black
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                  ],
                ),
              ),
              _profileHeader(context),
              _tabBar(),
              _activeTab == 0
                  ? _ordersTab()
                  : _activeTab == 1
                  ? _preferencesTab()
                  : _settingsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Color(0xFFE8F5F0),
            child: Icon(Icons.person, size: 56, color: Color(0xFF2D8066)),
          ),
          SizedBox(height: 10),
          Text(
            profile?.fullName ?? '-',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(email, style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco_outlined, color: Color(0xFF16807A), size: 18),
              SizedBox(width: 4),
              Text(
                "${orders.length} meals saved",
                style: TextStyle(fontSize: 14, color: Color(0xFF16807A)),
              ),
              SizedBox(width: 16),
              Icon(Icons.star, color: Color(0xFFFBC02D), size: 18),
              SizedBox(width: 4),
              Text(
                "Member since ${profile?.joinedAt?.year ?? '----'}",
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              _nameController.text = profile?.fullName ?? '';
              _phoneController.text = profile?.phone ?? '';
              _addressController.text = profile?.defaultAddress ?? '';
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => _editProfileModal(context),
              );
            },
            icon: Icon(Icons.edit, size: 18),
            label: Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF16807A),
              side: BorderSide(color: Color(0xFF16807A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              textStyle: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _tabBtn("My Orders", 0),
          _tabBtn("Preferences", 1),
          _tabBtn("Settings", 2),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _activeTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.5),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? Color(0xFFE8F5F0) : Colors.white,
          foregroundColor: active ? Color(0xFF16807A) : Color(0xFF6B7280),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w600),
        ),
        icon: index == 0
            ? Icon(Icons.list_alt, size: 18)
            : index == 1
            ? Icon(Icons.restaurant_menu, size: 18)
            : Icon(Icons.settings, size: 18),
        label: Text(label),
        onPressed: () => setState(() => _activeTab = index),
      ),
    );
  }

  Widget _ordersTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MyOrdersPage(),
    );
  }

  Widget _preferencesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Food Categories",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: allCategories
                .map(
                  (cat) => ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _emojiForCategory(cat),
                        SizedBox(width: 5),
                        Text(categoryLabels[cat] ?? cat),
                      ],
                    ),
                    selected: selectedCategories.contains(cat),
                    selectedColor: Color(0xFFE8F5F0),
                    onSelected: (sel) => setState(() {
                      if (sel)
                        selectedCategories.add(cat);
                      else
                        selectedCategories.remove(cat);
                    }),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 20),
          Text(
            "Dietary Restrictions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: allDiets
                .map(
                  (diet) => FilterChip(
                    label: Text(dietLabels[diet] ?? diet),
                    selected: dietaryRestrictions.contains(diet),
                    selectedColor: Color(0xFFE8F5F0),
                    onSelected: (sel) => setState(() {
                      if (sel)
                        dietaryRestrictions.add(diet);
                      else
                        dietaryRestrictions.remove(diet);
                    }),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: savingPrefs ? null : _savePreferences,
              child: savingPrefs
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text("Save Preferences"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF16807A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiForCategory(String cat) {
    switch (cat) {
      case "ITALIAN":
        return Text("🍕", style: TextStyle(fontSize: 18));
      case "JAPANESE":
        return Text("🍣", style: TextStyle(fontSize: 18));
      case "HEALTHY":
        return Text("🥗", style: TextStyle(fontSize: 18));
      case "BURGERS":
        return Text("🍔", style: TextStyle(fontSize: 18));
      case "SANDWICHES":
        return Text("🥪", style: TextStyle(fontSize: 18));
      case "VEGAN":
        return Text("🌱", style: TextStyle(fontSize: 18));
      case "CAFE":
        return Text("☕", style: TextStyle(fontSize: 18));
      case "BAKERY":
        return Text("🥖", style: TextStyle(fontSize: 18));
      default:
        return SizedBox(width: 0, height: 0);
    }
  }

  Widget _settingsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Notifications",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          _notifSwitch("New offers nearby", "newOffers"),
          _notifSwitch("Order updates", "orderUpdates"),
          _notifSwitch("Promotions", "promotions"),
          Divider(height: 30),
          ElevatedButton(
            onPressed: () => _showChangePassword(context),
            child: Text("Change Password"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF16807A),
              side: BorderSide(color: Color(0xFF16807A)),
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: _deleteAccount,
            child: Text("Delete Account"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFFF44336),
              side: BorderSide(color: Color(0xFFF44336)),
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifSwitch(String label, String key) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15)),
        Switch(
          value: notificationSettings[key] ?? false,
          activeColor: Color(0xFF16807A),
          onChanged: savingNotifs
              ? null
              : (val) async {
                  setState(() {
                    notificationSettings[key] = val;
                    savingNotifs = true;
                  });
                  await ProfileService.updateNotifications(
                    jwt!,
                    notificationSettings,
                  );
                  setState(() => savingNotifs = false);
                },
        ),
      ],
    );
  }

  Widget _editProfileModal(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Personal Informations",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _profileTextForm("Full Name", _nameController),
              _profileTextForm("Phone", _phoneController),
              _profileTextForm("Default Address", _addressController),
              SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: savingProfile ? null : () => _saveProfile(),
                  child: savingProfile
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text("Save Changes"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF16807A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTextForm(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => savingProfile = true);
    try {
      await ProfileService.updateProfile(
        jwt!,
        fullName: _nameController.text,
        phone: _phoneController.text,
        defaultAddress: _addressController.text,
      );
      // refetch profile
      final updated = await ProfileService.getProfile(jwt!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('clientName', updated.fullName);
      setState(() {
        profile = updated;
        savingProfile = false;
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                "Profile saved!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF16807A),
          behavior: SnackBarBehavior.floating,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.fromLTRB(24, 0, 24, 24),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => savingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                "Failed to save!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF16807A),
          behavior: SnackBarBehavior.floating,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.fromLTRB(24, 0, 24, 24),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _savePreferences() async {
    setState(() => savingPrefs = true);
    try {
      print('Saving cuisinePreferences: $selectedCategories');
      print('Saving dietaryRestrictions: $dietaryRestrictions');
      await ProfileService.updatePreferences(
        jwt!,
        cuisinePreferences: selectedCategories,
        dietaryRestrictions: dietaryRestrictions,
      );
      setState(() => savingPrefs = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                "Preferences saved!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF16807A),
          behavior: SnackBarBehavior.floating,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.fromLTRB(24, 0, 24, 24),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => savingPrefs = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                "Failed to save!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF16807A),
          behavior: SnackBarBehavior.floating,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.fromLTRB(24, 0, 24, 24),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showChangePassword(BuildContext context) {
    final _currentPwController = TextEditingController();
    final _newPwController = TextEditingController();
    final _confirmPwController = TextEditingController();

    final _passwordRegex = RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );
    bool isValidPassword(String pw) => _passwordRegex.hasMatch(pw);

    String? errorMsg;

    String extractBackendMessage(dynamic error) {
      final str = error.toString();
      final regexp = RegExp(r'\{.*\}');
      final match = regexp.firstMatch(str);
      if (match != null) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(match.group(0)!));
          if (map['message'] is String) return map['message'];
          if (map['message'] is List && map['message'].isNotEmpty) {
            return map['message'][0].toString();
          }
          return map['error'] ?? str;
        } catch (_) {}
      }
      return str;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text("Change Password"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    obscureText: true,
                    controller: _currentPwController,
                    decoration: InputDecoration(labelText: "Current Password"),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    obscureText: true,
                    controller: _newPwController,
                    decoration: InputDecoration(labelText: "New Password"),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    obscureText: true,
                    controller: _confirmPwController,
                    decoration: InputDecoration(
                      labelText: "Confirm New Password",
                    ),
                  ),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        errorMsg!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  final currPw = _currentPwController.text.trim();
                  final newPw = _newPwController.text.trim();
                  final confPw = _confirmPwController.text.trim();

                  // 1. LOCAL FIELD VALIDATION (do NOT go to backend if any fail!)
                  if (currPw.isEmpty) {
                    setModalState(
                      () => errorMsg = "Current password is required.",
                    );
                    return;
                  }
                  if (newPw.isEmpty || confPw.isEmpty) {
                    setModalState(
                      () => errorMsg = "Fill in new password and confirmation.",
                    );
                    return;
                  }
                  if (newPw != confPw) {
                    setModalState(() => errorMsg = "Passwords do not match.");
                    return;
                  }
                  if (!isValidPassword(newPw)) {
                    setModalState(
                      () => errorMsg =
                          "Password must be at least 8 characters and include 1 uppercase, 1 lowercase, 1 number, and 1 special character.",
                    );
                    return;
                  }

                  // 2. NOW do backend call (only if all above pass!)
                  try {
                    await ProfileService.changePassword(jwt!, currPw, newPw);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              "Password changed!",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Color(0xFF16807A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: EdgeInsets.fromLTRB(24, 0, 24, 24),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    final errMsg = extractBackendMessage(e);
                    if (errMsg.contains('Invalid current password')) {
                      setModalState(
                        () => errorMsg = "Your current password is incorrect.",
                      );
                    } else {
                      setModalState(() => errorMsg = errMsg);
                    }
                  }
                },
                child: Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteAccount() async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Are you sure?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ProfileService.deleteAccount(jwt!);
        // Optionally sign user out, clear data, and navigate to login page
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/signin/client', (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  "Failed to delete account!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF16807A),
            behavior: SnackBarBehavior.floating,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: EdgeInsets.fromLTRB(24, 0, 24, 24),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
