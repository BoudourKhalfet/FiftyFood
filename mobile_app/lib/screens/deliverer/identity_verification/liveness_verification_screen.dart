import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../api/api_service.dart';
import '../../../utils/device_integrity.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

// ─── Telemetry model — sent to server for validation ────────────────────────

class LivenessFrameTelemetry {
  final int timestamp;
  final double headEulerAngleX;
  final double headEulerAngleY;
  final double smilingProbability;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final double faceWidth;
  final double faceHeight;
  final double faceCenterX;
  final double faceCenterY;

  LivenessFrameTelemetry({
    required this.timestamp,
    required this.headEulerAngleX,
    required this.headEulerAngleY,
    required this.smilingProbability,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.faceWidth,
    required this.faceHeight,
    required this.faceCenterX,
    required this.faceCenterY,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'headEulerAngleX': headEulerAngleX,
    'headEulerAngleY': headEulerAngleY,
    'smilingProbability': smilingProbability,
    'leftEyeOpenProbability': leftEyeOpenProbability,
    'rightEyeOpenProbability': rightEyeOpenProbability,
    'faceWidth': faceWidth,
    'faceHeight': faceHeight,
    'faceCenterX': faceCenterX,
    'faceCenterY': faceCenterY,
  };

  factory LivenessFrameTelemetry.fromFace(Face face) {
    final bb = face.boundingBox;
    return LivenessFrameTelemetry(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      headEulerAngleX: face.headEulerAngleX ?? 0,
      headEulerAngleY: face.headEulerAngleY ?? 0,
      smilingProbability: face.smilingProbability ?? 0,
      leftEyeOpenProbability: face.leftEyeOpenProbability ?? 1.0,
      rightEyeOpenProbability: face.rightEyeOpenProbability ?? 1.0,
      faceWidth: bb.width,
      faceHeight: bb.height,
      faceCenterX: bb.center.dx,
      faceCenterY: bb.center.dy,
    );
  }
}

/// Atomic capture packet: frame + its telemetry, guaranteed synchronized.
class CapturePacket {
  final String frameBase64;
  final LivenessFrameTelemetry telemetry;
  CapturePacket({required this.frameBase64, required this.telemetry});
}

// ─── Challenge types ────────────────────────────────────────────────────────

enum LivenessChallenge { blink, turnLeft, turnRight }

extension LivenessChallengeExt on LivenessChallenge {
  String get apiKey {
    switch (this) {
      case LivenessChallenge.blink: return 'blink';
      case LivenessChallenge.turnLeft: return 'turn_left';
      case LivenessChallenge.turnRight: return 'turn_right';
    }
  }

  String get userInstruction {
    switch (this) {
      case LivenessChallenge.blink: return 'Blink your eyes';
      case LivenessChallenge.turnLeft: return 'Turn your head left';
      case LivenessChallenge.turnRight: return 'Turn your head right';
    }
  }

  IconData get icon {
    switch (this) {
      case LivenessChallenge.blink: return Icons.visibility;
      case LivenessChallenge.turnLeft: return Icons.arrow_back;
      case LivenessChallenge.turnRight: return Icons.arrow_forward;
    }
  }

  /// Check if this challenge is satisfied by the given telemetry snapshot.
  /// For blink, requires a full closed→open cycle tracked via [blinkState].
  /// Pass a map that persists across frames to track blink state.
  bool isDetectedIn(LivenessFrameTelemetry t, {Map<String, bool>? blinkState}) {
    switch (this) {
      case LivenessChallenge.blink:
        final avgEye = (t.leftEyeOpenProbability + t.rightEyeOpenProbability) / 2;
        final wasClosed = blinkState?['wasClosed'] ?? false;
        print('[BlinkDetect] avgEye=${avgEye.toStringAsFixed(3)} wasClosed=$wasClosed');
        if (avgEye < 0.4) {
          blinkState?['wasClosed'] = true;
          print('[BlinkDetect] → eyes CLOSED, waiting for reopen');
          return false;
        }
        if (wasClosed && avgEye > 0.6) {
          print('[BlinkDetect] → BLINK COMPLETE');
          return true;
        }
        return false;
      case LivenessChallenge.turnLeft:
        return t.headEulerAngleY > 12;
      case LivenessChallenge.turnRight:
        return t.headEulerAngleY < -12;
    }
  }
}

// ─── 2-step challenge sequence ──────────────────────────────────────────────

class LivenessChallengeSequence {
  final List<LivenessChallenge> steps;
  LivenessChallengeSequence(this.steps);

