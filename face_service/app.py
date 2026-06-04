import os
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'  # Disable MKL/oneDNN to prevent Conv2D crashes
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'   # Suppress TF C++ logs
import sys
import base64
import time
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import tempfile

# Fix Windows cp1252 encoding issues
if sys.stdout.encoding != 'utf-8':
    sys.stdout = open(sys.stdout.fileno(), mode='w', encoding='utf-8', errors='replace', buffering=1)
    sys.stderr = open(sys.stderr.fileno(), mode='w', encoding='utf-8', errors='replace', buffering=1)

app = Flask(__name__)
CORS(app)

# Try to import deepface (no cmake/dlib needed)
try:
    from deepface import DeepFace
    DEEPFACE_AVAILABLE = True
    print("[FaceService] DeepFace loaded successfully")
except ImportError:
    DEEPFACE_AVAILABLE = False
    print("[FaceService] WARNING: DeepFace not available, using OpenCV fallback")


def decode_base64_to_file(b64_string, suffix=".jpg"):
    """Decode base64 image to a temp file and return the path."""
    if ',' in b64_string:
        b64_string = b64_string.split(',')[1]
    img_bytes = base64.b64decode(b64_string)
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    tmp.write(img_bytes)
    tmp.close()
    return tmp.name


def decode_base64_image(b64_string):
    """Decode base64 string to numpy image array (BGR)."""
    if ',' in b64_string:
        b64_string = b64_string.split(',')[1]
    img_bytes = base64.b64decode(b64_string)
    np_arr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    return img


def encode_image_to_base64(img):
    """Encode numpy image array (BGR) to base64 JPEG string."""
    ok, buf = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 92])
    if not ok:
        return None
    return base64.b64encode(buf.tobytes()).decode('utf-8')


def check_image_quality(img):
    """Returns (is_ok, reason)"""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    brightness = gray.mean()
    if brightness < 30:
        return False, "Image is too dark. Please ensure good lighting."
    if brightness > 240:
        return False, "Image is overexposed. Please avoid direct light."

    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    if blur_score < 20:
        return False, "Image is too blurry. Please hold the camera steady."

    return True, "ok"


def crop_face_region(img):
    """Detect and crop the largest face region; return cropped image or None."""
    try:
        face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        )
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 4)
        if len(faces) == 0:
            return None

        # Pick the largest face
        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
        pad = int(max(w, h) * 0.15)
        x0 = max(x - pad, 0)
        y0 = max(y - pad, 0)
        x1 = min(x + w + pad, img.shape[1])
        y1 = min(y + h + pad, img.shape[0])
        cropped = img[y0:y1, x0:x1]
        if cropped.size == 0:
            return None

        # Upscale to help matching on small ID photos
        resized = cv2.resize(cropped, (256, 256), interpolation=cv2.INTER_CUBIC)
        return resized
    except Exception as e:
        print(f"[Compare] Face crop failed: {e}")
        return None


def estimate_face_tilt(img):
    """Estimate face tilt angle (degrees) using eye detection; returns None if unknown."""
    try:
        eye_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_eye.xml'
        )
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        eyes = eye_cascade.detectMultiScale(gray, 1.1, 5)
        if len(eyes) < 2:
            return None

        # Pick two eyes with largest widths
        eyes = sorted(eyes, key=lambda e: e[2], reverse=True)[:2]
        (x1, y1, w1, h1), (x2, y2, w2, h2) = eyes
        c1 = (x1 + w1 / 2.0, y1 + h1 / 2.0)
        c2 = (x2 + w2 / 2.0, y2 + h2 / 2.0)
        dx = c2[0] - c1[0]
        dy = c2[1] - c1[1]
        if dx == 0:
            return 90.0
        angle = float(np.degrees(np.arctan2(dy, dx)))
        return angle
    except Exception as e:
        print(f"[Compare] Eye tilt estimation failed: {e}")
        return None



