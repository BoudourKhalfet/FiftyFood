@echo off
echo Starting Face Recognition Service...
echo.
echo Prerequisites:
echo 1. Python 3.8+ installed
echo 2. CMake installed (from https://cmake.org/download/)
echo 3. Run: pip install -r requirements.txt
echo.
echo Service will run on http://localhost:5000
echo.

python app.py

pause
