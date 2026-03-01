import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SignInPage extends StatefulWidget {
  final String role; // e.g. 'Client', 'Deliverer', 'Partner'
  const SignInPage({Key? key, this.role = 'Client'}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late TapGestureRecognizer _signUpRecognizer;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _signUpRecognizer.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _signUpRecognizer = TapGestureRecognizer()
      ..onTap = () {
        final role = widget.role.toLowerCase();
        if (role == 'client') Navigator.of(context).pushNamed('/signup1');
        else if (role == 'deliverer') Navigator.of(context).pushNamed('/signup1');
        else if (role == 'partner') Navigator.of(context).pushNamed('/partenaire/signup1');
      };
  }

  Widget _buildField({required String label, required IconData icon, required TextEditingController controller, bool obscure = false}) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        obscureText: obscure ? _obscure : false,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDEE7E2), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Image.asset('assets/images/logo.png', height: 64, errorBuilder: (c, e, s) => const Icon(Icons.fastfood, size: 64, color: Colors.white)),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text('Welcome back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Sign in to continue saving delicious meals', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14))),
              const SizedBox(height: 18),

              // White card with form
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(children: [
                        _buildField(label: 'Email', icon: Icons.email_outlined, controller: _emailController),
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            _buildField(label: 'Password', icon: Icons.lock_outline, controller: _passwordController, obscure: true),
                            IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {},
                              child: Text('Forgot password?', style: TextStyle(color: const Color(0xFF1F9D7A))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState?.validate() == true) {
                                // Navigate to appropriate dashboard based on role
                                final role = widget.role.toLowerCase();
                                if (role == 'client') Navigator.of(context).pushNamed('/offers');
                                else if (role == 'partner') Navigator.of(context).pushNamed('/partenaire/dashboard');
                                else if (role == 'deliverer') Navigator.of(context).pushNamed('/deliverer/dashboard');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF1F9D7A),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: const [Expanded(child: Divider()), SizedBox(width: 8), Text('OR CONTINUE WITH', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))), SizedBox(width: 8), Expanded(child: Divider())]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.g_mobiledata, color: Color(0xFF1F9D7A)),
                          label: const Text('Google', style: TextStyle(color: Color(0xFF1F9D7A))),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F9D7A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.apple, color: Color(0xFF1F9D7A)),
                          label: const Text('Apple', style: TextStyle(color: Color(0xFF1F9D7A))),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F9D7A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: "Don't have an account? ", style: TextStyle(color: Color(0xFF1A1A1A))),
                            TextSpan(
                              text: 'Sign up',
                              style: const TextStyle(color: Color(0xFF1F9D7A), fontWeight: FontWeight.w600),
                              recognizer: _signUpRecognizer,
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
    );
  }
}
