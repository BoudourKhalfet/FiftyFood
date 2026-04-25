import 'package:flutter/material.dart';
import 'client/signin.dart' as client_signin;
import 'partner/signin.dart' as partner_signin;
import 'signin_page.dart';

class PendingApprovalPage extends StatelessWidget {
  final String role;

  const PendingApprovalPage({Key? key, this.role = 'restaurant'})
    : super(key: key);

  void _backToSignIn(BuildContext context) {
    final normalizedRole = role.toLowerCase();

    Widget destination;
    switch (normalizedRole) {
      case 'client':
        destination = const client_signin.ClientSignInPage();
        break;
      case 'livreur':
      case 'deliverer':
        destination = const SignInPage(role: 'Deliverer');
        break;
      case 'restaurant':
      case 'commercant':
      case 'partner':
      default:
        destination = const partner_signin.PartnerSignInPage();
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
          onPressed: () => _backToSignIn(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pending Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.schedule,
                    size: 60,
                    color: Color(0xFFFB923C),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Heading
              const Text(
                'Pending Approval',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Your registration is under review. An administrator will validate your documents shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _backToSignIn(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1F9D7A), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Sign In',
                    style: TextStyle(
                      color: Color(0xFF1F9D7A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
