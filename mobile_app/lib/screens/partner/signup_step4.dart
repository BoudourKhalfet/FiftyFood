import 'package:flutter/material.dart';

class PartnerSignupStep4 extends StatefulWidget {
  const PartnerSignupStep4({Key? key}) : super(key: key);

  @override
  _PartnerSignupStep4State createState() => _PartnerSignupStep4State();
}

class _PartnerSignupStep4State extends State<PartnerSignupStep4> {
  final _formKey = GlobalKey<FormState>();
  String _method = 'iban';
  final _ibanController = TextEditingController();

  @override
  void dispose() {
    _ibanController.dispose();
    super.dispose();
  }

  void _onBack() => Navigator.of(context).pop();

  void _onSubmit() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.pushReplacementNamed(context, '/partenaire/submitted');
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
                const SizedBox(height: 16),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 120,
                    errorBuilder: (context, error, stack) => const Icon(Icons.fastfood, size: 64),
                  ),
                ),
                const SizedBox(height: 0),
                const Text(
                  'Payout settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Step 4 of 4 — Payment (optional)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3D9176), Color(0xFF2D8066)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3FCF7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Optional at signup', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 8),
                      Text(
                        'You can skip this step and complete it later. However, withdrawals will be blocked until payment information is provided.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(value: 'iban', groupValue: _method, onChanged: (v) => setState(() => _method = v ?? 'iban')),
                  title: const Text('Bank Account (IBAN)'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(value: 'wallet', groupValue: _method, onChanged: (v) => setState(() => _method = v ?? 'wallet')),
                  title: const Text('Mobile Wallet'),
                ),
                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_method == 'iban')
                        TextFormField(
                          controller: _ibanController,
                          decoration: const InputDecoration(
                            labelText: 'IBAN',
                            hintText: 'FR76 1234 5678 9012 3456 7890 1',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_method == 'iban' && (v == null || v.isEmpty)) return 'Required';
                            return null;
                          },
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _onBack,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2D8066), width: 2),
                                foregroundColor: const Color(0xFF2D8066),
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              child: const Text('← Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _onSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F9D7A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
