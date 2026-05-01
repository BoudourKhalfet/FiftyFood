import os
import base64
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import tempfile

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


def compare_faces_deepface(cin_b64, selfie_b64):
    """Use DeepFace (no dlib needed) to compare faces."""
    cin_path = decode_base64_to_file(cin_b64)
    selfie_path = decode_base64_to_file(selfie_b64)

    try:
        result = DeepFace.verify(
            img1_path=cin_path,
            img2_path=selfie_path,
            model_name="Facenet",      # Fast and accurate, no dlib
            detector_backend="opencv", # Pure OpenCV, no dlib
            enforce_detection=False,   # Don't fail if face not detected
        )

        distance = float(result.get("distance", 1.0))
        threshold = float(result.get("threshold", 0.4))
        is_match = bool(result.get("verified", False))
        match_score = max(0.0, 1.0 - (distance / (threshold * 2)))

        print(f"[FaceService] DeepFace - Distance: {distance:.3f}, Threshold: {threshold:.3f}, Match: {is_match}")

        return {
            "isMatch": is_match,
            "matchScore": round(match_score, 3),
            "distance": round(distance, 3),
        }
    finally:
        os.unlink(cin_path)
        os.unlink(selfie_path)


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
    return jsonify({"status": "ok", "service": "face-recognition"})


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

    result = compare_faces(cin_b64, selfie_b64)

    if 'error' in result:
        return jsonify(result), 422

    return jsonify(result)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    print(f"[FaceService] Starting on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
