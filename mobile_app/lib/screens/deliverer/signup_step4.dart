import 'package:flutter/material.dart';
import 'available_deliveries.dart';
import '../../api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelivererSignupStep4 extends StatefulWidget {
  const DelivererSignupStep4({Key? key}) : super(key: key);

  @override
  State<DelivererSignupStep4> createState() => _DelivererSignupStep4State();
}

class _DelivererSignupStep4State extends State<DelivererSignupStep4> {
  final _formKey = GlobalKey<FormState>();
  String? _payoutMethod;
  final _payoutDetailsController = TextEditingController();
  bool _loading = false;
  String? _error;

  final Map<String, String> _methodLabels = {
    'BANK_TRANSFER': 'Bank Transfer',
    'MOBILE_WALLET': 'Mobile Wallet',
    'CASH': 'Cash',
    'OTHER': 'Other',
  };
  final List<String> _methods = [
    'BANK_TRANSFER',
    'MOBILE_WALLET',
    'CASH',
    // 'OTHER',
  ];

  final List<String> _wallets = [
    'Paymee',
    'D17',
    'Orange Money',
    'Flouci',
    'Yassir',
    'Other',
  ];
  String? _selectedWalletProvider;

  String get _detailsLabel {
    switch (_payoutMethod) {
      case 'BANK_TRANSFER':
        return "Bank Account Number (IBAN)";
      case 'MOBILE_WALLET':
        return "Wallet Number or Phone";
      case 'CASH':
        return "Notes or further instructions (optional)";
      case 'OTHER':
        return "Describe payout method";
      default:
        return "Payout Details";
    }
  }

  String? _detailsValidator(String? v) {
    if (_payoutMethod == 'CASH') return null;
    if (v == null || v.trim().isEmpty) return "Required";
    if (_payoutMethod == 'BANK_TRANSFER' && v.length < 10)
      return "Enter a valid IBAN/account number";
    if (_payoutMethod == 'MOBILE_WALLET' && v.length < 6)
      return "Enter a valid wallet or phone number";
    return null;
  }

  @override
  void dispose() {
    _payoutDetailsController.dispose();
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

      String? details = _payoutDetailsController.text.trim();
      if (_payoutMethod == 'MOBILE_WALLET' && _selectedWalletProvider != null) {
        details =
            "${_selectedWalletProvider!} - ${_payoutDetailsController.text.trim()}";
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
        Navigator.of(context).pushReplacementNamed('/verify_email_reminder');
        return;
      }
      Navigator.of(context).pushReplacementNamed('/submitted');
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
        Navigator.of(context).pushReplacementNamed('/verify_email_reminder');
        return;
      }
      Navigator.of(context).pushReplacementNamed('/submitted');
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
                        _selectedWalletProvider = null;
                        _payoutDetailsController.clear();
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
                  if (_payoutMethod == 'MOBILE_WALLET') ...[
                    DropdownButtonFormField<String>(
                      value: _selectedWalletProvider,
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(value: w, child: Text(w)),
                          )
                          .toList(),
                      onChanged: (w) {
                        setState(() {
                          _selectedWalletProvider = w;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: "Select Wallet Provider",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      validator: (v) =>
                          (_payoutMethod == 'MOBILE_WALLET' &&
                              (v == null || v.isEmpty))
                          ? 'Choose wallet'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _payoutDetailsController,
                      validator: _detailsValidator,
                      decoration: const InputDecoration(
                        labelText: "Wallet Number or Phone",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ] else if (_payoutMethod != null) ...[
                    TextFormField(
                      controller: _payoutDetailsController,
                      validator: _detailsValidator,
                      decoration: InputDecoration(
                        labelText: _detailsLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.info),
                      ),
                    ),
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
