import 'package:flutter/material.dart';
import 'client/signup_step1.dart';
import 'partner/signup_step1.dart';
import 'deliverer/signup_step1.dart';

class VerifyEmailReminderPage extends StatelessWidget {
  final String role;

  const VerifyEmailReminderPage({Key? key, this.role = 'client'})
    : super(key: key);

  void _goBackToSignupStart(BuildContext context) {
    final normalizedRole = role.toLowerCase();

    Widget destination;
    switch (normalizedRole) {
      case 'commercant':
      case 'partner':
      case 'restaurant':
      case 'merchant':
        destination = const PartnerSignupStep1();
        break;
      case 'livreur':
      case 'deliverer':
        destination = const DelivererSignupStep1();
        break;
      case 'client':
      default:
        destination = const SignupStep1();
        break;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => _goBackToSignupStart(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Verify your email to continue',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "You must verify your email to complete your registration. "
                "Check your inbox and spam folder for a verification email. "
                "\n\nYour registration won't be reviewed until you verify your email.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Call API to resend verification email if desired
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Verification email resent.")),
                  );
                },
                icon: Icon(Icons.refresh),
                label: Text('Resend Verification Email'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