def preprocess_for_comparison(b64_string):
    """
    Normalize brightness of image using CLAHE before comparison.
    DeepFace handles face alignment internally (align=True).
    Returns temp file path.
    """
    img = decode_base64_image(b64_string)
    if img is None:
        return decode_base64_to_file(b64_string)

    try:
        # Light denoise + unsharp mask to improve ID photo clarity
        denoised = cv2.fastNlMeansDenoisingColored(img, None, 5, 5, 7, 21)
        blurred = cv2.GaussianBlur(denoised, (0, 0), 1.2)
        sharpened = cv2.addWeighted(denoised, 1.4, blurred, -0.4, 0)

        # Apply CLAHE brightness normalization to reduce CIN-vs-selfie lighting gap
        lab = cv2.cvtColor(sharpened, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(4, 4))
        l = clahe.apply(l)
        normalized = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)

        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        cv2.imwrite(tmp.name, normalized)
        tmp.close()
        print("[Preprocess] CLAHE brightness normalization applied")
        return tmp.name
    except Exception as e:
        print(f"[Preprocess] Normalization failed, using original: {e}")
        return decode_base64_to_file(b64_string)


def compare_faces_deepface(cin_b64, selfie_b64):
    """Use DeepFace with retinaface detector, face alignment, and retry logic."""
    # Preprocess and align both faces before comparison
    cin_path = preprocess_for_comparison(cin_b64)
    selfie_path = preprocess_for_comparison(selfie_b64)

    last_error = None
    for attempt in range(2):  # try twice
        try:
            result = DeepFace.verify(
                img1_path=cin_path,
                img2_path=selfie_path,
                model_name="Facenet512",
                detector_backend="retinaface",
                enforce_detection=False,
                align=True,
            )
            distance = float(result.get("distance", 1.0))
            # Facenet512 default threshold is ~0.30 (cosine)
            # We use 0.40 for CIN-to-selfie quality gap
            threshold = 0.40
            is_match = distance <= threshold
            # Score: 1.0 = perfect match, 0.5 = at threshold boundary, 0.0 = very different
            match_score = max(0.0, 1.0 - (distance / (threshold * 2)))

            print(f"[FaceService] DeepFace - Distance: {distance:.3f}, Threshold: {threshold:.3f}, Match: {is_match}")

            return {
                "isMatch": is_match,
                "matchScore": round(match_score, 3),
                "distance": round(distance, 3),
            }
        except Exception as e:
            last_error = e
            if attempt == 0:
                time.sleep(1)
            continue
        finally:
            if attempt == 1 or last_error is None:
                try:
                    os.unlink(cin_path)
                    os.unlink(selfie_path)
                except:
                    pass

    # both attempts failed, fall back to opencv
    print(f"[FaceService] DeepFace failed after 2 attempts, falling back to OpenCV")
    return compare_faces_opencv(cin_b64, selfie_b64)


def compare_faces_opencv(cin_b64, selfie_b64):
    """Fallback: OpenCV face detection with histogram comparison."""
    cin_img = decode_base64_image(cin_b64)
    selfie_img = decode_base64_image(selfie_b64)

    if cin_img is None or selfie_img is None:
        return {"isMatch": False, "matchScore": 0.0, "error": "Failed to decode images"}

    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

    cin_gray = cv2.cvtColor(cin_img, cv2.COLOR_BGR2GRAY)
    selfie_gray = cv2.cvtColor(selfie_img, cv2.COLOR_BGR2GRAY)

    cin_faces = face_cascade.detectMultiScale(cin_gray, 1.1, 4)
    selfie_faces = face_cascade.detectMultiScale(selfie_gray, 1.1, 4)

    if len(cin_faces) == 0 or len(selfie_faces) == 0:
        return {"isMatch": False, "matchScore": 0.0, "error": "No face detected in one or both images"}

    # Crop face regions
    x, y, w, h = cin_faces[0]
    cin_face = cv2.resize(cin_img[y:y+h, x:x+w], (128, 128))

    x, y, w, h = selfie_faces[0]
    selfie_face = cv2.resize(selfie_img[y:y+h, x:x+w], (128, 128))

    # Compare using histogram correlation
    score = 0.0
    for i in range(3):
        hist1 = cv2.calcHist([cin_face], [i], None, [64], [0, 256])
        hist2 = cv2.calcHist([selfie_face], [i], None, [64], [0, 256])
        cv2.normalize(hist1, hist1)
        cv2.normalize(hist2, hist2)
        score += cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL)
    match_score = max(0.0, score / 3.0)
    is_match = match_score > 0.6

    print(f"[FaceService] OpenCV fallback - Score: {match_score:.3f}, Match: {is_match}")

    return {
        "isMatch": is_match,
        "matchScore": round(match_score, 3),
        "distance": round(1.0 - match_score, 3),
    }