  List<String> get apiKeys => steps.map((s) => s.apiKey).toList();

  /// Generate a random 2-step sequence with no duplicate consecutive actions.
  factory LivenessChallengeSequence.random() {
    final rng = Random();
    final all = LivenessChallenge.values;
    final first = all[rng.nextInt(all.length)];
    // Pick second that is different from first
    final remaining = all.where((c) => c != first).toList();
    final second = remaining[rng.nextInt(remaining.length)];
    return LivenessChallengeSequence([first, second]);
  }
}

// ─── Verification states ────────────────────────────────────────────────────

enum VerificationState { init, challenge, verifying, success, failed }

// ─── Screen ─────────────────────────────────────────────────────────────────

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
  CameraController? _cameraController;
  late final Future<void> _initializeControllerFuture = _initCamera();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  // Challenge
  late LivenessChallengeSequence _sequence;
  int _currentStep = 0; // 0 or 1
  VerificationState _state = VerificationState.init;
  List<Face> _detectedFaces = [];

  // Session (server-issued)
  String? _sessionId;
  String? _nonce;

  // Data collection — atomic packets (frame + telemetry synchronized)
  final List<CapturePacket> _packets = [];
  Uint8List? _bestSelfie;

  // Timing
  static const int _maxFrames = 24;
  Timer? _captureTimer;
  final Random _rng = Random();
  bool _processingFrame = false;
  bool _streamActive = false;

  // Per-challenge local detection
  final List<bool> _challengePassed = [false, false];
  bool _showCheckmark = false; // brief checkmark animation between steps
  final Map<String, bool> _blinkState = {}; // tracks closed→open cycle
  int _step2StartPacket = 0; // packet index when step 2 began

  // Last known good face telemetry (used when face lost during blink)
  LivenessFrameTelemetry? _lastGoodTelemetry;

  // Result
  double? _matchScore;
  String? _failReason;

