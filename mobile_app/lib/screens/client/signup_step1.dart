import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_service.dart';
import '../../l10n/app_localizations.dart';

class SignupStep1 extends StatefulWidget {
  const SignupStep1({Key? key}) : super(key: key);

  @override
  _SignupStep1State createState() => _SignupStep1State();
}

class _SignupStep1State extends State<SignupStep1> {
  late TapGestureRecognizer _signInRecognizer;
  final _formKey = GlobalKey<FormState>();
  bool _agreed = false;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _clientType = 'NORMAL';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _societyNameController = TextEditingController();
  final _fiscalNumberController = TextEditingController();
  final _proPhoneController = TextEditingController();
  final _proAddressController = TextEditingController();

  @override
  void dispose() {
    _signInRecognizer.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _societyNameController.dispose();
    _fiscalNumberController.dispose();
    _proPhoneController.dispose();
    _proAddressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _signInRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).pushNamed('/signin/client');
  }

  void _onContinue() async {
    if (_formKey.currentState?.validate() == true && _agreed) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final Map<String, dynamic> registerData = {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'role': 'CLIENT',
          'clientType': _clientType,
        };
        if (_clientType == 'PRO') {
          registerData['societyName'] = _societyNameController.text.trim();
          registerData['fiscalNumber'] = _fiscalNumberController.text.trim();
          registerData['proPhone'] = _proPhoneController.text.trim();
          registerData['proAddress'] = _proAddressController.text.trim();
        }
        final response = await ApiService.post('auth/register', registerData);

        // Defensive: Only proceed if backend says user created
        // Check if server said to verify email
        final message = response['message']?.toString().toLowerCase() ?? '';
        if (message.contains('verify your email')) {
          // Show a dialog or "success" banner
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.dialogAlmostThere),
              content: Text(
                AppLocalizations.of(context)!.infoRegistrationSuccess,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.btnOkay),
                ),
              ],
            ),
          );
          setState(() {
            _error = null; // Clear error
          });
        } else if (response['success'] == true ||
            response['statusCode'] == 201 ||
            response['status'] == 'ok') {
          Navigator.of(context).pushNamed('/client/signup2', arguments: _clientType);
        } else {
          setState(() {
            _error = "${response['message'] ?? response.toString()}";
          });
        }
      } catch (e) {
        setState(() {
          _error = AppLocalizations.of(context)!.errorRegistrationFailed(e.toString());
        });
      } finally {
        setState(() {
          _loading = false;
        });
      }
    } else if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorAgreeTerms)),
      );
    }
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 120,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.fastfood, size: 64),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.signupTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.signupSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onBackground.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.33,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3D9176),
                            const Color(0xFF2D8066),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const SizedBox(height: 16),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // only email and password on step1
                      _buildTextField(
                        controller: _emailController,
                        label: AppLocalizations.of(context)!.labelEmail,
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return AppLocalizations.of(context)!.errorRequired;
                          if (!RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                          ).hasMatch(v))
                            return AppLocalizations.of(context)!.errorInvalidEmail;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _passwordController,
                        label: AppLocalizations.of(context)!.labelPassword,
                        icon: Icons.lock,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF9CA3AF),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return AppLocalizations.of(context)!.errorRequired;
                          if (v.length < 8) {
                            return AppLocalizations.of(context)!.errorPasswordLength;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _confirmController,
                        label: AppLocalizations.of(context)!.labelConfirmPassword,
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF9CA3AF),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return AppLocalizations.of(context)!.errorRequired;
                          if (v != _passwordController.text)
                            return AppLocalizations.of(context)!.errorPasswordsNotMatch;
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.errorPasswordLength,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Account Type',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _clientType = 'NORMAL'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _clientType == 'NORMAL'
                                      ? const Color(0xFF2D8066).withOpacity(0.08)
                                      : Colors.white,
                                  border: Border.all(
                                    color: _clientType == 'NORMAL'
                                        ? const Color(0xFF2D8066)
                                        : const Color(0xFF9CA3AF),
                                    width: _clientType == 'NORMAL' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: _clientType == 'NORMAL'
                                          ? const Color(0xFF2D8066)
                                          : const Color(0xFF9CA3AF),
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Normal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _clientType == 'NORMAL'
                                            ? const Color(0xFF2D8066)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Personal account',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _clientType = 'PRO'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _clientType == 'PRO'
                                      ? const Color(0xFF2D8066).withOpacity(0.08)
                                      : Colors.white,
                                  border: Border.all(
                                    color: _clientType == 'PRO'
                                        ? const Color(0xFF2D8066)
                                        : const Color(0xFF9CA3AF),
                                    width: _clientType == 'PRO' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.business,
                                      color: _clientType == 'PRO'
                                          ? const Color(0xFF2D8066)
                                          : const Color(0xFF9CA3AF),
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _clientType == 'PRO'
                                            ? const Color(0xFF2D8066)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Business account',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_clientType == 'PRO') ...[
                        const SizedBox(height: 4),
                        _buildProField(
                          controller: _societyNameController,
                          label: 'Company Name',
                          icon: Icons.apartment,
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildProField(
                          controller: _fiscalNumberController,
                          label: 'Fiscal Number',
                          icon: Icons.numbers,
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildProField(
                          controller: _proPhoneController,
                          label: 'Professional Phone',
                          icon: Icons.phone_in_talk,
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildProField(
                          controller: _proAddressController,
                          label: 'Company Address',
                          icon: Icons.location_city,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (v) {
                              setState(() {
                                _agreed = v ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.labelAgreedTerms,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (_loading) const Center(child: CircularProgressIndicator()),
                      ElevatedButton(
                        onPressed: _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D8066),
                          foregroundColor: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(AppLocalizations.of(context)!.btnContinue),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)!.labelOrContinueWith,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.g_mobiledata,
                                color: Color(0xFF1F2937),
                              ),
                              label: Text(
                                AppLocalizations.of(context)!.btnGoogle,
                                style: const TextStyle(color: Color(0xFF1F2937)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1F9D7A),
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                              label: Text(
                                AppLocalizations.of(context)!.btnFacebook,
                                style: const TextStyle(color: Color(0xFF1F9D7A)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1F9D7A),
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: AppLocalizations.of(context)!.labelAlreadyAccount,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: AppLocalizations.of(context)!.btnSignInSmall,
                                style: const TextStyle(
                                  color: Color(0xFF1F9D7A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                recognizer: _signInRecognizer,
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      width: 289,
      height: 50,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2D8066)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D8066), width: 2),
        ),
      ),
    );
  }
}
