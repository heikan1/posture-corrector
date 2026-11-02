@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   Posture Corrector - Project Setup
echo ========================================================
echo.

:: 1. Arac Kontrolleri (Prerequisites Check)
echo [1/4] Checking prerequisites...

where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter SDK not found in PATH!
    echo Please install Flutter and add it to your PATH: https://docs.flutter.dev/get-started/install
    exit /b 1
)

where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Node.js not found in PATH!
    echo Please install Node.js (v18+ recommended): https://nodejs.org/
    exit /b 1
)

where npm >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] npm not found in PATH!
    exit /b 1
)

echo [OK] Flutter, Node.js, and npm detected.
echo.

:: 2. Firebase Konfigurasyonu
echo [2/4] Setting up Firebase config...
if not exist ".firebaserc" (
    if exist ".firebaserc.example" (
        copy ".firebaserc.example" ".firebaserc" >nul
        echo [OK] Created .firebaserc from .firebaserc.example
    )
) else (
    echo [INFO] .firebaserc already exists.
)
echo.

:: 3. Cloud Functions Bagimliliklari
echo [3/4] Installing Cloud Functions dependencies (npm install)...
if exist "functions\package.json" (
    pushd functions
    call npm install
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] npm install failed in functions directory!
        popd
        exit /b 1
    )
    popd
    echo [OK] Cloud Functions dependencies installed.
) else (
    echo [WARN] functions\package.json not found, skipping.
)
echo.

:: 4. Flutter Mobil Uygulama Bagimliliklari
echo [4/4] Installing Flutter app dependencies (flutter pub get)...
if exist "mobile\posture_corrector\pubspec.yaml" (
    pushd mobile\posture_corrector
    call flutter pub get
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] flutter pub get failed!
        popd
        exit /b 1
    )
    popd
    echo [OK] Flutter dependencies installed.
) else (
    echo [WARN] mobile\posture_corrector\pubspec.yaml not found, skipping.
)
echo.

:: 5. Kontrol ve Hatirlatmalar
echo ========================================================
echo   Setup Completed Successfully!
echo ========================================================
if not exist "mobile\posture_corrector\android\app\google-services.json" (
    echo [NOTE] Firebase setup reminder:
    echo   Please place your 'google-services.json' in:
    echo   mobile\posture_corrector\android\app\google-services.json
    echo.
)
echo You are ready to develop!
echo To run mobile app: cd mobile\posture_corrector ^&^& flutter run
echo.
pause

