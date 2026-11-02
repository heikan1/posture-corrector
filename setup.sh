#!/usr/bin/env bash

set -e

# Renkli ciktilar
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================================"
echo "  Posture Corrector - Project Setup"
echo "========================================================"
echo ""

# 1. Arac Kontrolleri
echo "[1/4] Checking prerequisites..."

if ! command -v flutter >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Flutter SDK not found in PATH!${NC}"
    echo "Please install Flutter: https://docs.flutter.dev/get-started/install"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Node.js not found in PATH!${NC}"
    echo "Please install Node.js (v18+ recommended): https://nodejs.org/"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] npm not found in PATH!${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Flutter, Node.js, and npm detected.${NC}"
echo ""

# 2. Firebase Konfigurasyonu
echo "[2/4] Setting up Firebase config..."
if [ ! -f ".firebaserc" ]; then
    if [ -f ".firebaserc.example" ]; then
        cp ".firebaserc.example" ".firebaserc"
        echo -e "${GREEN}[OK] Created .firebaserc from .firebaserc.example${NC}"
    fi
else
    echo -e "${YELLOW}[INFO] .firebaserc already exists.${NC}"
fi
echo ""

# 3. Cloud Functions Bagimliliklari
echo "[3/4] Installing Cloud Functions dependencies (npm install)..."
if [ -d "functions" ] && [ -f "functions/package.json" ]; then
    (cd functions && npm install)
    echo -e "${GREEN}[OK] Cloud Functions dependencies installed.${NC}"
else
    echo -e "${YELLOW}[WARN] functions/package.json not found, skipping.${NC}"
fi
echo ""

# 4. Flutter Mobil Uygulama Bagimliliklari
echo "[4/4] Installing Flutter app dependencies (flutter pub get)..."
if [ -d "mobile/posture_corrector" ] && [ -f "mobile/posture_corrector/pubspec.yaml" ]; then
    (cd mobile/posture_corrector && flutter pub get)
    echo -e "${GREEN}[OK] Flutter dependencies installed.${NC}"
else
    echo -e "${YELLOW}[WARN] mobile/posture_corrector/pubspec.yaml not found, skipping.${NC}"
fi
echo ""

# 5. Kontrol ve Hatirlatmalar
echo "========================================================"
echo -e "${GREEN}  Setup Completed Successfully!${NC}"
echo "========================================================"
if [ ! -f "mobile/posture_corrector/android/app/google-services.json" ]; then
    echo -e "${YELLOW}[NOTE] Firebase setup reminder:${NC}"
    echo "  Please place your 'google-services.json' in:"
    echo "  mobile/posture_corrector/android/app/google-services.json"
    echo ""
fi
echo "You are ready to develop!"
echo "To run mobile app: cd mobile/posture_corrector && flutter run"
echo ""
