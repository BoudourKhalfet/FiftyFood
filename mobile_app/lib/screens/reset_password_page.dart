import 'package:flutter/material.dart';
import '../api/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? token;
  const ResetPasswordPage({Key? key, this.token}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  String? _message;
  String? _error;
  bool _submitting = false;

  Future<void> _reset() async {
    final token = widget.token;
    final newPassword = _passwordController.text.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _error = "Reset token missing.";
        _message = null;
      });
      return;
    }
    if (newPassword.length < 6) {
      setState(() {
        _error = "Password too short.";
        _message = null;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });
    try {
      final res = await ApiService.post('auth/reset-password', {
        "token": token,
        "newPassword": newPassword,
      });
      setState(() {
        _message = res['message'] ?? "Password reset!";
        _error = null;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = "Reset failed. Try again.";
        _message = null;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasToken = widget.token != null && widget.token!.isNotEmpty;
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
                    "Reset Password",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter a new password. Minimum 6 characters.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!hasToken) ...[
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Invalid or missing reset link.\nPlease check that you opened the full link from your email.',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "New password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      obscureText: true,
                      enabled: !_submitting,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 1,
                        ),
                        onPressed: _submitting ? null : _reset,
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Reset Password',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
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
