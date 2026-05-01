from flask import Flask, request, jsonify
from flask_cors import CORS
import face_recognition
import numpy as np
import base64
from PIL import Image
import io
import logging

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def decode_base64_image(base64_string):
    """Decode base64 image to numpy array"""
    try:
        # Remove data URI prefix if present
        if ',' in base64_string:
            base64_string = base64_string.split(',')[1]
        
        image_bytes = base64.b64decode(base64_string)
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB (face_recognition needs RGB)
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        return np.array(image)
    except Exception as e:
        logger.error(f"Error decoding image: {e}")
        return None

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "ok", "service": "face-recognition"})

@app.route('/compare', methods=['POST'])
def compare_faces():
    """
    Compare two faces and return similarity score
    
    Request body:
    {
        "image1": "base64_encoded_image",
        "image2": "base64_encoded_image"
    }
    
    Response:
    {
        "match": true/false,
        "score": 0.85,  # 0-1 similarity score
        "distance": 0.45,  # face distance (lower is better)
        "faces_detected": {"image1": 1, "image2": 1}
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'image1' not in data or 'image2' not in data:
            return jsonify({
                "error": "Missing required fields: image1, image2"
            }), 400
        
        logger.info("Decoding images...")
        img1 = decode_base64_image(data['image1'])
        img2 = decode_base64_image(data['image2'])
        
        if img1 is None or img2 is None:
            return jsonify({
                "error": "Failed to decode one or both images"
            }), 400
        
        logger.info("Detecting faces...")
        # Detect face locations
        face_locations1 = face_recognition.face_locations(img1)
        face_locations2 = face_recognition.face_locations(img2)
        
        logger.info(f"Faces detected - Image1: {len(face_locations1)}, Image2: {len(face_locations2)}")
        
        if len(face_locations1) == 0:
            return jsonify({
                "match": False,
                "score": 0,
                "distance": 1,
                "faces_detected": {"image1": 0, "image2": len(face_locations2)},
                "error": "No face detected in first image"
            })
        
        if len(face_locations2) == 0:
            return jsonify({
                "match": False,
                "score": 0,
                "distance": 1,
                "faces_detected": {"image1": len(face_locations1), "image2": 0},
                "error": "No face detected in second image"
            })
        
        # Get face encodings (128-dimension face embeddings)
        encoding1 = face_recognition.face_encodings(img1, face_locations1)[0]
        encoding2 = face_recognition.face_encodings(img2, face_locations2)[0]
        
        # Calculate face distance (0-1, lower is more similar)
        distance = face_recognition.face_distance([encoding1], [encoding2])[0]
        
        # Convert to similarity score (0-1, higher is more similar)
        # face_distance of 0.6 is typical threshold for same person
        score = max(0, 1 - (distance / 0.6))
        
        # Match threshold: 0.6 distance = typical for same person
        is_match = distance < 0.6
        
        logger.info(f"Face comparison - Distance: {distance:.3f}, Score: {score:.3f}, Match: {is_match}")
        
        return jsonify({
            "match": is_match,
            "score": float(score),
            "distance": float(distance),
            "faces_detected": {
                "image1": len(face_locations1),
                "image2": len(face_locations2)
            },
            "threshold": 0.6,
            "message": "Same person" if is_match else "Different person"
        })
        
    except Exception as e:
        logger.error(f"Error comparing faces: {e}")
        return jsonify({
            "error": str(e),
            "match": False,
            "score": 0
        }), 500

@app.route('/detect', methods=['POST'])
def detect_face():
    """
    Detect if image contains a face
    
    Request body:
    {
        "image": "base64_encoded_image"
    }
    
    Response:
    {
        "has_face": true/false,
        "face_count": 1
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'image' not in data:
            return jsonify({"error": "Missing required field: image"}), 400
        
        img = decode_base64_image(data['image'])
        
        if img is None:
            return jsonify({"error": "Failed to decode image"}), 400
        
        face_locations = face_recognition.face_locations(img)
        
        return jsonify({
            "has_face": len(face_locations) > 0,
            "face_count": len(face_locations)
        })
        
    except Exception as e:
        logger.error(f"Error detecting face: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Face Recognition Service...")
    logger.info("Loading face recognition models (this may take a moment)...")
    # Pre-load models by running a dummy detection
    dummy_image = np.zeros((100, 100, 3), dtype=np.uint8)
    face_recognition.face_locations(dummy_image)
    logger.info("Models loaded. Service ready!")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
