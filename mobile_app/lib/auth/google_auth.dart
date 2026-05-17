import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

class GoogleAuth {
  /// Minimal Google sign-in helper.
  /// Returns the Firebase ID token (JWT) on success, or null on cancel/failure.
  static Future<String?> signInWithGoogle(
    BuildContext context,
    String role,
  ) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email']);

      await googleSignIn.signOut();
      try {
        await googleSignIn.disconnect();
      } catch (_) {
        // Disconnect is not always supported; sign-out is enough to show the account chooser.
      }
      await FirebaseAuth.instance.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed in with Google')));

      if (idToken != null && idToken.isNotEmpty) {
        try {
          final resp = await ApiService.post('auth/google', {
            'idToken': idToken,
            'role': role,
          });
          final onboardingToken = resp['onboardingToken'];
          final accessToken = resp['accessToken'];
          final realToken = accessToken ?? onboardingToken;
          final user = resp['user'] as Map<String, dynamic>?;
          if (realToken != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('jwt', realToken.toString());
            final role = user?['role']?.toString().toUpperCase() ?? '';
            final status = user?['status']?.toString().toUpperCase() ?? '';
            final requiresOnboarding = resp['requiresOnboarding'] == true;
            final nextStep = resp['nextOnboardingStep'];

            if (requiresOnboarding) {
              if (role == 'CLIENT') {
                final clientType =
                    user?['clientProfile']?['clientType']?.toString() ??
                    'NORMAL';
                Navigator.of(context).pushReplacementNamed(
                  '/client/signup2',
                  arguments: clientType,
                );
              } else if (role == 'LIVREUR') {
                final step = nextStep is int
                    ? nextStep
                    : int.tryParse(nextStep?.toString() ?? '') ?? 2;
                if (step <= 2) {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed('/deliverer/signup2');
                } else if (step == 3) {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed('/deliverer/signup2');
                } else {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed('/deliverer/signup4');
                }
              } else if (role == 'RESTAURANT') {
                final step = nextStep is int
                    ? nextStep
                    : int.tryParse(nextStep?.toString() ?? '') ?? 2;
                final route = step <= 2
                    ? '/partner/signup2'
                    : step == 3
                    ? '/partner/signup3'
                    : '/partner/signup4';
                Navigator.of(context).pushReplacementNamed(route);
              } else {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            } else if (role == 'CLIENT') {
              Navigator.of(context).pushReplacementNamed('/offers');
            } else if (role == 'LIVREUR') {
              Navigator.of(
                context,
              ).pushReplacementNamed('/deliverer/dashboard');
            } else if (role == 'RESTAURANT') {
              Navigator.of(context).pushReplacementNamed('/partner/dashboard');
            } else if (status == 'PENDING') {
              Navigator.of(context).pushReplacementNamed('/pending_approval');
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
            return realToken.toString();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  resp['message']?.toString() ?? 'Unable to complete sign-in',
                ),
              ),
            );
            return null;
          }
        } catch (e) {
          debugPrint('Backend social login failed: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Server error: $e')));
          return null;
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
      );
      return null;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
      return null;
    }
  }
}
