import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

// Step1 is shared
import 'screens/client/signup_step1.dart';

// Client step2
import 'screens/client/signup_step2.dart' as client;
import 'screens/client/available_offers.dart';
import 'screens/partner/signup_step2.dart' as partner;
import 'screens/partner/signup_step1.dart' as partner1;
import 'screens/partner/signup_step3.dart' as partner3;
import 'screens/partner/signup_step4.dart' as partner4;
import 'screens/partner/submission.dart' as partnerSubmitted;
import 'screens/partner/dashboard.dart' as partnerDashboard;
import 'screens/signin_page.dart';
import 'screens/client/signin.dart' as clientSignin;
import 'screens/partner/signin.dart' as partnerSignin;

void main() {
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
      home: const SplashScreen(),
      routes: {
        // shared step1
        '/signup1': (_) => const SignupStep1(),

        // role-specific step2 routes
        '/client/signup2': (_) => const client.SignupStep2(),

        // role-specific partner signup routes
        '/partenaire/signup1': (_) => const partner1.PartnerSignupStep1(),
        '/partenaire/signup2': (_) => const partner.PartnerSignupStep2(),
        '/partenaire/signup3': (_) => const partner3.PartnerSignupStep3(),
        '/partenaire/signup4': (_) => const partner4.PartnerSignupStep4(),
        '/partenaire/submitted': (_) =>
            const partnerSubmitted.PartnerSubmissionPage(),
        '/partenaire/dashboard': (_) =>
            const partnerDashboard.PartnerDashboardPage(),

        '/offers': (_) => const AvailableOffersPage(),
        // Sign-in pages for roles
        '/signin/client': (_) => const clientSignin.ClientSignInPage(),
        '/signin/deliverer': (_) => const SignInPage(role: 'Deliverer'),
        '/signin/partner': (_) => const partnerSignin.PartnerSignInPage(),
      },
    );
  }
}
