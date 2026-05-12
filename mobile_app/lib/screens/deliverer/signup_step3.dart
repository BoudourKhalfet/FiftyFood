import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:ui'; // for Size
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_service.dart';
import 'identity_verification/liveness_verification_screen.dart';
import 'signup_step4.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;

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

  // CIN Verification state
  Uint8List? _cinFrontImage;
  Uint8List? _cinBackImage;
  bool _cinVerified = false;
  bool _cinVerifying = false;
  String? _cinVerifyError;
  late TextRecognizer _textRecognizer;

  // Face Verification state
  bool _faceVerified = false;

  bool get needsLicense =>
      widget.vehicleType == 'Car' || widget.vehicleType == 'Motorcycle';

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  void dispose() {
    _cinController.dispose();
    _termsNameController.dispose();
    _textRecognizer.close();
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
        onPicked(null, result.files.single.bytes, result.files.single.name);
      } else {
        onPicked(result.files.single.path, null, result.files.single.name);
      }
    }
  }

  Future<void> _startIdentityVerification() async {
    if (_cinController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your CIN number first');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Verify CIN Identity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CIN: ${_cinController.text.trim()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Upload front and back photos of your CIN card:'),
                const SizedBox(height: 16),

                // Front Photo
                _buildPhotoPicker(
                  label: 'Front Photo',
                  image: _cinFrontImage,
                  onCapture: () => _captureCINPhoto('front', setModalState),
                  onGallery: () => _pickCINPhoto('front', setModalState),
                ),
                const SizedBox(height: 12),

                // Back Photo
                _buildPhotoPicker(
                  label: 'Back Photo',
                  image: _cinBackImage,
                  onCapture: () => _captureCINPhoto('back', setModalState),
                  onGallery: () => _pickCINPhoto('back', setModalState),
                ),

                if (_cinVerifyError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _cinVerifyError!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],

                if (_cinVerifying) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifying CIN with OCR...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _cinVerifying
                  ? null
                  : () {
                      Navigator.pop(context);
                      setState(() {
                        _cinFrontImage = null;
                        _cinBackImage = null;
                        _cinVerifyError = null;
                      });
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (_cinFrontImage == null ||
                      _cinBackImage == null ||
                      _cinVerifying)
                  ? null
                  : () => _verifyCINWithOCR(setModalState),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D9176),
              ),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker({
    required String label,
    required Uint8List? image,
    required VoidCallback onCapture,
    required VoidCallback onGallery,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(image, height: 120, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(image == null ? 'Camera' : 'Retake'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _captureCINPhoto(String side, StateSetter setModalState) async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(backCamera, ResolutionPreset.high);
      await controller.initialize();

      if (!mounted) return;

      final image = await showDialog<XFile?>(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 400,
                child: CameraPreview(controller),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final photo = await controller.takePicture();
                        Navigator.pop(context, photo);
                      },
                      child: const Text('Capture'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      await controller.dispose();

      if (image != null) {
        final bytes = await image.readAsBytes();
        final compressed = await _compressImage(bytes);
        setModalState(() {
          if (side == 'front') {
            _cinFrontImage = compressed;
          } else {
            _cinBackImage = compressed;
          }
          _cinVerifyError = null;
        });
      }
    } catch (e) {
      setModalState(() => _cinVerifyError = 'Camera error: $e');
    }
  }

  Future<void> _pickCINPhoto(String side, StateSetter setModalState) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final compressed = await _compressImage(bytes);
        setModalState(() {
          if (side == 'front') {
            _cinFrontImage = compressed;
          } else {
            _cinBackImage = compressed;
          }
          _cinVerifyError = null;
        });
      }
    } catch (e) {
      setModalState(() => _cinVerifyError = 'Gallery error: $e');
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageData) async {
    final image = img.decodeImage(imageData);
    if (image == null) return imageData;
    final resized = img.copyResize(
      image,
      width: 1200,
      height: 1200,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<String?> _performOCR(Uint8List imageBytes) async {
    // ML Kit Text Recognition is not supported on Flutter Web
    if (kIsWeb) {
      print('OCR: Web platform detected, returning null (server-side OCR will be used)');
      return null; // Backend will perform OCR on web
    }

    try {
      // For mobile: Create temporary file for OCR
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/cin.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFile(tempFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      await tempFile.delete();
      await tempDir.delete();

      return recognizedText.text;
    } catch (e) {
      print('OCR Error: $e');
      return null;
    }
  }

  String? _extractCINNumber(String ocrText, String expectedCIN) {
    final cleanExpected = expectedCIN.replaceAll(RegExp(r'[^0-9]'), '');
    final cinPattern = RegExp(r'\b\d{8}\b');
    final matches = cinPattern.allMatches(ocrText);

    for (final match in matches) {
      final foundCIN = match.group(0);
      if (foundCIN == cleanExpected) return foundCIN;
    }

    final allNumbers = RegExp(r'\d+').allMatches(ocrText);
    for (final match in allNumbers) {
      final number = match.group(0);
      if (number != null && number.length == 8 && number == cleanExpected) {
        return number;
      }
    }
    return null;
  }

  Future<void> _verifyCINWithOCR(StateSetter setModalState) async {
    setModalState(() {
      _cinVerifying = true;
      _cinVerifyError = null;
    });

    try {
      final enteredCIN = _cinController.text.trim();

      // On mobile: perform client-side OCR
      // On web: skip client-side OCR and let backend handle it
      if (!kIsWeb) {
        final ocrText = await _performOCR(_cinFrontImage!);

        if (ocrText == null || ocrText.isEmpty) {
          setModalState(() {
            _cinVerifying = false;
            _cinVerifyError = 'Could not read text from CIN. Try better lighting.';
          });
          return;
        }

        final extractedCIN = _extractCINNumber(ocrText, enteredCIN);

        if (extractedCIN == null) {
          setModalState(() {
            _cinVerifying = false;
            _cinVerifyError = 'CIN mismatch! The number on the card does not match what you entered.';
          });
          return;
        }
      }

      // Submit to backend for verification
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw 'Not logged in.';

      final frontBase64 = base64Encode(_cinFrontImage!);
      final backBase64 = base64Encode(_cinBackImage!);

      final response = await ApiService.post(
        'livreur/verify/cin',
        {
          'cinNumber': enteredCIN,
          'cinFrontImageBase64': 'data:image/jpeg;base64,$frontBase64',
          'cinBackImageBase64': 'data:image/jpeg;base64,$backBase64',
          'ocrVerified': !kIsWeb, // true if mobile OCR passed, false on web
        },
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response['success'] == true) {
        Navigator.pop(context); // Close modal
        setState(() {
          _cinVerified = true;
          _cinVerifying = false;
        });

        // Navigate to face verification and wait for result
        if (mounted) {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => LivenessVerificationScreen(
                cinFrontImage: _cinFrontImage,
                cinNumber: enteredCIN,
              ),
            ),
          );

          // If face verification succeeded, mark as verified
          if (result == true) {
            setState(() {
              _faceVerified = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Face verification completed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        setModalState(() {
          _cinVerifying = false;
          _cinVerifyError = response['message'] ?? 'Verification failed';
        });
      }
    } catch (e) {
      setModalState(() {
        _cinVerifying = false;
        _cinVerifyError = 'Error: $e';
      });
    }
  }

  Future<void> _startFaceVerificationOnly() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LivenessVerificationScreen(
          cinFrontImage: _cinFrontImage,
          cinNumber: _cinController.text.trim(),
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _faceVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _onSubmit() async {
    // Check identity verification first
    if (!_cinVerified || !_faceVerified) {
      setState(() {
        _error = 'Please complete identity verification (CIN + Face) before submitting.';
      });
      return;
    }

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
                  // CIN Field with verification status
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cinController,
                          decoration: InputDecoration(
                            labelText: "CIN",
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge),
                            suffixIcon: (_cinVerified && _faceVerified)
                                ? const Icon(Icons.verified, color: Colors.green)
                                : (_cinVerified || _faceVerified)
                                    ? const Icon(Icons.pending, color: Colors.orange)
                                    : null,
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Verification status message
                  if (_cinVerified || _faceVerified) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_cinVerified)
                                  const Text(
                                    'CIN verified',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                if (_faceVerified)
                                  const Text(
                                    'Face verified',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  ElevatedButton.icon(
                    onPressed: (_cinVerified && _faceVerified) || _loading || _cinVerifying
                        ? null
                        : _cinVerified
                            ? _startFaceVerificationOnly
                            : _startIdentityVerification,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: (_cinVerified && _faceVerified)
                          ? Colors.green
                          : _cinVerified
                              ? Colors.orange
                              : const Color(0xFF3D9176),
                    ),
                    icon: Icon(
                      (_cinVerified && _faceVerified)
                          ? Icons.verified
                          : _cinVerified
                              ? Icons.refresh
                              : Icons.verified_user,
                      color: Colors.white,
                    ),
                    label: Text(
                      (_cinVerified && _faceVerified)
                          ? 'Identity Verified ✓'
                          : _cinVerified
                              ? 'Continue Face Verification'
                              : 'Verify Identity (CIN + Face)',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
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