def compare_faces(cin_b64, selfie_b64):
    if DEEPFACE_AVAILABLE:
        return compare_faces_deepface(cin_b64, selfie_b64)
    return compare_faces_opencv(cin_b64, selfie_b64)


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "ok",
        "service": "face-recognition",
        "deepface": DEEPFACE_AVAILABLE,
        "detector": "retinaface" if DEEPFACE_AVAILABLE else "opencv-haar",
        "model": "Facenet512" if DEEPFACE_AVAILABLE else "histogram"
    })


@app.route('/liveness', methods=['POST'])
def liveness():
    """
    POST /liveness — Server-side liveness verification.
    Body: {
        frames: [base64, ...],                   # captured frames
        challenges: ["blink", "turn_left"],       # 2-step challenge sequence
        telemetry: [{timestamp, headEulerAngleX, headEulerAngleY,
                     smilingProbability, leftEyeOpenProbability,
                     rightEyeOpenProbability, faceWidth, faceHeight,
                     faceCenterX, faceCenterY}, ...]
    }
    Returns detailed diagnostics with per-check results.
    """
    from liveness_validators import (
        validate_challenge_sequence, validate_timing_patterns,
        validate_telemetry_integrity,
        cross_verify_telemetry_frames,
        analyze_face_depth_consistency, analyze_motion_irregularity,
        analyze_optical_flow, analyze_texture, analyze_frame_diffs,
        check_face_presence, validate_face_embedding_consistency,
        compute_liveness_confidence,
        FailureReport,
    )

    data = request.get_json()
    if not data:
        return jsonify({"error": "No JSON body"}), 400

    frames_b64 = data.get("frames", [])
    challenges = data.get("challenges", [])
    telemetry = data.get("telemetry", [])

    # Backward compat: single challenge string → list
    if not challenges and data.get("challenge"):
        challenges = [data["challenge"]]

    if len(frames_b64) < 2:
        return jsonify({"isLive": False, "confidence": 0.0, "reason": "Not enough frames",
                        "riskLevel": "HIGH", "checks": {}, "failureReport": {}}), 200

    if not telemetry:
        return jsonify({"isLive": False, "confidence": 0.0, "reason": "No telemetry data",
                        "riskLevel": "HIGH", "checks": {}, "failureReport": {}}), 200

    # --- Decode frames ---
    gray_frames = []
    for b64 in frames_b64:
        img = decode_base64_image(b64)
        if img is not None:
            gray_frames.append(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY))

    if len(gray_frames) < 2:
        return jsonify({"isLive": False, "confidence": 0.0, "reason": "Could not decode frames",
                        "riskLevel": "HIGH", "checks": {}, "failureReport": {}}), 200

    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    report = FailureReport()

    # ── 1. Telemetry integrity (reject fabricated data) ──
    telemetry_valid, telemetry_reason = validate_telemetry_integrity(telemetry)
    # ── 2. Challenge validation (event-based ordered detection) ──
    challenge_passed, challenge_results, challenge_reason = validate_challenge_sequence(
        challenges, telemetry
    )

    # ── 4. Timing security ──
    timing_passed, timing_reason = validate_timing_patterns(telemetry)

    # ── 4b. Frame count vs duration consistency ──
    from liveness_validators import validate_frame_count_vs_duration
    frame_duration_ok, frame_duration_reason = validate_frame_count_vs_duration(telemetry, len(gray_frames))
    if not frame_duration_ok:
        timing_passed = False  # treat as timing failure

    # ── 5. Face presence ──
    face_ratio, face_reason = check_face_presence(gray_frames, face_cascade)

    # ── 6. Frame diff analysis (frozen/duplicate/moiré/compression) ──
    frame_diff_score, frame_checks, frame_reason = analyze_frame_diffs(gray_frames)

    # ── 7. Texture analysis ──
    texture_score, texture_reason = analyze_texture(gray_frames, face_cascade)

    # ── 8. Face depth/size consistency ──
    depth_score, depth_reason = analyze_face_depth_consistency(telemetry)

    # ── 9. Motion irregularity (with entropy scoring) ──
    motion_score, motion_reason = analyze_motion_irregularity(telemetry)

    # ── 10. Optical flow ──
    flow_score, flow_reason = analyze_optical_flow(gray_frames)

    # ── 11. Cross-verify telemetry vs frames ──
    cross_verify_score, cross_reason = cross_verify_telemetry_frames(telemetry, gray_frames, face_cascade)

    # ── 12. Face embedding consistency (detects photo attacks) ──
    face_consistency_score, face_consistency_reason = validate_face_embedding_consistency(gray_frames, face_cascade)

    # ── Composite scoring (unified normalized pipeline) ──
    confidence, risk_level, final_reason = compute_liveness_confidence(
        challenge_passed=challenge_passed,
        timing_passed=timing_passed,
        telemetry_valid=telemetry_valid,
        face_ratio=face_ratio,
        frame_diff_score=frame_diff_score,
        texture_score=texture_score,
        depth_score=depth_score,
        motion_score=motion_score,
        flow_score=flow_score,
        cross_verify_score=cross_verify_score,
        face_consistency_score=face_consistency_score,
        report=report,
    )

    is_live = (confidence >= 0.55 and challenge_passed and timing_passed
               and telemetry_valid and face_ratio >= 0.5)

    failed = report.failed_modules()
    print(f"[Liveness] isLive={is_live} confidence={confidence:.2f} risk={risk_level} challenge={challenge_passed} face={face_ratio:.2f}" + (f" failed={failed}" if failed else ""))

    return jsonify({
        "isLive": is_live,
        "confidence": confidence,
        "riskLevel": risk_level,
        "reason": final_reason,
        "checks": {
            "telemetryValid": telemetry_valid,
            "telemetryReason": telemetry_reason,
            "challenge": challenge_passed,
            "challengeDetails": challenge_results,
            "timing": timing_passed,
            "timingReason": timing_reason,
            "facePresence": round(face_ratio, 2),
            "frameDiff": frame_diff_score,
            "texture": texture_score,
            "depth": depth_score,
            "motion": motion_score,
            "opticalFlow": flow_score,
            "crossVerify": cross_verify_score,
            "faceConsistency": face_consistency_score,
            "faceConsistencyReason": face_consistency_reason,
            "replayRisk": frame_checks.get("static_frames", False) or frame_checks.get("uniform_diffs", False),
            "duplicateFrames": frame_checks.get("duplicate_frames", 0),
            "frozenSequences": frame_checks.get("frozen_sequences", 0),
            "moireDetected": frame_checks.get("moire_detected", False),
        },
        "failureReport": report.to_dict(),
    }), 200


