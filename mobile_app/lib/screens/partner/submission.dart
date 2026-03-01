import 'package:flutter/material.dart';
import '../home_screen.dart';

class PartnerSubmissionPage extends StatelessWidget {
  const PartnerSubmissionPage({Key? key}) : super(key: key);

  void _backToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _signIn(BuildContext context) {
    // Navigate to partner sign-in page
    Navigator.pushNamed(context, '/signin/partner');
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: const [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFFFFF4E5),
                      child: Icon(Icons.access_time, size: 32, color: Color(0xFFFFA726)),
                    ),
                    SizedBox(height: 12),
                    Text('Application Submitted!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Your restaurant registration is now', style: TextStyle(color: Color(0xFF6B7280)))),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('Pending Admin Validation', style: TextStyle(color: Color(0xFFE07B0F), fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_outlined, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Expanded(child: Text('An administrator will review your legal documents and validate your account.')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.notifications_none, color: Color(0xFF6B7280)),
                        SizedBox(width: 8),
                        Expanded(child: Text("We'll notify you by in-app notification and email when a decision is made.")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.email_outlined, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Expanded(child: Text("We'll also email you if we need additional documents or changes.")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Expanded(child: Text("Once approved, you'll be able to publish offers and start selling.")),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _backToHome(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2D8066), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('← Back to Home'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _signIn(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F9D7A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sign In'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
