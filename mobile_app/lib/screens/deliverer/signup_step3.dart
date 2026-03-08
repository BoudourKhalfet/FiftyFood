import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_service.dart';
import 'signup_step4.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class DelivererSignupStep3 extends StatefulWidget {
  final String fullName, phone, vehicleType, zone;
  final String? photoUrl;
  const DelivererSignupStep3({
    Key? key,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.zone,
    this.photoUrl,
  }) : super(key: key);

  @override
  State<DelivererSignupStep3> createState() => _DelivererSignupStep3State();
}

class _DelivererSignupStep3State extends State<DelivererSignupStep3> {
  final _formKey = GlobalKey<FormState>();
  final _cinController = TextEditingController();
  final _termsNameController = TextEditingController();

  // Path for mobile/desktop, bytes/name for web
  String? _licenseLocalPath, _ownershipLocalPath, _vehiclePhotoLocalPath;
  Uint8List? _licenseBytes, _ownershipBytes, _vehiclePhotoBytes;
  String? _licenseFileName, _ownershipFileName, _vehiclePhotoFileName;

  String? _licenseUrl, _ownershipUrl, _vehiclePhotoUrl;
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;

  bool get needsLicense =>
      widget.vehicleType == 'Car' || widget.vehicleType == 'Motorcycle';

  @override
  void dispose() {
    _cinController.dispose();
    _termsNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(
    Function(String? path, Uint8List? bytes, String? fileName) onPicked,
  ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null) {
      if (kIsWeb) {
        print(
          "Web picked: ${result.files.single.name}, ${result.files.single.bytes?.length ?? 0} bytes",
        );
        onPicked(null, result.files.single.bytes, result.files.single.name);
      } else {
        print("Mobile picked: ${result.files.single.path}");
        onPicked(result.files.single.path, null, result.files.single.name);
      }
    }
  }

