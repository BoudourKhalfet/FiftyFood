import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'LocationConsentPage.dart' as client_consent;
import '../../api/client_profile_service.dart';

class SignupStep2 extends StatefulWidget {
  const SignupStep2({Key? key}) : super(key: key);

  @override
  _SignupStep2State createState() => _SignupStep2State();
}

class _SignupStep2State extends State<SignupStep2> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final List<String> _foodTypes = [
    'BAKERY',
    'GRILL',
    'FAST_FOOD',
    'VEGETARIAN',
    'HALAL',
    'SEAFOOD',
    'SUSHI',
    'PIZZA',
    'BURGER',
    'BBQ',
    'HEALTHY',
    'DESSERT',
    'STREET_FOOD',
    'SANDWICHES',
    'SALAD',
    'PASTA',
    'BREAKFAST',
    'FINE_DINING',
    'BRUNCH',
  ];

  final Map<String, String> _foodEmoji = {
    'BAKERY': '🥖',
    'GRILL': '🔥',
    'FAST_FOOD': '🍟',
    'VEGETARIAN': '🥬',
    'HALAL': '🕌',
    'SEAFOOD': '🐟',
    'SUSHI': '🍣',
    'PIZZA': '🍕',
    'BURGER': '🍔',
    'BBQ': '🍖',
    'HEALTHY': '🥗',
    'DESSERT': '🍰',
    'STREET_FOOD': '🌮',
    'SANDWICHES': '🥪',
    'SALAD': '🥗',
    'PASTA': '🍝',
    'BREAKFAST': '🍳',
    'FINE_DINING': '🍽',
    'BRUNCH': '🥞',
  };

  final Set<String> _selectedFood = {};

  void _toggleFood(String type) {
    setState(() {
      if (_selectedFood.contains(type)) {
        _selectedFood.remove(type);
      } else {
        _selectedFood.add(type);
      }
    });
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  void _onComplete() async {
    if (_formKey.currentState?.validate() == true) {
      if (_selectedFood.isEmpty) {
        setState(() {
          _error = 'Select at least one food preference.';
        });
        return;
      }

      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final jwtToken = prefs.getString('jwt');
        if (jwtToken == null) {
          setState(() => _error = "Not logged in. Please sign in again.");
          return;
        }
        await ApiService.patch(
          'users/me/complete-profile',
          {
            'fullName': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'defaultAddress': _addressController.text.trim(),
            'cuisinePreferences': _selectedFood.toList(),
          },
          headers: {'Authorization': 'Bearer $jwtToken'},
        );

        // fetch latest profile
        final updatedProfile = await ProfileService.getProfile(jwtToken);
        if (updatedProfile.locationConsentGiven != true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => client_consent.LocationConsentPage(),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/offers');
        }
      } catch (e) {
        debugPrint('Profile completion failed: $e');
        setState(() {
          _error =
              'Unable to complete your profile right now. Please try again.';
        });
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 289,
      height: 50,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 120,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.fastfood, size: 64),
                  ),
                ),
                const SizedBox(height: 0),
                // personal info form was inserted earlier
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Default address',
                        icon: Icons.location_on,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Food Preferences',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us personalize your recommendations',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                // custom gradient progress indicator matching design
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onBackground.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.66,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3D9176),
                            const Color(0xFF2D8066),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'What are your food and meals preferences?',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _foodTypes.map((type) {
                    final selected = _selectedFood.contains(type);
                    return GestureDetector(
                      onTap: () => _toggleFood(type),
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.white,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // use emoji according to design
                            Text(
                              _foodEmoji[type] ?? '',
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              type,
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onBack,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF2D8066),
                            width: 2,
                          ),
                          foregroundColor: const Color(0xFF2D8066),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('← Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _onComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F9D7A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Complete Signup'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
