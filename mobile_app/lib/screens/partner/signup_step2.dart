import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../api/api_service.dart';

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
  String? _logoFileName;
  String? _coverFileName;
  bool _logoUploading = false;
  bool _coverUploading = false;
  bool _loading = false;
  String? _error;

  final List<String> _types = [
    'FAST_FOOD',
    'CAFE',
    'BAKERY',
    'RESTAURANT',
    'HOTEL',
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

  void _onContinue() async {
    if (_formKey.currentState?.validate() == true) {
      setState(() => _loading = true);
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      try {
        await ApiService.patch(
          'restaurant/onboarding/identity',
          {
            'restaurantName': _restaurantNameController.text.trim(),
            'establishmentType': _selectedType,
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
          },
          headers: {'Authorization': 'Bearer $jwt'},
        );
        Navigator.of(context).pushNamed('/partenaire/signup3');
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving info: $e")));
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAndUploadImage(String type) async {
    setState(() {
      if (type == 'logo') _logoUploading = true;
      if (type == 'cover') _coverUploading = true;
      _error = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwt');
        final fileName = result.files.single.name;
        final bytes = result.files.single.bytes!;

        final res = await ApiService.uploadFile(
          'restaurant/onboarding/upload/$type',
          'file',
          '', // not needed for bytes
          bytes: bytes,
          fileName: fileName,
          headers: {'Authorization': 'Bearer $jwt'},
        );

        setState(() {
          if (type == 'logo') {
            _logoFileName = fileName;
          } else {
            _coverFileName = fileName;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${type[0].toUpperCase()}${type.substring(1)} uploaded successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Failed to upload image: $e";
      });
    } finally {
      setState(() {
        _logoUploading = false;
        _coverUploading = false;
      });
    }
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

  Widget _uploadImageRow({
    required String label,
    required bool uploading,
    required VoidCallback onUpload,
    required String? fileName,
  }) {
    return Expanded(
      child: InkWell(
        onTap: uploading ? null : onUpload,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: uploading
                ? const CircularProgressIndicator()
                : fileName != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF1F9D7A),
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$label uploaded',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        label == 'Logo'
                            ? Icons.cloud_upload_outlined
                            : Icons.image_outlined,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload $label',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
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
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.fastfood, size: 64),
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
                          colors: [
                            const Color(0xFF3D9176),
                            const Color(0xFF2D8066),
                          ],
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
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
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
                            prefixIcon: const Icon(
                              Icons.business,
                              color: Color(0xFF9CA3AF),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFEF4444),
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFEF4444),
                                width: 1.5,
                              ),
                            ),
                          ),
                          items: _types
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedType = v),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address *',
                        icon: Icons.location_on,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City *',
                        icon: Icons.location_city,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Branding (optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _uploadImageRow(
                            label: 'Logo',
                            uploading: _logoUploading,
                            onUpload: () => _pickAndUploadImage('logo'),
                            fileName: _logoFileName,
                          ),
                          const SizedBox(width: 12),
                          _uploadImageRow(
                            label: 'Cover',
                            uploading: _coverUploading,
                            onUpload: () => _pickAndUploadImage('cover'),
                            fileName: _coverFileName,
                          ),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _onBack,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF2D8066),
                                  width: 2,
                                ),
                                foregroundColor: const Color(0xFF2D8066),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                              ),
                              child: const Text('← Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loading ? null : _onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F9D7A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
