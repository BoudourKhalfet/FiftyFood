import 'package:flutter/material.dart';
import 'available_deliveries.dart';

class DelivererSignupStep2 extends StatefulWidget {
  const DelivererSignupStep2({Key? key}) : super(key: key);

  @override
  _DelivererSignupStep2State createState() => _DelivererSignupStep2State();
}

class _DelivererSignupStep2State extends State<DelivererSignupStep2> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedVehicle;
  String? _selectedZone;
  String? _proofFileName;
  bool _agreePrivacy = false;

  final List<String> _vehicles = ['Car', 'Motorcycle', 'Bicycle', 'Electric Scooter'];
  final List<String> _zones = ['Downtown', 'Suburbs', 'Airport', 'Business District'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _completeSignup() {
    if (_formKey.currentState?.validate() == true &&
        _selectedVehicle != null &&
        _selectedZone != null &&
        _proofFileName != null &&
        _agreePrivacy) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AvailableDeliveries()),
      );
    } else if (!_agreePrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to privacy policy')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
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
                const SizedBox(height: 12),
                const Text(
                  'Signup Complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)),
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
                const SizedBox(height: 6),
                const Text(
                  'Your profile is complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Enter your full name',
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Enter your phone number',
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Your Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Enter your address',
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedVehicle,
                        items: _vehicles
                            .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedVehicle = val),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.directions_car_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Select your vehicle',
                        ),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Proof of ownership', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() => _proofFileName = 'Document.pdf');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.description_outlined, color: Color(0xFF6B7280)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _proofFileName ?? 'Upload Proof',
                                  style: TextStyle(color: _proofFileName != null ? Colors.black : Color(0xFF6B7280)),
                                ),
                              ),
                              const Icon(Icons.upload_outlined, color: Color(0xFF1F9D7A)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Preferred Zone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedZone,
                        items: _zones
                            .map((z) => DropdownMenuItem<String>(value: z, child: Text(z)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedZone = val),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Select your zone',
                        ),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _agreePrivacy,
                        onChanged: (val) => setState(() => _agreePrivacy = val ?? false),
                        title: const Text('I agree to Privacy Policy', style: TextStyle(fontSize: 14)),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1F9D7A), width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Icon(Icons.arrow_back, color: Color(0xFF1F9D7A)), SizedBox(width: 4), Text('Back', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F9D7A)))],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _completeSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F9D7A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Text('Complete Signup', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(width: 4), Icon(Icons.arrow_forward, size: 18)],
                              ),
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