@app.route('/compare', methods=['POST'])
def compare():
    """
    POST /compare
    Body: { cinImageBase64: string, selfieImageBase64: string }
    Returns: { isMatch: bool, matchScore: float, distance: float }
    """
    data = request.get_json()

    if not data:
        return jsonify({"error": "No JSON body provided"}), 400

    cin_b64 = data.get('cinImageBase64')
    selfie_b64 = data.get('selfieImageBase64')

    if not cin_b64 or not selfie_b64:
        return jsonify({"error": "Both cinImageBase64 and selfieImageBase64 are required"}), 400

    # Decode images
    cin_img = decode_base64_image(cin_b64)
    selfie_img = decode_base64_image(selfie_b64)

    # Selfie quality check (single pass)
    selfie_ok, selfie_reason = check_image_quality(selfie_img)
    if not selfie_ok:
        return jsonify({"error": f"Selfie quality issue: {selfie_reason}"}), 422

    # Try CIN rotations to handle sideways ID photos
    angles = [0, 90, 180, 270]
    valid_variants = []
    first_fail_reason = None
    tilt_rejects = 0
    for angle in angles:
        rotated = cin_img if angle == 0 else rotate_image(cin_img, angle)
        cin_ok, cin_reason = check_image_quality(rotated)
        if not cin_ok:
            if first_fail_reason is None:
                first_fail_reason = cin_reason
            continue
        face_crop = crop_face_region(rotated)
        if face_crop is not None:
            tilt = estimate_face_tilt(face_crop)
            if tilt is not None and abs(tilt) > 20:
                tilt_rejects += 1
                print(
                    f"[Compare] CIN rotation {angle}deg rejected (tilt={tilt:.1f}deg)"
                )
                continue
            cin_b64_variant = encode_image_to_base64(face_crop)
            if cin_b64_variant:
                valid_variants.append((angle, cin_b64_variant, True))
                continue

        cin_b64_variant = encode_image_to_base64(rotated)
        if cin_b64_variant:
            valid_variants.append((angle, cin_b64_variant, False))

    if not valid_variants and tilt_rejects > 0:
        return jsonify({
            "error": "CIN photo is rotated. Please retake the photo with the face upright and centered."
        }), 422

    if not valid_variants:
        reason = first_fail_reason or "CIN photo quality issue"
        return jsonify({"error": f"CIN photo quality issue: {reason}"}), 422

    best_result = None
    best_score = -1.0
    best_angle = 0

    for angle, cin_variant_b64, used_crop in valid_variants:
        result = compare_faces(cin_variant_b64, selfie_b64)
        if 'error' in result:
            print(f"[Compare] CIN rotation {angle}deg failed: {result.get('error')}")
            continue

        score = float(result.get("matchScore", 0.0))
        crop_note = "cropped" if used_crop else "full"
        print(
            f"[Compare] CIN rotation {angle}deg {crop_note} matchScore={score:.3f} "
            f"isMatch={result.get('isMatch')}"
        )

        if result.get('isMatch'):
            result['rotation'] = angle
            return jsonify(result)

        if score > best_score:
            best_score = score
            best_result = result
            best_angle = angle

    if best_result is None:
        return jsonify({"error": "No face detected in one or both images"}), 422

    best_result['rotation'] = best_angle
    return jsonify(best_result)

