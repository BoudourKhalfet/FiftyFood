# Face Recognition Service

Intelligent face comparison using Python + face_recognition library (dlib).

## Features

- **Face Detection**: Detects faces in images
- **Face Comparison**: Compares two faces and returns similarity score
- **High Accuracy**: Uses 128-dimension face embeddings
- **Free & Local**: No cloud APIs, no billing, no limits

## Setup

### Prerequisites

- Python 3.8+
- CMake (for dlib compilation)

### Windows

```bash
# Install CMake from https://cmake.org/download/
# Make sure to add CMake to PATH during installation

# Install dependencies
pip install -r requirements.txt
```

### Linux/Mac

```bash
# Install system dependencies
# Ubuntu/Debian:
sudo apt-get install -y cmake libdlib-dev libopenblas-dev liblapack-dev

# macOS:
brew install cmake dlib

# Install Python dependencies
pip install -r requirements.txt
```

## Running

### Development

```bash
python app.py
```

Service runs on `http://localhost:5000`

### Production

```bash
gunicorn -w 2 -b 0.0.0.0:5000 app:app
```

## API Endpoints

### Health Check
```bash
GET /health
```

### Compare Faces
```bash
POST /compare
Content-Type: application/json

{
    "image1": "data:image/jpeg;base64,/9j/4AAQ...",
    "image2": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

Response:
```json
{
    "match": true,
    "score": 0.92,
    "distance": 0.08,
    "faces_detected": {
        "image1": 1,
        "image2": 1
    },
    "threshold": 0.6,
    "message": "Same person"
}
```

### Detect Face
```bash
POST /detect
Content-Type: application/json

{
    "image": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

## How It Works

1. **Face Detection**: Uses HOG (Histogram of Oriented Gradients) to find faces
2. **Face Encoding**: Creates 128-dimension vector representing face features
3. **Comparison**: Calculates Euclidean distance between vectors
4. **Threshold**: < 0.6 distance = same person (tunable)

## Integration with NestJS Backend

The NestJS backend calls this service at `http://localhost:5000/compare` to verify faces.

Score interpretation:
- **0.90+**: Very high confidence (same person)
- **0.70-0.90**: High confidence (likely same person)
- **0.60-0.70**: Moderate confidence (possible match)
- **< 0.60**: Low confidence (different person)
