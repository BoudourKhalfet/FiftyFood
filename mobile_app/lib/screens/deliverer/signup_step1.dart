import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'signup_step2.dart';

class DelivererSignupStep1 extends StatefulWidget {
  const DelivererSignupStep1({Key? key}) : super(key: key);

  @override
  _DelivererSignupStep1State createState() => _DelivererSignupStep1State();
}

class _DelivererSignupStep1State extends State<DelivererSignupStep1> {
  late TapGestureRecognizer _signInRecognizer;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _signInRecognizer.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _signInRecognizer = TapGestureRecognizer()..onTap = () => Navigator.of(context).pushNamed('/signin/deliverer');
  }

  void _onContinue() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const DelivererSignupStep2()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
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
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.fastfood,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your delivery partner account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.33,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [const Color(0xFF3D9176), const Color(0xFF2D8066)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Help saving food and money and Join us as Delivery Partner',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 18),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!RegExp(r"^[^@]+@[^@]+\.[^@]+").hasMatch(v)) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock,
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'Must be at least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _confirmController,
                        label: 'Confirm password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Must be at least 8 characters', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _onContinue,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D8066), foregroundColor: Colors.white),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Continue'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'OR CONTINUE WITH',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.g_mobiledata, color: Color(0xFF1F2937)),
                              label: const Text('Google', style: TextStyle(color: Color(0xFF1F2937))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1F9D7A), width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.facebook, color: Color(0xFF1F9D7A)),
                              label: const Text('Facebook', style: TextStyle(color: Color(0xFF1F9D7A))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1F9D7A), width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Already have an account? ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                              TextSpan(
                                text: 'Sign in',
                                style: const TextStyle(color: Color(0xFF1F9D7A), fontWeight: FontWeight.w600, fontSize: 13),
                                recognizer: _signInRecognizer,
                              ),
                            ],
                          ),
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
    );
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
}
