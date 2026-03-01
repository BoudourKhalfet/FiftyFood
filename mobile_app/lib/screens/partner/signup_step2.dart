import 'package:flutter/material.dart';

class PartnerSignupStep2 extends StatefulWidget {
  const PartnerSignupStep2({Key? key}) : super(key: key);

  @override
  _PartnerSignupStep2State createState() => _PartnerSignupStep2State();
}

class _PartnerSignupStep2State extends State<PartnerSignupStep2> {
  final _formKey = GlobalKey<FormState>();

  final _restaurantNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  String? _selectedType;
  bool _logoSelected = false;
  bool _coverSelected = false;

  final List<String> _types = [
    'Restaurant',
    'Café',
    'Bakery',
    'Food Truck',
    'Supermarket',
  ];

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onBack() => Navigator.of(context).pop();

  void _onContinue() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.of(context).pushNamed('/partenaire/signup3');
    }
  }

  void _pickImage(String type) async {
    // Placeholder handler. Replace with actual image picker integration (image_picker)
    setState(() {
      if (type == 'logo') _logoSelected = true;
      if (type == 'cover') _coverSelected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image picker for $type not implemented yet')));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 289,
      height: 50,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
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
                  'Restaurant information',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Step 2 of 4 — Identity',
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
                    widthFactor: 0.33,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF3D9176), const Color(0xFF2D8066)],
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
                      _buildTextField(
                        controller: _restaurantNameController,
                        label: 'Establishment name',
                        icon: Icons.restaurant,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 289,
                        height: 50,
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          dropdownColor: Colors.white,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Type of establishment',
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
                          items: _types
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedType = v),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address *',
                        icon: Icons.location_on,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City *',
                        icon: Icons.location_city,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      const Text('Branding (optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickImage('logo'),
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: _logoSelected
                                      ? Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check_circle, color: Color(0xFF1F9D7A), size: 28), SizedBox(height: 6), Text('Logo selected')])
                                      : Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.cloud_upload_outlined, size: 28), SizedBox(height: 6), Text('Upload logo')]),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickImage('cover'),
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: _coverSelected
                                      ? Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check_circle, color: Color(0xFF1F9D7A), size: 28), SizedBox(height: 6), Text('Cover selected')])
                                      : Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.image_outlined, size: 28), SizedBox(height: 6), Text('Cover image')]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

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
