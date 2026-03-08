import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

// Step1 is shared
import 'screens/client/signup_step1.dart';

import 'screens/client/signup_step2.dart' as client;
import 'screens/client/available_offers.dart';
import 'screens/partner/signup_step2.dart' as partner;
import 'screens/partner/signup_step1.dart' as partner1;
import 'screens/partner/signup_step3.dart' as partner3;
import 'screens/partner/signup_step4.dart' as partner4;
import 'screens/submission.dart' as Submitted;
import 'screens/partner/dashboard.dart' as partnerDashboard;
import 'screens/pending_approval.dart';
import 'screens/signin_page.dart';
import 'screens/client/signin.dart' as clientSignin;
import 'screens/partner/signin.dart' as partnerSignin;
import 'screens/verify_email_reminder.dart';
import 'constants/api.dart';
import 'screens/forgot_password_page.dart';
import 'screens/reset_password_page.dart';

void main() {
  print('CURRENT API BASE URL: $apiBaseUrl');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FiftyFood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        print('ROUTER: ${settings.name}');
        // Reset password (extract token from query for web, or arguments for mobile)
        if (settings.name != null &&
            settings.name!.startsWith('/reset-password')) {
          String? token;

          // Extract token from URL query string (web)
          final uri = Uri.parse(settings.name!);
          token = uri.queryParameters['token'];

          // Use argument if it came from Navigator.pushNamed (mobile/deep link)
          if (settings.arguments != null && settings.arguments is String) {
            token = settings.arguments as String;
          }
          return MaterialPageRoute(
            builder: (_) => ResetPasswordPage(token: token),
            settings: settings,
          );
        }

        if (settings.name == '/' || settings.name == null) {
          // Your root page, probably a splash screen or onboarding
          return MaterialPageRoute(
            builder: (_) => const SplashScreen(),
            settings: settings,
          );
        }

        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/signup1':
            return MaterialPageRoute(builder: (_) => const SignupStep1());
          case '/client/signup2':
            return MaterialPageRoute(
              builder: (_) => const client.SignupStep2(),
            );
          case '/partenaire/signup1':
            return MaterialPageRoute(
              builder: (_) => const partner1.PartnerSignupStep1(),
            );
          case '/partenaire/signup2':
            return MaterialPageRoute(
              builder: (_) => const partner.PartnerSignupStep2(),
            );
          case '/partenaire/signup3':
            return MaterialPageRoute(
              builder: (_) => const partner3.PartnerSignupStep3(),
            );
          case '/partenaire/signup4':
            return MaterialPageRoute(
              builder: (_) => const partner4.PartnerSignupStep4(),
            );
          case '/submitted':
            return MaterialPageRoute(
              builder: (_) => const Submitted.PartnerSubmissionPage(),
            );
          case '/partenaire/dashboard':
            return MaterialPageRoute(
              builder: (_) => const partnerDashboard.PartnerDashboardPage(),
            );
          case '/pending_approval':
            return MaterialPageRoute(
              builder: (_) => const PendingApprovalPage(),
            );
          case '/offers':
            return MaterialPageRoute(
              builder: (_) => const AvailableOffersPage(),
            );
          case '/signin/client':
            return MaterialPageRoute(
              builder: (_) => const clientSignin.ClientSignInPage(),
            );
          case '/signin/deliverer':
            return MaterialPageRoute(
              builder: (_) => const SignInPage(role: 'Deliverer'),
            );
          case '/signin/partner':
            return MaterialPageRoute(
              builder: (_) => const partnerSignin.PartnerSignInPage(),
            );
          case '/verify_email_reminder':
            return MaterialPageRoute(
              builder: (_) => const VerifyEmailReminderPage(),
            );
          case '/forgot-password':
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordPage(),
            );
          // add any extra routes as needed...
          default:
            // Optionally show a not found/404 page
            return MaterialPageRoute(
              builder: (_) =>
                  Scaffold(body: Center(child: Text('Page not found'))),
            );
        }
      },
    );
  }
}