@app.route('/detect', methods=['POST'])
def detect():
    data = request.get_json()
    if not data or 'image' not in data:
        return jsonify({"error": "Missing image field"}), 400

    img_path = None
    try:
        img_path = decode_base64_to_file(data['image'])

        if DEEPFACE_AVAILABLE:
            faces = DeepFace.extract_faces(
                img_path=img_path,
                detector_backend="retinaface",
                enforce_detection=False,
            )
            has_face = len(faces) > 0 and faces[0].get("confidence", 0) > 0.9
            return jsonify({
                "has_face": has_face,
                "face_count": len(faces),
                "confidence": faces[0].get("confidence", 0) if faces else 0,
            })
        else:
            # fallback to opencv haar cascade
            img = decode_base64_image(data['image'])
            face_cascade = cv2.CascadeClassifier(
                cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
            )
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, 1.1, 4)
            return jsonify({
                "has_face": len(faces) > 0,
                "face_count": len(faces),
                "confidence": 0.7 if len(faces) > 0 else 0,
            })
    finally:
        if img_path and os.path.exists(img_path):
            os.unlink(img_path)


@app.route('/extract-barcode', methods=['POST'])
def extract_barcode():
    """
    POST /extract-barcode
    Body: { image: base64_string }
    Returns: { barcode: bool, cin: string|null, isTunisianFormat: bool, rawData: string|null }
    Extracts PDF417 barcode from Tunisian ID card back
    """
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({"error": "No image provided"}), 400
        
        # Decode image
        img = decode_base64_image(data['image'])
        if img is None:
            return jsonify({"error": "Could not decode image"}), 400

        # Attempt to deskew/rotate the image to correct for phone tilt
        try:
            img = deskew_image(img)
        except Exception as e:
            print(f"[FlagDetect] Deskew failed: {e}")
        
        # Save temp image for barcode scanning
        temp_path = None
        try:
            temp_path = tempfile.mktemp(suffix='.jpg')
            cv2.imwrite(temp_path, img)
            
            # Try to import pyzbar for barcode scanning
            try:
                from pyzbar import pyzbar
                from pyzbar.pyzbar import ZBarSymbol
                
                # Read image and decode barcodes
                barcode_img = cv2.imread(temp_path)
                barcodes = pyzbar.decode(barcode_img, symbols=[ZBarSymbol.PDF417])
                
                if not barcodes:
                    # Try without symbol restriction
                    barcodes = pyzbar.decode(barcode_img)
                
                if barcodes:
                    for barcode in barcodes:
                        barcode_data = barcode.data.decode('utf-8', errors='replace')
                        print(f"[Barcode] Type={barcode.type} RawData={repr(barcode_data)}")

                        # Validate Tunisian CIN barcode:
                        # - Must be exactly 18 digits
                        # - First 8 digits must be the CIN number
                        is_tunisian = (
                            len(barcode_data) == 18 and
                            barcode_data.isdigit() and
                            barcode_data[:8].isdigit()
                        )
                        cin = barcode_data[:8] if is_tunisian else None

                        return jsonify({
                            "barcode": True,
                            "cin": cin,
                            "isTunisianFormat": is_tunisian,
                            "rawData": barcode_data,
                            "barcodeType": barcode.type
                        })
                
                # No valid barcode found
                return jsonify({
                    "barcode": False,
                    "cin": None,
                    "isTunisianFormat": False,
                    "rawData": None,
                    "reason": "No PDF417 barcode detected"
                })
                
            except ImportError:
                # pyzbar not available, use fallback
                print("[FaceService] WARNING: pyzbar not available for barcode scanning")
                return jsonify({
                    "barcode": False,
                    "cin": None,
                    "isTunisianFormat": False,
                    "rawData": None,
                    "reason": "Barcode scanner not available"
                })
                
        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        print(f"[FaceService] Barcode extraction error: {e}")
        return jsonify({
            "barcode": False,
            "cin": None,
            "isTunisianFormat": False,
            "rawData": None,
            "error": str(e)
        }), 500


