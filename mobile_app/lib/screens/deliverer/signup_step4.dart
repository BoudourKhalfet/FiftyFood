import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locationConsentPage.dart';

class DelivererSignupStep4 extends StatefulWidget {
  const DelivererSignupStep4({Key? key}) : super(key: key);

  @override
  State<DelivererSignupStep4> createState() => _DelivererSignupStep4State();
}

class _DelivererSignupStep4State extends State<DelivererSignupStep4> {
  final _formKey = GlobalKey<FormState>();
  String? _payoutMethod;
  final _bankAccountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _paypalEmailController = TextEditingController();
  final _cardHolderNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _edinarHolderNameController = TextEditingController();
  final _edinarNumberController = TextEditingController();
  bool _loading = false;
  String? _error;

  final Map<String, String> _methodLabels = {
    'BANK_TRANSFER': 'Bank Transfer',
    'PAYPAL': 'PayPal',
    'CREDIT_CARD': 'Credit / Visa Card',
    'EDINAR': 'e-Dinar',
  };
  final List<String> _methods = [
    'BANK_TRANSFER',
    'PAYPAL',
    'CREDIT_CARD',
    'EDINAR',
  ];

  @override
  void dispose() {
    _bankAccountHolderController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _paypalEmailController.dispose();
    _cardHolderNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _edinarHolderNameController.dispose();
    _edinarNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      setState(() {
        _error = "Please fill payout details, or skip for now.";
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw "Not logged in.";

      dynamic details;
      switch (_payoutMethod) {
        case 'BANK_TRANSFER':
          details = {
            'accountHolder': _bankAccountHolderController.text.trim(),
            'bankName': _bankNameController.text.trim(),
            'iban': _ibanController.text.trim().replaceAll(' ', ''),
          };
          break;
        case 'PAYPAL':
          details = {'paypalEmail': _paypalEmailController.text.trim()};
          break;
        case 'CREDIT_CARD':
          details = {
            'cardHolderName': _cardHolderNameController.text.trim(),
            'cardNumber': _cardNumberController.text.trim().replaceAll(' ', ''),
            'expiryDate': _cardExpiryController.text.trim(),
          };
          break;
        case 'EDINAR':
          details = {
            'cardHolderName': _edinarHolderNameController.text.trim(),
            'edinarNumber': _edinarNumberController.text.trim().replaceAll(' ', ''),
          };
          break;
        default:
          details = {};
      }

      await ApiService.patch(
        'livreur/onboarding/profile',
        {'payoutMethod': _payoutMethod, 'payoutDetails': details},
        headers: {'Authorization': 'Bearer $jwt'},
      );
      await ApiService.post(
        'livreur/onboarding/submit',
        {},
        headers: {'Authorization': 'Bearer $jwt'},
      );

      // --- Email verification check and navigation ---
      final userResponse = await ApiService.get(
        'auth/me',
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (userResponse['emailVerifiedAt'] == null) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/verify_email_reminder', arguments: 'livreur');
        return;
      }
      final profile = await ApiService.get(
        'livreur/onboarding/me',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (profile['locationConsentGiven'] != true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LocationConsentPage()),
        );
      } else {
        Navigator.of(
          context,
        ).pushReplacementNamed('/submitted', arguments: 'livreur');
      }
    } catch (e) {
      setState(() {
        _error = "Payout info failed: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildPaymentFields() {
    switch (_payoutMethod) {
      case 'BANK_TRANSFER':
        return Column(
          children: [
            TextFormField(
              controller: _bankAccountHolderController,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ibanController,
              decoration: const InputDecoration(
                labelText: 'IBAN / Account Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              validator: (v) =>
                  (v == null || v.trim().length < 10)
                      ? 'Enter a valid IBAN/account number'
                      : null,
            ),
          ],
        );
      case 'PAYPAL':
        return TextFormField(
          controller: _paypalEmailController,
          decoration: const InputDecoration(
            labelText: 'PayPal Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      case 'CREDIT_CARD':
        return Column(
          children: [
            TextFormField(
              controller: _cardHolderNameController,
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                hintText: 'Visa / Credit card number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().length < 12)
                      ? 'Enter a valid card number'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardExpiryController,
              decoration: const InputDecoration(
                labelText: 'Expiry Date',
                hintText: 'MM/YY',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        );
      case 'EDINAR':
        return Column(
          children: [
            TextFormField(
              controller: _edinarHolderNameController,
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _edinarNumberController,
              decoration: const InputDecoration(
                labelText: 'e-Dinar Card Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().length < 8)
                      ? 'Enter a valid e-Dinar number'
                      : null,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _skip() async {
    try {
      setState(() => _loading = true);
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw "Not logged in.";

      await ApiService.post(
        'livreur/onboarding/submit',
        {},
        headers: {'Authorization': 'Bearer $jwt'},
      );

      // --- Email verification check and navigation ---
      final userResponse = await ApiService.get(
        'auth/me',
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (userResponse['emailVerifiedAt'] == null) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/verify_email_reminder', arguments: 'livreur');
        return;
      }
      Navigator.of(
        context,
      ).pushReplacementNamed('/submitted', arguments: 'livreur');
    } catch (e) {
      setState(() {
        _error = "Payout info failed: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Info (Optional)'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 180,
                      height: 90,
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.fastfood, size: 64),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "Step 4 of 4",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Payout Information",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3D9176), Color(0xFF2D8066)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Enter payout method and details (optional). You can skip this step and add payout info later.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    value: _payoutMethod,
                    items: _methods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(_methodLabels[m]!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _payoutMethod = v;
                        _bankAccountHolderController.clear();
                        _bankNameController.clear();
                        _ibanController.clear();
                        _paypalEmailController.clear();
                        _cardHolderNameController.clear();
                        _cardNumberController.clear();
                        _cardExpiryController.clear();
                        _edinarHolderNameController.clear();
                        _edinarNumberController.clear();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Payout Method",
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_payoutMethod != null) ...[
                    _buildPaymentFields(),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _skip,
                          child: const Text('Skip for now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F9D7A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text("Save & Finish"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
