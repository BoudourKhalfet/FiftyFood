import 'package:flutter/material.dart';
import '../api/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _sent = false;
  String? _error;

  Future<void> _requestReset() async {
    setState(() {
      _error = null;
    });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = "Please enter your email.";
      });
      return;
    }
    try {
      await ApiService.post('auth/request-password-reset', {"email": email});
      setState(() {
        _sent = true;
      });
    } catch (e) {
      setState(() {
        _error = "Something went wrong, please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 56,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.fastfood, size: 56),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Forgot Password",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your email and we'll send you a link to reset your password.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_sent) ...[
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, // text
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 1,
                        ),
                        onPressed: _requestReset,
                        child: const Text(
                          'Send reset link',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ] else ...[
                    const Icon(
                      Icons.mark_email_read_rounded,
                      color: Colors.green,
                      size: 38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "If an account exists for this email,\na reset link has been sent.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green[700], fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