def deskew_image(img):
    """
    Detect and correct skew angle of a document image using Hough line transform.
    Returns the deskewed image.
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # Threshold to get text/edge pixels
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    # Detect lines via HoughLinesP
    edges = cv2.Canny(thresh, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=80,
                             minLineLength=img.shape[1] // 4, maxLineGap=20)
    if lines is None:
        return img  # Can't detect angle, return as-is

    angles = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        if x2 - x1 == 0:
            continue
        angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
        # Only consider near-horizontal lines (card edges)
        if -45 < angle < 45:
            angles.append(angle)

    if not angles:
        return img

    median_angle = float(np.median(angles))
    # Skip rotation if angle is negligible (< 0.5 deg) to avoid unnecessary processing
    if abs(median_angle) < 0.5:
        return img

    h, w = img.shape[:2]
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    deskewed = cv2.warpAffine(img, M, (w, h),
                               flags=cv2.INTER_LINEAR,
                               borderMode=cv2.BORDER_REPLICATE)
    print(f"[Deskew] Corrected angle: {median_angle:.2f}°")
    return deskewed


def rotate_image(img, angle):
    """
    Rotate image by a given angle (degrees) around its center.
    """
    h, w = img.shape[:2]
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, angle, 1.0)
    rotated = cv2.warpAffine(
        img,
        M,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REPLICATE,
    )
    return rotated


@app.route('/deskew', methods=['POST'])
def deskew_endpoint():
    """
    POST /deskew
    Body: { image: base64_string }
    Returns: { image: base64_string }  — deskewed JPEG image
    """
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({"error": "No image provided"}), 400

        img = decode_base64_image(data['image'])
        if img is None:
            return jsonify({"error": "Could not decode image"}), 400

        result = deskew_image(img)
        _, buf = cv2.imencode('.jpg', result, [cv2.IMWRITE_JPEG_QUALITY, 92])
        b64 = base64.b64encode(buf.tobytes()).decode('utf-8')
        return jsonify({"image": b64})

    except Exception as e:
        print(f"[Deskew] Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/rotate', methods=['POST'])
def rotate_endpoint():
    """
    POST /rotate
    Body: { image: base64_string, angle: number }
    Returns: { image: base64_string }  — rotated JPEG image
    """
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({"error": "No image provided"}), 400

        angle = float(data.get('angle', 0))

        img = decode_base64_image(data['image'])
        if img is None:
            return jsonify({"error": "Could not decode image"}), 400

        result = rotate_image(img, angle)
        _, buf = cv2.imencode('.jpg', result, [cv2.IMWRITE_JPEG_QUALITY, 92])
        b64 = base64.b64encode(buf.tobytes()).decode('utf-8')
        return jsonify({"image": b64})

    except Exception as e:
        print(f"[Rotate] Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/detect-tunisian-features', methods=['POST'])
def detect_tunisian_features():
    """
    POST /detect-tunisian-features
    Body: { image: base64_string }
    Returns: { hasTunisianFlag: bool, flagConfidence: float, hasSecurityFeatures: bool }
    Detects Tunisian flag (red with white crescent) and security features
    """
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({"error": "No image provided"}), 400
        
        # Decode image
        img = decode_base64_image(data['image'])
        if img is None:
            return jsonify({"error": "Could not decode image"}), 400

        img_h, img_w = img.shape[:2]

        # Convert full image to HSV for a coarse red search first
        hsv_full = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        v_mean = float(np.mean(hsv_full[:, :, 2]))
        sat_low = 50 if v_mean > 80 else 35
        val_low = 45 if v_mean > 80 else 30

        # Red occupies both ends of the HSV hue spectrum
        lower_red1 = np.array([0, sat_low, val_low])
        upper_red1 = np.array([12, 255, 255])
        lower_red2 = np.array([170, sat_low, val_low])
        upper_red2 = np.array([180, 255, 255])

        mask1_full = cv2.inRange(hsv_full, lower_red1, upper_red1)
        mask2_full = cv2.inRange(hsv_full, lower_red2, upper_red2)
        red_mask_full = mask1_full | mask2_full

        # Clean up mask to reduce noise
        kernel = np.ones((5, 5), np.uint8)
        red_mask_full = cv2.morphologyEx(red_mask_full, cv2.MORPH_OPEN, kernel)
        red_mask_full = cv2.morphologyEx(red_mask_full, cv2.MORPH_CLOSE, kernel)

        # Find candidate red region near the top-left
        contours, _ = cv2.findContours(red_mask_full, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        best_bbox = None
        best_score = -1.0
        img_area = float(img_h * img_w)
        for cnt in contours:
            area = float(cv2.contourArea(cnt))
            if area <= 0:
                continue
            area_ratio = area / img_area
            if area_ratio < 0.002 or area_ratio > 0.08:
                continue
            x, y, w, h = cv2.boundingRect(cnt)
            cx = x + w / 2.0
            cy = y + h / 2.0
            if cx > img_w * 0.7 or cy > img_h * 0.7:
                continue
            aspect = w / h if h > 0 else 0.0
            if aspect < 0.6 or aspect > 1.6:
                continue
            # Score favors bigger regions closer to the top-left
            proximity = 1.0 - ((cx / img_w) * 0.7 + (cy / img_h) * 0.3)
            score = area_ratio * 2.0 + proximity
            if score > best_score:
                best_score = score
                best_bbox = (x, y, w, h)

        if best_bbox is not None:
            x, y, w, h = best_bbox
            pad = int(max(w, h) * 0.25)
            x0 = max(x - pad, 0)
            y0 = max(y - pad, 0)
            x1 = min(x + w + pad, img_w)
            y1 = min(y + h + pad, img_h)
            flag_roi = img[y0:y1, x0:x1]
        else:
            # Fallback: use a generous top-left crop
            flag_roi = img[:int(img_h * 0.65), :int(img_w * 0.50)]

        # Convert ROI to HSV for color analysis
        hsv = cv2.cvtColor(flag_roi, cv2.COLOR_BGR2HSV)

        mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
        mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
        red_mask = mask1 | mask2

        roi_pixels = flag_roi.shape[0] * flag_roi.shape[1]
        red_pixels = int(np.sum(red_mask > 0))
        red_ratio = red_pixels / roi_pixels if roi_pixels > 0 else 0.0

        # White crescent sits inside the red area
        # Loosen white detection to tolerate highlights under indoor lighting
        lower_white = np.array([0, 0, 155])
        upper_white = np.array([180, 110, 255])
        white_mask = cv2.inRange(hsv, lower_white, upper_white)
        white_ratio = float(np.sum(white_mask > 0)) / roi_pixels if roi_pixels > 0 else 0.0
        white_in_red = float(np.sum((white_mask > 0) & (red_mask > 0)))
        white_in_red_ratio = white_in_red / red_pixels if red_pixels > 0 else 0.0

        # Security features — use full image Laplacian variance
        gray_full = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        lap_var = float(cv2.Laplacian(gray_full, cv2.CV_64F).var())
        fft = np.fft.fft2(gray_full)
        magnitude = np.abs(np.fft.fftshift(fft))
        h, w = magnitude.shape
        high_freq_sum = float(
            np.sum(magnitude[:h//4, :]) + np.sum(magnitude[-h//4:, :]) +
            np.sum(magnitude[:, :w//4]) + np.sum(magnitude[:, -w//4:])
        )
        total_mag = float(np.sum(magnitude))
        high_freq_ratio = high_freq_sum / total_mag if total_mag > 0 else 0.0

        # Flag is present when the ROI has enough red AND some white
        # Thresholds are tuned to be tolerant of framing and lighting changes
        has_red_flag = bool(red_ratio > 0.06)
        has_white_crescent = bool(white_in_red_ratio > 0.015 or white_ratio > 0.02)

        flag_confidence = 0.0
        if has_red_flag:
            flag_confidence += 0.6
        if has_white_crescent:
            flag_confidence += 0.3
        if red_ratio > 0.15:
            flag_confidence += 0.1

        has_security_features = bool(lap_var > 200 and high_freq_ratio > 0.15)

        print(
            f"[FlagDetect] red_ratio={red_ratio:.3f} white_ratio={white_ratio:.3f} white_in_red={white_in_red_ratio:.3f} "
            f"flag={has_red_flag and has_white_crescent}"
        )

        return jsonify({
            "hasTunisianFlag": bool(has_red_flag and has_white_crescent),
            "flagConfidence": round(float(flag_confidence), 3),
            "hasSecurityFeatures": has_security_features,
            "details": {
                "redRatio": round(float(red_ratio), 4),
                "whiteRatio": round(float(white_ratio), 4),
                "laplacianVariance": round(float(lap_var), 2),
                "highFreqRatio": round(float(high_freq_ratio), 4)
            }
        })
        
    except Exception as e:
        print(f"[FaceService] Tunisian feature detection error: {e}")
        return jsonify({
            "hasTunisianFlag": False,
            "flagConfidence": 0,
            "hasSecurityFeatures": False,
            "error": str(e)
        }), 500


if __name__ == '__main__':
    import logging
    logging.getLogger('werkzeug').setLevel(logging.ERROR)
    port = int(os.environ.get('PORT', 5001))
    print(f"[FaceService] Starting on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)