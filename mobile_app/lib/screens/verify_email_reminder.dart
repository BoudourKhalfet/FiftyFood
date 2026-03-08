import 'package:flutter/material.dart';

class VerifyEmailReminderPage extends StatelessWidget {
  const VerifyEmailReminderPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
