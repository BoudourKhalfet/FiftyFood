import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../api/api_service.dart';
import 'cin_capture_screen.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

// Verification states — like the Python script's classification states
enum VerificationState {
  scanning,     // Looking for face
  faceDetected, // Face found, counting stable frames
  comparing,    // Sending to backend
  matched,      // Face matches CIN
  notMatched,   // Face doesn't match CIN
}

class LivenessVerificationScreen extends StatefulWidget {
  final Uint8List? cinFrontImage;
  final String? cinNumber;

  const LivenessVerificationScreen({
    Key? key,
    this.cinFrontImage,
    this.cinNumber,
  }) : super(key: key);

  @override
  State<LivenessVerificationScreen> createState() =>
      _LivenessVerificationScreenState();
}

class _LivenessVerificationScreenState
    extends State<LivenessVerificationScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  // State machine — mirrors the Python script
  VerificationState _state = VerificationState.scanning;
  List<Face> _detectedFaces = [];
  int _stableFrameCount = 0;
  static const int _framesNeeded = 5; // frames before auto-capture
  bool _isProcessing = false;
  double? _matchScore;
  String? _errorMessage;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _initializeControllerFuture = _cameraController.initialize();
    await _initializeControllerFuture;
    setState(() {});
    // ML Kit face detection works on mobile only; web gets manual-capture fallback
    _startContinuousScan();
  }

  /// Continuous scan loop — like the while(True) loop in the Python script
  void _startContinuousScan() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (_isProcessing ||
          _state == VerificationState.comparing ||
          _state == VerificationState.matched ||
          !_cameraController.value.isInitialized) return;

      _isProcessing = true;
      try {
        final xfile = await _cameraController.takePicture();
        final bytes = await xfile.readAsBytes();

        List<Face> faces = [];

        if (!kIsWeb) {
          // Mobile: use file path — most reliable for ML Kit
          final inputImage = InputImage.fromFilePath(xfile.path);
          faces = await _faceDetector.processImage(inputImage);
        }
        // Web: skip ML Kit (not supported), go straight to stable count
        // so user can still trigger comparison via frame accumulation

        if (!mounted) return;

        if (faces.isNotEmpty || kIsWeb) {
          _stableFrameCount++;
          if (faces.isNotEmpty) {
            setState(() {
              _detectedFaces = faces;
              _state = VerificationState.faceDetected;
            });
          } else if (kIsWeb) {
            // On web just show scanning state but count frames
            setState(() => _state = VerificationState.faceDetected);
          }
          print('[Scan] Frame $_stableFrameCount/$_framesNeeded');

          if (_stableFrameCount >= _framesNeeded) {
            _scanTimer?.cancel();
            await _runComparison(bytes);
          }
        } else {
          setState(() {
            _detectedFaces = [];
            _stableFrameCount = 0;
            _state = VerificationState.scanning;
          });
        }
      } catch (e) {
        print('[Scan] Error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  /// Run backend face comparison (like sending 'V' or 'F' in the Python script)
  Future<void> _runComparison(Uint8List selfieBytes) async {
    setState(() => _state = VerificationState.comparing);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw 'Not logged in.';

      final selfieB64 = base64Encode(selfieBytes);

      // Compare face with CIN photo via backend
      final compareResponse = await ApiService.post(
        'livreur/verify/compare-faces',
        {
          'cinImageBase64': base64Encode(widget.cinFrontImage ?? selfieBytes),
          'selfieImageBase64': selfieB64,
        },
        headers: {'Authorization': 'Bearer $jwt'},
      );

      final isMatch = compareResponse['isMatch'] == true;
      final score = (compareResponse['matchScore'] ?? 0.0).toDouble();

      print('[Compare] isMatch=$isMatch score=$score');

      if (isMatch) {
        // Save verification to backend
        await ApiService.post(
          'livreur/verify/face',
          {
            'selfieImageBase64': 'data:image/jpeg;base64,$selfieB64',
            'livenessVideoBase64': 'data:image/jpeg;base64,$selfieB64',
            'faceMatch': true,
            'cinNumber': widget.cinNumber,
          },
          headers: {'Authorization': 'Bearer $jwt'},
        );

        setState(() {
          _state = VerificationState.matched;
          _matchScore = score;
        });

        // Pop back to Step 3 with success result
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        setState(() {
          _state = VerificationState.notMatched;
          _matchScore = score;
        });

        // Show error dialog — user can retry or go back
        if (mounted) {
          final shouldRetry = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Face Not Matched'),
              content: Text(
                'Your face does not match the CIN photo.\n\nMatch score: ${(score * 100).toStringAsFixed(1)}%\n\nPlease make sure:\n• Good lighting\n• Face the camera directly\n• Remove glasses if possible',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Go Back'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D9176),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );

          if (shouldRetry == true) {
            _resetAndRetry();
          } else {
            // Pop back to Step 3 with failure
            Navigator.of(context).pop(false);
          }
        }
      }
    } catch (e) {
      print('[Compare] Error: $e');
      setState(() {
        _state = VerificationState.notMatched;
        _errorMessage = 'Verification error: $e';
      });

      if (mounted) {
        final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred during verification.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D9176),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        );

        if (shouldRetry == true) {
          _resetAndRetry();
        } else {
          Navigator.of(context).pop(false);
        }
      }
    }
  }

  void _resetAndRetry() {
    setState(() {
      _state = VerificationState.scanning;
      _stableFrameCount = 0;
      _detectedFaces = [];
      _matchScore = null;
      _errorMessage = null;
    });
    _startContinuousScan();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _faceDetector.close();
    _cameraController.dispose();
    super.dispose();
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  Color get _borderColor {
    switch (_state) {
      case VerificationState.matched:
        return Colors.green;
      case VerificationState.notMatched:
        return Colors.red;
      case VerificationState.faceDetected:
        return Colors.yellow;
      default:
        return Colors.white54;
    }
  }

  String get _statusLabel {
    switch (_state) {
      case VerificationState.scanning:
        return 'Looking for face...';
      case VerificationState.faceDetected:
        return 'Hold still... ($_stableFrameCount/$_framesNeeded)';
      case VerificationState.comparing:
        return 'Comparing with CIN photo...';
      case VerificationState.matched:
        return '✅ IDENTITY CONFIRMED — Redirecting...';
      case VerificationState.notMatched:
        return '❌ FACE NOT MATCHED';
    }
  }

  Color get _statusColor {
    switch (_state) {
      case VerificationState.matched:
        return Colors.green.shade700;
      case VerificationState.notMatched:
        return Colors.red.shade700;
      case VerificationState.faceDetected:
        return Colors.orange.shade700;
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Face Verification',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview — rotate to fix landscape orientation on web/desktop
              kIsWeb
                  ? Transform.rotate(
                      angle: -1.5708, // -90 degrees
                      child: CameraPreview(_cameraController),
                    )
                  : CameraPreview(_cameraController),

              // Face bounding box overlay
              if (_detectedFaces.isNotEmpty)
                CustomPaint(
                  painter: _FaceBoxPainter(
                    faces: _detectedFaces,
                    previewSize: _cameraController.value.previewSize!,
                    screenSize: MediaQuery.of(context).size,
                    color: _borderColor,
                  ),
                ),

              // Status banner at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_state == VerificationState.comparing)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: CircularProgressIndicator(
                              color: Colors.white),
                        ),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _state == VerificationState.scanning ||
                                  _state == VerificationState.comparing
                              ? Colors.white
                              : _statusColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black)
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_matchScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Match score: ${(_matchScore! * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      if (_state == VerificationState.notMatched)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Retrying in 3 seconds...',
                            style: TextStyle(
                                color: Colors.orange.shade300, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Progress bar at top for stable frames
              if (_state == VerificationState.faceDetected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _stableFrameCount / _framesNeeded,
                    backgroundColor: Colors.white24,
                    color: Colors.yellow,
                    minHeight: 6,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// Placeholder — kept for backward compatibility
class VerificationSuccessScreen extends StatelessWidget {
  const VerificationSuccessScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

/// Draws face bounding boxes on camera preview — like OpenCV's rectangle
class _FaceBoxPainter extends CustomPainter {
  final List<Face> faces;
  final Size previewSize;
  final Size screenSize;
  final Color color;

  _FaceBoxPainter({
    required this.faces,
    required this.previewSize,
    required this.screenSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scaleX = screenSize.width / previewSize.height;
    final scaleY = screenSize.height / previewSize.width;

    for (final face in faces) {
      final r = face.boundingBox;
      final rect = Rect.fromLTWH(
        r.left * scaleX,
        r.top * scaleY,
        r.width * scaleX,
        r.height * scaleY,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
    }
  }

  @override
  bool shouldRepaint(_FaceBoxPainter old) => old.faces != faces || old.color != color;
}

