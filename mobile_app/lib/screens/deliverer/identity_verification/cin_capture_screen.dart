import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../api/api_service.dart';
import 'liveness_verification_screen.dart';

class CINCaptureScreen extends StatefulWidget {
  final String fullName;
  final String phone;
  final String vehicleType;
  final String zone;
  final String? photoUrl;

  const CINCaptureScreen({
    Key? key,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.zone,
    this.photoUrl,
  }) : super(key: key);

  @override
  State<CINCaptureScreen> createState() => _CINCaptureScreenState();
}

class _CINCaptureScreenState extends State<CINCaptureScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  late TextRecognizer _textRecognizer;

  final _cinController = TextEditingController();
  Uint8List? _cinFrontImage;
  Uint8List? _cinBackImage;

  bool _loading = false;
  bool _ocrProcessing = false;
  String? _error;
  String? _ocrStatus;

  int _currentStep = 0; // 0: CIN input, 1: Front photo, 2: Back photo, 3: Review, 4: OCR Verification

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
  }

  void _initializeCamera() async {
    final cameras = await availableCameras();
    // Use back camera for CIN card photos
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _cameraController.initialize();
    setState(() {});
  }

  Future<Uint8List> _compressImage(Uint8List imageData) async {
    final image = img.decodeImage(imageData);
    if (image == null) return imageData;

    // Resize to max 1200x1200
    final resized = img.copyResize(
      image,
      width: 1200,
      height: 1200,
      interpolation: img.Interpolation.average,
    );

    // Compress to JPEG with 85% quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _cameraController.takePicture();

      final imageData = await image.readAsBytes();
      final compressed = await _compressImage(imageData);

      setState(() {
        if (_currentStep == 1) {
          _cinFrontImage = compressed;
        } else if (_currentStep == 2) {
          _cinBackImage = compressed;
        }
        _currentStep++;
      });

      if (_currentStep == 3) {
        // Show review screen
        _showReviewDialog();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to capture image: $e';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final imageData = await pickedFile.readAsBytes();
      final compressed = await _compressImage(imageData);

      setState(() {
        if (_currentStep == 1) {
          _cinFrontImage = compressed;
        } else if (_currentStep == 2) {
          _cinBackImage = compressed;
        }
        _currentStep++;
      });

      if (_currentStep == 3) {
        // Show review screen
        _showReviewDialog();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<String?> _performOCR(Uint8List imageBytes) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/cin_front.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFile(tempFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Clean up temp file
      await tempFile.delete();
      await tempDir.delete();

      return recognizedText.text;
    } catch (e) {
      print('OCR Error: $e');
      return null;
    }
  }

  String? _extractCINNumber(String ocrText, String expectedCIN) {
    // Remove all non-alphanumeric characters for comparison
    final cleanExpected = expectedCIN.replaceAll(RegExp(r'[^0-9]'), '');

    // Look for the CIN number in the OCR text
    // CIN numbers are typically 8 digits
    final cinPattern = RegExp(r'\b\d{8}\b');
    final matches = cinPattern.allMatches(ocrText);

    for (final match in matches) {
      final foundCIN = match.group(0);
      if (foundCIN == cleanExpected) {
        return foundCIN;
      }
    }

    // Also try to find any 8-digit number that might be the CIN
    final allNumbers = RegExp(r'\d+').allMatches(ocrText);
    for (final match in allNumbers) {
      final number = match.group(0);
      if (number != null && number.length == 8 && number == cleanExpected) {
        return number;
      }
    }

    return null;
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Your CIN Photos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cinFrontImage != null) ...[
                const Text('Front:'),
                Image.memory(_cinFrontImage!, height: 200),
                const SizedBox(height: 16),
              ],
              if (_cinBackImage != null) ...[
                const Text('Back:'),
                Image.memory(_cinBackImage!, height: 200),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentStep = 1);
            },
            child: const Text('Retake'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyCINWithOCR();
            },
            child: const Text('Verify & Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyCINWithOCR() async {
    if (_cinController.text.isEmpty) {
      setState(() => _error = 'Please enter your CIN number');
      return;
    }

    if (_cinFrontImage == null || _cinBackImage == null) {
      setState(() => _error = 'Please capture both front and back of your CIN');
      return;
    }

    setState(() {
      _ocrProcessing = true;
      _error = null;
      _ocrStatus = 'Analyzing CIN card with OCR...';
    });

    try {
      // Perform OCR on the front image
      final ocrText = await _performOCR(_cinFrontImage!);

      if (ocrText == null || ocrText.isEmpty) {
        setState(() {
          _ocrProcessing = false;
          _error = 'Could not read text from CIN card. Please retake the photo with better lighting.';
          _ocrStatus = null;
        });
        return;
      }

      setState(() => _ocrStatus = 'Verifying CIN number...');

      final enteredCIN = _cinController.text.trim();
      final extractedCIN = _extractCINNumber(ocrText, enteredCIN);

      if (extractedCIN == null) {
        setState(() {
          _ocrProcessing = false;
          _error = 'CIN number verification failed. The number on the card does not match what you entered. Please check and try again.';
          _ocrStatus = null;
        });
        // Reset to allow retry
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentStep = 0;
              _cinFrontImage = null;
              _cinBackImage = null;
              _cinController.clear();
            });
          }
        });
        return;
      }

      setState(() => _ocrStatus = 'CIN verified! Submitting...');
      await _submitCINVerification();

    } catch (e) {
      setState(() {
        _ocrProcessing = false;
        _error = 'OCR verification error: $e. Please try again.';
        _ocrStatus = null;
      });
    }
  }

  Future<void> _submitCINVerification() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw 'Not logged in.';

      final frontBase64 = base64Encode(_cinFrontImage!);
      final backBase64 = base64Encode(_cinBackImage!);

      final response = await ApiService.post(
        'livreur/verify/cin',
        {
          'cinNumber': _cinController.text.trim(),
          'cinFrontImageBase64': 'data:image/jpeg;base64,$frontBase64',
          'cinBackImageBase64': 'data:image/jpeg;base64,$backBase64',
          'ocrVerified': true,
        },
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response['success'] == true) {
        setState(() {
          _ocrProcessing = false;
          _loading = false;
        });

        // Navigate to liveness verification with CIN front image for face comparison
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => LivenessVerificationScreen(
                cinFrontImage: _cinFrontImage,
                cinNumber: _cinController.text.trim(),
              ),
            ),
          );
        }
      } else {
        setState(() {
          _ocrProcessing = false;
          _loading = false;
          _error = response['message'] ?? 'CIN verification failed';
        });

        // Reset for retry on failure
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentStep = 0;
              _cinFrontImage = null;
              _cinBackImage = null;
              _cinController.clear();
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _ocrProcessing = false;
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _cinController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: _currentStep == 0
            ? _buildCINInputStep()
            : _buildCameraStep(),
      ),
    );
  }

  Widget _buildCINInputStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Enter Your CIN Number',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Please enter the CIN number from your national ID card. We\'ll verify it matches the photos you\'ll provide.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          TextFormField(
            controller: _cinController,
            decoration: InputDecoration(
              labelText: 'CIN Number',
              hintText: 'e.g., 12345678',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF3D9176),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraStep() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    CameraPreview(_cameraController),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentStep == 1
                              ? 'Capture Front of CIN'
                              : 'Capture Back of CIN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (_ocrProcessing || _loading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3D9176)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _ocrStatus ?? 'Processing...',
                              style: const TextStyle(
                                color: Color(0xFF3D9176),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: (_ocrProcessing || _loading) ? null : _takePicture,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: const Color(0xFF3D9176),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: (_ocrProcessing || _loading) ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library, color: Color(0xFF3D9176)),
                      label: const Text(
                        'Import from Gallery',
                        style: TextStyle(color: Color(0xFF3D9176)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        side: const BorderSide(color: Color(0xFF3D9176)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}