  @override
  void initState() {
    super.initState();
    _sequence = LivenessChallengeSequence.random(); // fallback, overridden by server
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
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
      // Device integrity check (block in release mode)
      if (kReleaseMode && DeviceIntegrity.isCompromised()) {
        final checks = DeviceIntegrity.check();
        print('[Liveness] Device integrity FAILED: $checks');
        setState(() {
          _state = VerificationState.failed;
          _failReason = 'Verification unavailable on this device.';
        });
        return;
      }
      await _requestSession();
    }
  }

  /// Request a liveness session from the server (provides challenges + nonce).
  Future<void> _requestSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw 'Not logged in.';

      final response = await ApiService.post(
        'livreur/verify/liveness/session',
        {},
        headers: {'Authorization': 'Bearer $jwt'},
      );

      _sessionId = response['sessionId'] as String?;
      _nonce = response['nonce'] as String?;
      final challenges = (response['challenges'] as List<dynamic>?)?.cast<String>() ?? [];

      if (_sessionId == null || _nonce == null || challenges.isEmpty) {
        throw 'Invalid session response';
      }

      // Use server-provided challenges
      _sequence = LivenessChallengeSequence(
        challenges.map((key) => LivenessChallenge.values.firstWhere(
          (c) => c.apiKey == key,
          orElse: () => LivenessChallenge.blink,
        )).toList(),
      );

      print('[Liveness] Session obtained: $_sessionId challenges=${_sequence.apiKeys}');
      _startChallenge();
    } catch (e) {
      print('[Liveness] Session request failed: $e');
      if (mounted) {
        setState(() {
          _state = VerificationState.failed;
          _failReason = 'Could not start verification. Please try again.';
        });
      }
    }
  }

  // ─── Challenge flow (data collection only — NO validation) ────────────────

  void _startChallenge() {
    _packets.clear();
    _bestSelfie = null;
    _failReason = null;
    _matchScore = null;
    _currentStep = 0;
    _challengePassed[0] = false;
    _challengePassed[1] = false;
    _showCheckmark = false;
    _blinkState.clear();
    _lastGoodTelemetry = null;

    setState(() => _state = VerificationState.challenge);
    print('[Liveness] Sequence started: ${_sequence.apiKeys}');

    // Start continuous image stream — frames processed at randomized intervals
    _startStream();
  }

  void _startStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_streamActive) return;
    _streamActive = true;
    _scheduleNextCapture();
  }

  void _stopStream() {
    _captureTimer?.cancel();
    _streamActive = false;
  }

  void _scheduleNextCapture() {
    if (_state != VerificationState.challenge || !_streamActive) return;
    final delay = 200 + _rng.nextInt(200); // 200-400ms — fast enough to catch blinks
    _captureTimer = Timer(Duration(milliseconds: delay), () {
      _captureFrame();
      _scheduleNextCapture();
    });
  }

  Future<void> _captureFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _state != VerificationState.challenge ||
        _packets.length >= _maxFrames ||
        _processingFrame) return;

    _processingFrame = true;
    try {
      // Take picture and run ML Kit face detection in one atomic operation
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();
      final frameB64 = base64Encode(bytes);
      _bestSelfie = bytes;

      LivenessFrameTelemetry telemetry;

      if (!kIsWeb) {
        final inputImage = InputImage.fromFilePath(xfile.path);
        final faces = await _faceDetector.processImage(inputImage);
        if (mounted && faces.isNotEmpty) {
          setState(() => _detectedFaces = faces);
          telemetry = LivenessFrameTelemetry.fromFace(faces.first);
          _lastGoodTelemetry = telemetry; // remember last face position
        } else {
          if (mounted) setState(() => _detectedFaces = []);
          if (_lastGoodTelemetry != null) {
            // Face lost (likely during blink) — reuse last position with eyes closed
            telemetry = LivenessFrameTelemetry(
              timestamp: DateTime.now().millisecondsSinceEpoch,
              headEulerAngleX: _lastGoodTelemetry!.headEulerAngleX,
              headEulerAngleY: _lastGoodTelemetry!.headEulerAngleY,
              smilingProbability: 0,
              leftEyeOpenProbability: 0,
              rightEyeOpenProbability: 0,
              faceWidth: _lastGoodTelemetry!.faceWidth,
              faceHeight: _lastGoodTelemetry!.faceHeight,
              faceCenterX: _lastGoodTelemetry!.faceCenterX,
              faceCenterY: _lastGoodTelemetry!.faceCenterY,
            );
          } else {
            return; // no face ever detected yet, skip
          }
        }
      } else {
        telemetry = LivenessFrameTelemetry(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          headEulerAngleX: 0, headEulerAngleY: 0,
          smilingProbability: 0,
          leftEyeOpenProbability: 0, rightEyeOpenProbability: 0,
          faceWidth: 0, faceHeight: 0, faceCenterX: 0, faceCenterY: 0,
        );
      }

      // Create atomic packet — frame and telemetry always paired
      _packets.add(CapturePacket(frameBase64: frameB64, telemetry: telemetry));

      print('[Liveness] Packet ${_packets.length}/$_maxFrames | '
          'step=${_currentStep + 1}/2 | '
          'angleY=${telemetry.headEulerAngleY.toStringAsFixed(1)} '
          'leftEye=${telemetry.leftEyeOpenProbability.toStringAsFixed(2)} '
          'rightEye=${telemetry.rightEyeOpenProbability.toStringAsFixed(2)}');

      // Always track blink state (even before canCheckStep2 is true)
      // so closed-eye frames during early step 2 aren't lost
      if (_currentStep == 1 && !_challengePassed[1] &&
          _activeChallenge == LivenessChallenge.blink) {
        final avgEye = (telemetry.leftEyeOpenProbability + telemetry.rightEyeOpenProbability) / 2;
        if (avgEye < 0.4) _blinkState['wasClosed'] = true;
      }

      // Real-time challenge detection — advance when the user completes the action
      // For step 2: wait at least 3 frames after step advanced so server can detect it
      final canCheckStep2 = _currentStep == 0 ||
          (_packets.length - _step2StartPacket) >= 3;

      if (!_challengePassed[_currentStep] && canCheckStep2 &&
          _activeChallenge.isDetectedIn(telemetry, blinkState: _blinkState)) {
        _challengePassed[_currentStep] = true;
        print('[Liveness] ✓ Challenge ${_currentStep + 1} passed locally: ${_activeChallenge.apiKey}');

        // Release frame lock so captures continue during checkmark animation
        // This ensures the server gets the full action (e.g. blink reopen)
        _processingFrame = false;

        if (_currentStep == 0) {
          // Show checkmark briefly, then advance to step 2
          setState(() => _showCheckmark = true);
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted || _state != VerificationState.challenge) return;
          setState(() {
            _showCheckmark = false;
            _currentStep = 1;
          });
          _step2StartPacket = _packets.length;
          _blinkState.clear(); // reset blink tracking for step 2
          print('[Liveness] → Step 2: ${_sequence.steps[1].apiKey}');
        } else {
          // Show checkmark for step 2, keep capturing then submit
          setState(() => _showCheckmark = true);
          print('[Liveness] ✓ All challenges passed locally, capturing final frames...');
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted && _state == VerificationState.challenge) _submit();
          return;
        }
      }

      // Safety: auto-submit if max frames reached even without local detection
      if (_packets.length >= _maxFrames) {
        _submit();
      }
    } catch (e) {
      print('[Liveness] Capture error: $e');
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _submit() async {
    _stopStream();
    setState(() => _state = VerificationState.verifying);
    print('[Liveness] Submitting ${_packets.length} atomic packets to server...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) throw 'Not logged in.';

      final selfieB64 = _bestSelfie != null
          ? 'data:image/jpeg;base64,${base64Encode(_bestSelfie!)}'
          : '';
      final cinB64 = widget.cinFrontImage != null
          ? 'data:image/jpeg;base64,${base64Encode(widget.cinFrontImage!)}'
          : '';

      // Extract parallel lists from atomic packets — guaranteed same order
      final frames = _packets.map((p) => p.frameBase64).toList();
      final telemetry = _packets.map((p) => p.telemetry.toJson()).toList();

      final response = await ApiService.post(
        'livreur/verify/liveness',
        {
          'sessionId': _sessionId,
          'nonce': _nonce,
          'frames': frames,
          'challenges': _sequence.apiKeys,
          'telemetry': telemetry,
          'selfieImageBase64': selfieB64,
          'cinFrontImageBase64': cinB64,
        },
        headers: {'Authorization': 'Bearer $jwt'},
      );

      final success = response['success'] == true;
      final isLive = response['isLive'] == true;
      final score = (response['matchScore'] ?? 0.0).toDouble();
      final reason = response['reason'] ?? '';
      final risk = response['riskLevel'] ?? '';

      print('[Liveness] Server: success=$success isLive=$isLive score=$score risk=$risk reason=$reason');

      if (success) {
        setState(() {
          _state = VerificationState.success;
          _matchScore = score;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() {
          _state = VerificationState.failed;
          _matchScore = score;
          _failReason = !isLive
              ? 'Verification failed. Please try again.'
              : 'Face does not match. Please try again.';
        });
      }
    } catch (e) {
      print('[Liveness] Error: $e');
      setState(() {
        _state = VerificationState.failed;
        _failReason = 'Verification error. Please try again.';
      });
    }
  }

  void _retry() {
    _stopStream();
    setState(() {
      _state = VerificationState.init;
      _detectedFaces = [];
      _packets.clear();
      _bestSelfie = null;
      _matchScore = null;
      _failReason = null;
      _currentStep = 0;
      _challengePassed[0] = false;
      _challengePassed[1] = false;
      _showCheckmark = false;
      _blinkState.clear();
      _sessionId = null;
      _nonce = null;
    });
    print('[Liveness] Retry → requesting new session');
    _requestSession();
  }

  @override
  void dispose() {
    _stopStream();
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  LivenessChallenge get _activeChallenge => _sequence.steps[_currentStep];

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
              // Camera preview
              kIsWeb
                  ? Transform.rotate(
                      angle: -1.5708,
                      child: CameraPreview(_cameraController!),
                    )
                  : CameraPreview(_cameraController!),

              // Face bounding box
              if (_detectedFaces.isNotEmpty && _cameraController != null)
                CustomPaint(
                  painter: _FaceBoxPainter(
                    faces: _detectedFaces,
                    previewSize: _cameraController!.value.previewSize!,
                    screenSize: MediaQuery.of(context).size,
                    color: _borderColor,
                  ),
                ),


              // Step indicator moved to bottom challenge panel

              // Frame capture progress (top)
              if (_state == VerificationState.challenge)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _packets.length / _maxFrames,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFF3D9176),
                    minHeight: 5,
                  ),
                ),

              // Bottom panel
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomPanel(),
              ),
            ],
          );
        },
      ),
    );
  }

  Color get _borderColor {
    switch (_state) {
      case VerificationState.success: return Colors.green;
      case VerificationState.failed: return Colors.red;
      case VerificationState.challenge: return Colors.yellow;
      default: return Colors.white54;
    }
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: _buildStateContent(),
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_state) {
      case VerificationState.init:
        return const SizedBox.shrink();
      case VerificationState.challenge:
        return _buildChallengeState();
      case VerificationState.verifying:
        return _buildVerifyingState();
      case VerificationState.success:
        return _buildSuccessState();
      case VerificationState.failed:
        return _buildFailedState();
    }
  }

  Widget _buildChallengeState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final done = _challengePassed[i];
            final active = i == _currentStep && !_showCheckmark;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: active ? 12 : 10,
              height: active ? 12 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? Colors.green
                    : active
                        ? Colors.white
                        : Colors.white30,
                border: active
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check, size: 8, color: Colors.white)
                  : null,
            );
          }),
        ),
        const SizedBox(height: 16),

        // Checkmark transition or instruction chip
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showCheckmark
              ? const Icon(
                  Icons.check_circle,
                  key: ValueKey('check'),
                  size: 48,
                  color: Colors.green,
                )
              : Container(
                  key: ValueKey(_currentStep),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeChallenge.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _activeChallenge.userInstruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVerifyingState() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 16),
        Text(
          'Verifying your identity...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 56, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          'Identity Confirmed',
          style: TextStyle(
            color: Colors.green,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Redirecting...',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 10),
        const Text(
          'Verification Failed',
          style: TextStyle(
            color: Colors.red,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_failReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _failReason!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Go Back',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D9176),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Try Again',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Backward compat placeholder
class VerificationSuccessScreen extends StatelessWidget {
  const VerificationSuccessScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

/// Draws face bounding boxes on camera preview
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
  bool shouldRepaint(_FaceBoxPainter old) =>
      old.faces != faces || old.color != color;
}
