#!/usr/bin/env bash
# Cloud Agent install script for the CIT App (Flutter + Firebase).
# Idempotent: safe to run repeatedly and on a warm/snapshotted disk.
set -euo pipefail

# Flutter 3.38.3 (Dart 3.10.1) matches the README and the SDK constraint
# recorded in pubspec.lock (flutter >=3.38.0, dart >=3.10.0).
FLUTTER_VERSION="3.38.3"
FLUTTER_DIR="${HOME}/flutter"

# 1. Install the Flutter SDK if it is not already present on disk.
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "==> Installing Flutter ${FLUTTER_VERSION} to ${FLUTTER_DIR}"
  curl -fSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -rf "${FLUTTER_DIR}"
  tar xf /tmp/flutter.tar.xz -C "${HOME}"
  rm -f /tmp/flutter.tar.xz
else
  echo "==> Flutter already present at ${FLUTTER_DIR}, skipping download"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
git config --global --add safe.directory "${FLUTTER_DIR}" || true
flutter config --no-analytics >/dev/null 2>&1 || true

# 2. Precache the web engine artifacts so `flutter run -d web-server` starts fast.
flutter precache --web

# 3. Fetch the app's Dart/Flutter package dependencies.
flutter pub get

# 4. Install Cloud Functions (Node) dependencies when npm is available.
if command -v npm >/dev/null 2>&1; then
  echo "==> Installing Cloud Functions dependencies"
  (cd functions && npm ci)
else
  echo "==> npm not found on PATH, skipping Cloud Functions dependencies"
fi

# 5. Make the Flutter SDK and Chrome discoverable in the agent's interactive shells.
if ! grep -q 'flutter/bin' "${HOME}/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# Flutter SDK (Cloud Agent environment)'
    echo 'export PATH="${HOME}/flutter/bin:${PATH}"'
    echo 'export CHROME_EXECUTABLE="/usr/local/bin/google-chrome"'
  } >> "${HOME}/.bashrc"
fi

echo "==> Install complete: $(flutter --version | head -n 1)"
