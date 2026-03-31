import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_service.dart';
import 'package:file_picker/file_picker.dart';

class PartnerSignupStep3 extends StatefulWidget {
  const PartnerSignupStep3({Key? key}) : super(key: key);

  @override
  _PartnerSignupStep3State createState() => _PartnerSignupStep3State();
}

class _PartnerSignupStep3State extends State<PartnerSignupStep3> {
  final _legalNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _termsNameController = TextEditingController();
  String _ownership = 'Owner';
  bool _loading = false;
  String? _error;

  bool _acceptedHygiene = false;
  bool _acceptedNoPreparation = false;
  bool _acceptedLiability = false;

  String? _businessRegFileName, _hygieneCertFileName, _ownershipFileName;
  bool _businessRegUploading = false,
      _hygieneCertUploading = false,
      _ownershipUploading = false;

  @override
  void dispose() {
    _legalNameController.dispose();
    _regNumberController.dispose();
    _termsNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadDoc(String type) async {
    setState(() {
      if (type == 'business-registration') _businessRegUploading = true;
      if (type == 'hygiene-certificate') _hygieneCertUploading = true;
      if (type == 'proof-of-ownership') _ownershipUploading = true;
      _error = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwt');
        final fileName = result.files.single.name;
        final bytes = result.files.single.bytes!;

        await ApiService.uploadFile(
          'restaurant/onboarding/upload/$type',
          'file',
          '',
          bytes: bytes,
          fileName: fileName,
          headers: {'Authorization': 'Bearer $jwt'},
        );

        setState(() {
          if (type == 'business-registration') _businessRegFileName = fileName;
          if (type == 'hygiene-certificate') _hygieneCertFileName = fileName;
          if (type == 'proof-of-ownership') _ownershipFileName = fileName;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$type uploaded!')));
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to upload $type: $e';
      });
    } finally {
      setState(() {
        _businessRegUploading = false;
        _hygieneCertUploading = false;
        _ownershipUploading = false;
      });
    }
  }

  Widget _uploadRow(
    String label,
    String type, {
    bool required = false,
    String? fileName,
    bool uploading = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: uploading ? null : () => _pickAndUploadDoc(type),
        child: Container(
          height: 90,
          margin: const EdgeInsets.only(bottom: 12, right: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
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
                        size: 24,
                      ),
                      const SizedBox(height: 3),
                      Flexible(
                        child: Text(
                          'Uploaded: $fileName',
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 24),
                      const SizedBox(height: 3),
                      Text(label, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _onBack() => Navigator.of(context).pop();

  String? _validateAll() {
    if (_legalNameController.text.trim().isEmpty) {
      return "Legal entity name is required.";
    }
    if (_legalNameController.text.trim().length < 3) {
      return "Legal entity name must be at least 3 characters.";
    }
    if (!RegExp(
      r"^[\w\s\-,.&']+$",
    ).hasMatch(_legalNameController.text.trim())) {
      return "Use only letters, numbers, and basic punctuation for name.";
    }
    if (_regNumberController.text.trim().isEmpty) {
      return "Registration number (RNE) is required.";
    }
    if (!(_ownership == "Owner" || _ownership == "Manager")) {
      return "Select an ownership type.";
    }
    if (_businessRegFileName == null) {
      return "Please upload your Registration Document.";
    }
    if (_hygieneCertFileName == null) {
      return "Please upload your Hygiene Certificate.";
    }
    if (!_acceptedHygiene || !_acceptedNoPreparation || !_acceptedLiability) {
      return "You must agree to all legal agreements.";
    }
    if (_termsNameController.text.trim().isEmpty) {
      return "Type your full name as signature.";
    }
    return null;
  }

  void _onContinue() async {
    final validationError = _validateAll();
    if (validationError != null) {
      setState(() {
        _error = validationError;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Navigator.of(context).pushNamed('/partenaire/signup4');
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _onBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 110,
                    height: 76,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.fastfood, size: 64),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Compliance documents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Step 3 of 4 — Legal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                ),
                // Progress bar
                Container(
                  height: 6,
                  margin: const EdgeInsets.only(top: 22, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.13),
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
                // CARD for legal info
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.07),
                        blurRadius: 13,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 52,
                        child: TextFormField(
                          controller: _legalNameController,
                          decoration: InputDecoration(
                            labelText: 'Legal entity name',
                            prefixIcon: const Icon(
                              Icons.business,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "This field is required";
                            }
                            if (value.trim().length < 3) {
                              return "Name is too short (min 3 chars)";
                            }
                            if (!RegExp(
                              r"^[\w\s\-,.&']+$",
                            ).hasMatch(value.trim())) {
                              return "Use only letters, numbers, and basic punctuation";
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        child: TextFormField(
                          controller: _regNumberController,
                          decoration: InputDecoration(
                            labelText: 'Registration number (RNE)',
                            prefixIcon: const Icon(
                              Icons.confirmation_number,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Ownership type *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<String>(
                          value: 'Owner',
                          groupValue: _ownership,
                          onChanged: (v) =>
                              setState(() => _ownership = v ?? 'Owner'),
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
                          onChanged: (v) =>
                              setState(() => _ownership = v ?? 'Manager'),
                        ),
                        title: const Text('Manager'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Upload required documents',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _uploadRow(
                      'Registration\nDocument',
                      'business-registration',
                      required: true,
                      fileName: _businessRegFileName,
                      uploading: _businessRegUploading,
                    ),
                    _uploadRow(
                      'Hygiene\nCertificate',
                      'hygiene-certificate',
                      required: true,
                      fileName: _hygieneCertFileName,
                      uploading: _hygieneCertUploading,
                    ),
                    _uploadRow(
                      'Ownership/\nLease (opt)',
                      'proof-of-ownership',
                      required: false,
                      fileName: _ownershipFileName,
                      uploading: _ownershipUploading,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(height: 36, thickness: 1.5),
                const Text(
                  "Agreement",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                // Agreement Checkboxes (FIXED: No Expanded in Row!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedHygiene,
                            onChanged: (v) =>
                                setState(() => _acceptedHygiene = v ?? false),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              'I am solely responsible for the hygiene of the dishes sold via FiftyFood.',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedNoPreparation,
                            onChanged: (v) => setState(
                              () => _acceptedNoPreparation = v ?? false,
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              'FiftyFood neither prepares nor stores the dishes.',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedLiability,
                            onChanged: (v) =>
                                setState(() => _acceptedLiability = v ?? false),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              'In the event of food poisoning, the company (restaurant) assumes 100% responsibility.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: TextFormField(
                          controller: _termsNameController,
                          decoration: const InputDecoration(
                            labelText: "Type your full name as signature",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Signature required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                // ---- ERROR is shown ONLY HERE ----
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.left,
                    ),
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 26),
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
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: const Text('← Back'),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F9D7A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