  Future<void> _onSubmit() async {
    if (_formKey.currentState?.validate() == true &&
        (needsLicense
            ? (_licenseLocalPath != null || _licenseBytes != null)
            : true) &&
        (_ownershipLocalPath != null || _ownershipBytes != null) &&
        _acceptedTerms &&
        _termsNameController.text.trim().isNotEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwt');
        if (jwt == null) throw "Not logged in.";

        // --- Upload docs (sample API - you need to update ApiService.uploadFile to support bytes upload on web) ---
        if (needsLicense &&
            (_licenseLocalPath != null || _licenseBytes != null)) {
          var res = await ApiService.uploadFile(
            'livreur/onboarding/upload/license',
            'file',
            _licenseLocalPath ?? '',
            path: _licenseLocalPath,
            bytes: _licenseBytes,
            fileName: _licenseFileName,
            headers: {'Authorization': 'Bearer $jwt'},
          );
          _licenseUrl = res['licensePhotoUrl'] ?? res['url'];
        }
        if (_ownershipLocalPath != null || _ownershipBytes != null) {
          var res = await ApiService.uploadFile(
            'livreur/onboarding/upload/ownership',
            'file',
            _ownershipLocalPath ?? '',
            path: _ownershipLocalPath,
            bytes: _ownershipBytes,
            fileName: _ownershipFileName,
            headers: {'Authorization': 'Bearer $jwt'},
          );
          if (res['message'] != null &&
              res['message'].toString().toLowerCase().contains(
                'unsupported file type',
              )) {
            setState(() {
              _error = "Not supported file type. Allowed: jpg, jpeg, png, pdf.";
            });
            return;
          }
          _ownershipUrl = res['vehicleOwnershipDocUrl'] ?? res['url'];
        }
        if (_vehiclePhotoLocalPath != null || _vehiclePhotoBytes != null) {
          var res = await ApiService.uploadFile(
            'livreur/onboarding/upload/vehicle',
            'file',
            _vehiclePhotoLocalPath ?? '',
            path: _vehiclePhotoLocalPath,
            bytes: _vehiclePhotoBytes,
            fileName: _vehiclePhotoFileName,
            headers: {'Authorization': 'Bearer $jwt'},
          );
          if (res['message'] != null &&
              res['message'].toString().toLowerCase().contains(
                'unsupported file type',
              )) {
            setState(() {
              _error = "Not supported file type. Allowed: jpg, jpeg, png, pdf.";
            });
            return;
          }
          _vehiclePhotoUrl = res['vehiclePhotoUrl'] ?? res['url'];
        }

        // --- PATCH profile main info + doc URLs: ---
        final patchPayload = {
          'fullName': widget.fullName,
          'phone': widget.phone,
          'vehicleType': widget.vehicleType,
          'zone': widget.zone,
          'cinOrPassportNumber': _cinController.text.trim(),
        };
        if (_licenseUrl != null) {
          patchPayload['licensePhotoUrl'] = _licenseUrl!;
        }
        if (_ownershipUrl != null) {
          patchPayload['vehicleOwnershipDocUrl'] = _ownershipUrl!;
        }
        if (_vehiclePhotoUrl != null) {
          patchPayload['vehiclePhotoUrl'] = _vehiclePhotoUrl!;
        }
        if (widget.photoUrl != null) {
          patchPayload['photoUrl'] = widget.photoUrl!;
        }

        await ApiService.patch(
          'livreur/onboarding/profile',
          {'cinOrPassportNumber': _cinController.text.trim()},
          headers: {'Authorization': 'Bearer $jwt'},
        );

        // --- Accept terms (signature) ---
        await ApiService.post(
          'livreur/onboarding/accept-terms',
          {'name': _termsNameController.text.trim()},
          headers: {'Authorization': 'Bearer $jwt'},
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => const DelivererSignupStep4()),
        );
      } catch (e) {
        setState(() {
          _error = "Profile or docs failed: $e";
        });
      } finally {
        setState(() {
          _loading = false;
        });
      }
    } else {
      setState(() {
        _error = "Please fill all required fields.";
      });
    }
  }

  // Helper for upload field name display
  String _fileDisplay(String? path, String? name) {
    if (path != null) return path.split('/').last;
    if (name != null) return name;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents & Legal'),
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
                      "Step 3 of 4",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Legal Documents",
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
                      widthFactor: 0.75, // Step 3/4 -> 0.75
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
                      "Upload your vehicle and identity documents",
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
                  TextFormField(
                    controller: _cinController,
                    decoration: const InputDecoration(
                      labelText: "CIN or Passport Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (needsLicense) ...[
                    GestureDetector(
                      onTap: () {
                        _pickFile((path, bytes, name) {
                          setState(() {
                            _licenseLocalPath = path;
                            _licenseBytes = bytes;
                            _licenseFileName = name;
                          });
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _fileDisplay(
                                      _licenseLocalPath,
                                      _licenseFileName,
                                    ).isNotEmpty
                                    ? _fileDisplay(
                                        _licenseLocalPath,
                                        _licenseFileName,
                                      )
                                    : 'Upload Driver\'s License',
                                style: TextStyle(
                                  color:
                                      _fileDisplay(
                                        _licenseLocalPath,
                                        _licenseFileName,
                                      ).isNotEmpty
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const Icon(Icons.upload_outlined),
                          ],
                        ),
                      ),
                    ),
                  ],
                  GestureDetector(
                    onTap: () {
                      _pickFile((path, bytes, name) {
                        setState(() {
                          _ownershipLocalPath = path;
                          _ownershipBytes = bytes;
                          _ownershipFileName = name;
                        });
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _fileDisplay(
                                    _ownershipLocalPath,
                                    _ownershipFileName,
                                  ).isNotEmpty
                                  ? _fileDisplay(
                                      _ownershipLocalPath,
                                      _ownershipFileName,
                                    )
                                  : 'Upload Vehicle Ownership Document',
                              style: TextStyle(
                                color:
                                    _fileDisplay(
                                      _ownershipLocalPath,
                                      _ownershipFileName,
                                    ).isNotEmpty
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          const Icon(Icons.upload_outlined),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, top: 2),
                    child: Text(
                      "Allowed formats: jpg, jpeg, png, pdf",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _pickFile((path, bytes, name) {
                        setState(() {
                          _vehiclePhotoLocalPath = path;
                          _vehiclePhotoBytes = bytes;
                          _vehiclePhotoFileName = name;
                        });
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _fileDisplay(
                                    _vehiclePhotoLocalPath,
                                    _vehiclePhotoFileName,
                                  ).isNotEmpty
                                  ? _fileDisplay(
                                      _vehiclePhotoLocalPath,
                                      _vehiclePhotoFileName,
                                    )
                                  : 'Upload Vehicle Photo (Optional)',
                              style: TextStyle(
                                color:
                                    _fileDisplay(
                                      _vehiclePhotoLocalPath,
                                      _vehiclePhotoFileName,
                                    ).isNotEmpty
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          const Icon(Icons.upload_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Divider(height: 32, thickness: 2),
                  // Terms & signature visually separated!
                  const Text(
                    "Agreement",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms of Service and Privacy Policy',
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _termsNameController,
                    decoration: const InputDecoration(
                      labelText: "Type your full name as signature",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Signature required' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F9D7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Continue"),
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
