import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/api/client_profile_service.dart';
import '../api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/client/LocationConsentPage.dart' as client_consent;
import '../screens/deliverer/LocationConsentPage.dart' as deliverer_consent;
import '../screens/deliverer/signup_step3.dart';
import '../l10n/app_localizations.dart';

class SignInPage extends StatefulWidget {
  final String role;
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
  bool _loading = false;
  String? _error;
  bool _isEmailNotVerified = false;
  bool _sendingResend = false;
  String? _resendInfo;

  void _handleLogin() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _loading = true;
      _error = null;
      _isEmailNotVerified = false;
      _resendInfo = null;
    });
    try {
      final response = await ApiService.post('auth/login', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
      });

      final dynamic messageField = response['message'];
      final dynamic nestedCode = messageField is Map<String, dynamic>
          ? messageField['code']
          : null;
      final String code = (response['code'] ?? nestedCode ?? '')
          .toString()
          .toUpperCase();
      final String messageText = messageField is String
          ? messageField
          : (messageField is Map<String, dynamic>
                ? (messageField['message']?.toString() ??
                      messageField['reason']?.toString() ??
                      messageField['code']?.toString() ??
                      '')
                : '');

      if (code == 'EMAIL_NOT_VERIFIED') {
        setState(() {
          _error = AppLocalizations.of(context)!.errorEmailNotVerified;
          _isEmailNotVerified = true;
        });
        return;
      }

      if (code == 'ACCOUNT_SUSPENDED' ||
          messageText.toLowerCase().contains('suspended')) {
        setState(() {
          _error = AppLocalizations.of(context)!.errorAccountSuspended;
        });
        return;
      }

      if (response['error'] == 'Unauthorized') {
        if (messageText.toLowerCase().contains('account does not exist')) {
          setState(() {
            _error = AppLocalizations.of(context)!.errorAccountDoesNotExist;
          });
          return;
        }
        setState(() {
          _error = AppLocalizations.of(context)!.errorInvalidCredentials;
        });
        return;
      }
      if (response['error'] == 'Forbidden') {
        setState(() {
          _error = AppLocalizations.of(context)!.errorForbidden;
        });
        return;
      }
      if (response['message'] != null &&
          (response['accessToken'] == null &&
              response['onboardingToken'] == null)) {
        debugPrint('Login rejected response: ${response['message']}');
        setState(() {
          _error = AppLocalizations.of(context)!.errorInvalidCredentials;
        });
        return;
      }
      // Handle login success flows
      final onboardingToken = response['onboardingToken'];
      final accessToken = response['accessToken'];
      final requiresOnboarding = response['requiresOnboarding'] == true;
      final nextOnboardingStep = response['nextOnboardingStep'];
      final user = response['user'];

      final prefs = await SharedPreferences.getInstance();

      if (user != null && user['emailVerified'] == false) {
        setState(() {
          _error = AppLocalizations.of(context)!.errorEmailNotVerified;
          _isEmailNotVerified = true;
        });
        return;
      }

      final realToken = accessToken ?? onboardingToken;
      if (realToken != null && user != null) {
        await prefs.setString('jwt', realToken);

        // Check if user role matches the signin page role
        final userRole = user['role']?.toString().toUpperCase() ?? '';
        final expectedRole = widget.role.toUpperCase() == 'DELIVERER'
            ? 'LIVREUR'
            : widget.role.toUpperCase();

        if (userRole != expectedRole) {
          setState(() {
            _error = AppLocalizations.of(
              context,
            )!.errorRoleMismatch(user['role'].toString(), widget.role);
          });
          return;
        }

        // Resume onboarding from the exact incomplete step returned by backend.
        if (requiresOnboarding) {
          final int step = (nextOnboardingStep is int)
              ? nextOnboardingStep
              : int.tryParse(nextOnboardingStep?.toString() ?? '') ?? 2;

          if (user['role'] == 'CLIENT') {
            Navigator.of(context).pushReplacementNamed('/client/signup2');
            return;
          }

          if (user['role'].toString().toUpperCase() == 'LIVREUR') {
            if (step <= 2) {
              Navigator.of(context).pushReplacementNamed('/deliverer/signup2');
              return;
            }

            if (step == 3) {
              try {
                final p = await ApiService.get(
                  'livreur/onboarding/me',
                  headers: {'Authorization': 'Bearer $realToken'},
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => DelivererSignupStep3(
                      fullName: (p['fullName'] ?? '').toString(),
                      phone: (p['phone'] ?? '').toString(),
                      vehicleType: (p['vehicleType'] ?? '').toString(),
                      zone: (p['zone'] ?? '').toString(),
                      photoUrl: p['photoUrl']?.toString(),
                    ),
                  ),
                );
              } catch (_) {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/deliverer/signup2');
              }
              return;
            }

            Navigator.of(context).pushReplacementNamed('/deliverer/signup4');
            return;
          }

          if (user['role'].toString().toUpperCase() == 'RESTAURANT') {
            final route = step <= 2
                ? '/partner/signup2'
                : step == 3
                ? '/partner/signup3'
                : '/partner/signup4';
            Navigator.of(context).pushReplacementNamed(route);
            return;
          }
        }

        // Backward compatibility: if backend only returned onboarding token.
        if (onboardingToken != null) {
          if (user['role'] == 'CLIENT') {
            Navigator.of(context).pushReplacementNamed('/client/signup2');
            return;
          }
          if (user['role'].toString().toUpperCase() == 'LIVREUR') {
            Navigator.of(context).pushReplacementNamed('/deliverer/signup2');
            return;
          }
          if (user['role'].toString().toUpperCase() == 'RESTAURANT') {
            Navigator.of(context).pushReplacementNamed('/partner/signup2');
            return;
          }
        }

        // ==== CLIENT logic ====
        if (user['role'] == 'CLIENT') {
          try {
            final profile = await ProfileService.getProfile(realToken);
            // You may want to store their name locally, for UX:
            if (profile.fullName != "" && profile.fullName.trim().isNotEmpty) {
              await prefs.setString('clientName', profile.fullName.trim());
            }
          } catch (e) {
            // No action needed here for now.
          }
          if (response['message'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'].toString())),
            );
          }
          if (user['status'] == 'APPROVED') {
            try {
              final profile = await ProfileService.getProfile(realToken);
              if (profile.locationConsentGiven != true) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => client_consent.LocationConsentPage(),
                  ),
                );
              } else {
                Navigator.of(context).pushReplacementNamed('/offers');
              }
            } catch (e) {
              setState(() {
                _error = AppLocalizations.of(context)!.errorNetwork;
              });
            }
          } else {
            // Client is not yet approved, must finish onboarding
            Navigator.of(context).pushReplacementNamed('/client/signup2');
          }
        }
        // ==== DELIVERER logic ====
        else if (user['role'].toString().toUpperCase() == 'LIVREUR') {
          if (user['status'] == 'APPROVED') {
            try {
              // Ping backend to mark as online!
              await ApiService.post('livreur/onboarding/ping', {});
            } catch (e) {
              debugPrint('Deliverer ping failed: $e');
            }
            try {
              final profile = await ApiService.getDelivererProfile(realToken);
              if (profile.locationConsentGiven != true) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => deliverer_consent.LocationConsentPage(),
                  ),
                );
              } else {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/deliverer/dashboard');
              }
            } catch (e) {
              if (e.toString().contains('PROFILE_INCOMPLETE')) {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/deliverer/signup2');
              } else {
                setState(() {
                  _error = AppLocalizations.of(context)!.errorNetwork;
                });
              }
            }
          } else if (user['status'] == 'PENDING') {
            Navigator.of(context).pushReplacementNamed('/pending_approval');
          } else if (user['status'] == 'REJECTED') {
            Navigator.of(context).pushReplacementNamed('/rejected');
          } else {
            // fallback: treat as incomplete
            Navigator.of(context).pushReplacementNamed('/deliverer/signup2');
          }
        } else if (user['role'].toString().toUpperCase() == 'RESTAURANT') {
          if (user['status'] == 'APPROVED') {
            // If your API returns restaurantProfile or similar, check onboarding completeness here if needed.
            Navigator.of(context).pushReplacementNamed('/partner/dashboard');
          } else if (user['status'] == 'PENDING') {
            Navigator.of(context).pushReplacementNamed('/pending_approval');
          } else if (user['status'] == 'REJECTED') {
            Navigator.of(context).pushReplacementNamed('/rejected');
          } else {
            // fallback: treat as incomplete
            Navigator.of(context).pushReplacementNamed('/partner/signup2');
          }
        } else {
          setState(() {
            _error = AppLocalizations.of(context)!.errorOnboardingNeeded;
          });
        }
      } else {
        setState(() {
          _error = AppLocalizations.of(context)!.errorLoginNoToken;
        });
      }
    } catch (e, st) {
      debugPrint('ERROR in _handleLogin: $e\n$st');
      debugPrint('Error type: ${e.runtimeType}');
      setState(() {
        _error = AppLocalizations.of(context)!.errorNetwork;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _sendingResend = true;
      _resendInfo = null;
    });

    try {
      final response = await ApiService.post('auth/resend-verification-email', {
        'email': _emailController.text.trim(),
      });
      if (response == "" || response['status'] == 'ok') {
        setState(() {
          _resendInfo = AppLocalizations.of(context)!.infoVerificationResent;
        });
      } else {
        setState(() {
          _resendInfo = AppLocalizations.of(context)!.errorResendFailed;
        });
      }
    } catch (e, st) {
      debugPrint('Resend verification failed: $e\n$st');
      setState(() {
        _resendInfo = AppLocalizations.of(context)!.errorResendFailed;
      });
    } finally {
      setState(() => _sendingResend = false);
    }
  }

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
        if (role == 'client')
          Navigator.of(context).pushNamed('/signup1');
        else if (role == 'deliverer')
          Navigator.of(context).pushNamed('/signup1');
        else if (role == 'restaurant')
          Navigator.of(context).pushNamed('/partner/signup1');
      };
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        obscureText: obscure ? _obscure : false,
        validator: (v) => (v == null || v.isEmpty)
            ? AppLocalizations.of(context)!.errorRequired
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDEE7E2), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.6,
            ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      nav.pushReplacementNamed('/home');
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 64,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.fastfood, size: 64, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.signInWelcome,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.signInSubtitle,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // White card with form
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildField(
                            label: AppLocalizations.of(context)!.labelEmail,
                            icon: Icons.email_outlined,
                            controller: _emailController,
                          ),
                          const SizedBox(height: 12),
                          Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              _buildField(
                                label: AppLocalizations.of(
                                  context,
                                )!.labelPassword,
                                icon: Icons.lock_outline,
                                controller: _passwordController,
                                obscure: true,
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/forgot-password');
                                },
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: const Color(0xFF1F9D7A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFF1F9D7A),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_loading)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (!_loading) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // ======= ERROR & RESEND UI: ONLY HERE! =======
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                bottom: 2.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 15,
                                      ),
                                      children: [
                                        TextSpan(text: _error!),
                                        if (_isEmailNotVerified)
                                          TextSpan(
                                            text: "  Resend Email",
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = _sendingResend
                                                  ? null
                                                  : _resendVerificationEmail,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_isEmailNotVerified &&
                                      _resendInfo != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _resendInfo!,
                                        style: TextStyle(
                                          color:
                                              _resendInfo!
                                                  .toLowerCase()
                                                  .contains('sent')
                                              ? Colors.green
                                              : Colors.red,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          // ================================================
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        SizedBox(width: 8),
                        Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.g_mobiledata,
                              color: Color(0xFF1F9D7A),
                            ),
                            label: const Text(
                              'Google',
                              style: TextStyle(color: Color(0xFF1F9D7A)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1F9D7A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.facebook,
                              color: Color(0xFF1F9D7A),
                            ),
                            label: const Text(
                              'Facebook',
                              style: TextStyle(color: Color(0xFF1F9D7A)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1F9D7A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Color(0xFF1A1A1A)),
                            ),
                            TextSpan(
                              text: 'Sign up',
                              style: const TextStyle(
                                color: Color(0xFF1F9D7A),
                                fontWeight: FontWeight.w600,
                              ),
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
