import 'package:flutter/material.dart';

class PartnerSignupStep3 extends StatefulWidget {
  const PartnerSignupStep3({Key? key}) : super(key: key);

  @override
  _PartnerSignupStep3State createState() => _PartnerSignupStep3State();
}

class _PartnerSignupStep3State extends State<PartnerSignupStep3> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  String _ownership = 'Owner';

  @override
  void dispose() {
    _legalNameController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  void _onBack() => Navigator.of(context).pop();

  void _onContinue() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.of(context).pushNamed('/partenaire/signup4');
    }
  }

  Widget _uploadRow(String title, {bool required = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF1F9D7A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(required ? 'PDF, JPG — max 5MB' : 'Optional — PDF, JPG — max 5MB', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Upload'))
        ],
      ),
    );
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
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.fastfood,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 0),
                const Text(
                  'Compliance documents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Step 3 of 4 — Legal',
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
                    widthFactor: 0.75,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3D9176), Color(0xFF2D8066)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 289,
                        height: 50,
                        child: TextFormField(
                          controller: _legalNameController,
                          decoration: InputDecoration(
                            labelText: 'Legal entity name',
                            prefixIcon: const Icon(Icons.business, color: Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 289,
                        height: 50,
                        child: TextFormField(
                          controller: _regNumberController,
                          decoration: InputDecoration(
                            labelText: 'Registration number (RNE)',
                            prefixIcon: const Icon(Icons.confirmation_number, color: Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                      ),
                      const SizedBox(height: 12),
                      const Text('Ownership type *', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Radio<String>(
                                value: 'Owner',
                                groupValue: _ownership,
                                onChanged: (v) => setState(() => _ownership = v ?? 'Owner'),
                              ),
                              title: const Text('Owner'),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Radio<String>(
                                value: 'Manager',
                                groupValue: _ownership,
                                onChanged: (v) => setState(() => _ownership = v ?? 'Manager'),
                              ),
                              title: const Text('Manager'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const SizedBox(height: 6),
                      _uploadRow('Business registration document *', required: true),
                      _uploadRow('Hygiene / food safety certificate *', required: true),
                      _uploadRow('Proof of ownership / lease', required: false),

                      const SizedBox(height: 18),

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
                              onPressed: _onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F9D7A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Continue'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
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
}
