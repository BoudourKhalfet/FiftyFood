@echo off
chcp 65001 >nul
cls
echo ============================================
echo    FiftyFood - Starting All Services
echo ============================================
echo.

:: Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://python.org
    pause
    exit /b 1
)

:: Check if Node is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org
    pause
    exit /b 1
)

echo [1/4] Checking Face Service dependencies...
cd face-service
pip show face-recognition >nul 2>&1
if errorlevel 1 (
    echo [!] Installing Python dependencies...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo [ERROR] Failed to install Python dependencies
        echo Make sure you have CMake installed: https://cmake.org/download/
        pause
        exit /b 1
    )
)
cd ..

echo [2/4] Installing Node dependencies (if needed)...
cd backend
call npm install --legacy-peer-deps >nul 2>&1
cd ..

echo [3/4] Starting Face Recognition Service...
start "Face Recognition Service" cmd /k "cd /d %~dp0face-service && echo Starting Face Recognition Service on http://localhost:5000 && python app.py"

:: Wait for face service to be ready
echo [3/4] Waiting for Face Service to start...
timeout /t 5 /nobreak >nul

:: Check if face service is running
curl -s http://localhost:5000/health >nul 2>&1
if errorlevel 1 (
    echo [!] Face service may still be loading, waiting 5 more seconds...
    timeout /t 5 /nobreak >nul
)

echo [4/4] Starting NestJS Backend...
cd backend
set FACE_SERVICE_URL=http://localhost:5000
start "NestJS Backend" cmd /k "echo Starting NestJS Backend on http://localhost:3000 && npm run start:dev"

echo.
echo ============================================
echo    All Services Started!
echo ============================================
echo.
echo Face Recognition: http://localhost:5000
echo NestJS Backend:   http://localhost:3000
echo.
echo [i] Both services are running in separate windows
echo [i] Press Ctrl+C in each window to stop
echo.
pause
