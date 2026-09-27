#!/bin/bash
# Downloads and builds the bundled Piper TTS runtime into DadJoke/Resources/.
# This runtime is gitignored (it's ~230MB of binaries) so it must be
# regenerated once after cloning this repo, before building the app.
#
# What this produces:
#   DadJoke/Resources/PythonRuntime/   - portable Python 3.11 + piper-tts + onnxruntime
#   DadJoke/Resources/PiperVoice/      - the en_GB-alan-medium British voice model
#   DadJoke/Resources/speak.py         - already tracked in git, not touched here
#
# Safe to re-run; it rebuilds from scratch each time.

set -euo pipefail

PYTHON_BUILD_TAG="20260924"
PYTHON_VERSION="3.11.16"
VOICE_NAME="en_GB-alan-medium"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_ROOT/DadJoke/Resources"
RUNTIME_DIR="$RESOURCES_DIR/PythonRuntime"
VOICE_DIR="$RESOURCES_DIR/PiperVoice"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This script only supports Apple Silicon (arm64) Macs." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Downloading portable Python ${PYTHON_VERSION}..."
curl -sL -o "$WORK_DIR/cpython.tar.gz" \
  "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_BUILD_TAG}/cpython-${PYTHON_VERSION}+${PYTHON_BUILD_TAG}-aarch64-apple-darwin-install_only_stripped.tar.gz"
tar -xzf "$WORK_DIR/cpython.tar.gz" -C "$WORK_DIR"

PYTHON_BIN="$WORK_DIR/python/bin/python3.11"

echo "==> Installing piper-tts and dependencies..."
"$PYTHON_BIN" -m ensurepip --upgrade >/dev/null
"$PYTHON_BIN" -m pip install --quiet --upgrade pip
"$PYTHON_BIN" -m pip install --quiet piper-tts

echo "==> Trimming unneeded packages and caches..."
SITE_PACKAGES="$WORK_DIR/python/lib/python3.11/site-packages"
rm -rf "$SITE_PACKAGES/pip" "$SITE_PACKAGES"/pip-*.dist-info
rm -rf "$SITE_PACKAGES/setuptools" "$SITE_PACKAGES"/setuptools-*.dist-info
rm -rf "$WORK_DIR/python/lib/python3.11/ensurepip"
rm -rf "$WORK_DIR/python/lib/python3.11/idlelib" \
       "$WORK_DIR/python/lib/python3.11/tkinter" \
       "$WORK_DIR/python/lib/python3.11/lib2to3" \
       "$WORK_DIR/python/lib/python3.11/turtledemo"
find "$WORK_DIR/python" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "$WORK_DIR/python" -name "*.dist-info" -exec sh -c 'rm -f "$1"/RECORD "$1"/INSTALLER' _ {} \;

echo "==> Downloading British voice (${VOICE_NAME})..."
mkdir -p "$WORK_DIR/voice"
curl -sL -o "$WORK_DIR/voice/${VOICE_NAME}.onnx" \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alan/medium/${VOICE_NAME}.onnx"
curl -sL -o "$WORK_DIR/voice/${VOICE_NAME}.onnx.json" \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alan/medium/${VOICE_NAME}.onnx.json"

echo "==> Installing into $RESOURCES_DIR..."
rm -rf "$RUNTIME_DIR"
mkdir -p "$RESOURCES_DIR"
cp -R "$WORK_DIR/python" "$RUNTIME_DIR"
mkdir -p "$VOICE_DIR"
cp "$WORK_DIR/voice/${VOICE_NAME}.onnx" "$VOICE_DIR/"
cp "$WORK_DIR/voice/${VOICE_NAME}.onnx.json" "$VOICE_DIR/"

echo "==> Verifying synthesis..."
TEST_WAV="$WORK_DIR/test.wav"
echo "Testing, one two three." | "$RUNTIME_DIR/bin/python3.11" "$RESOURCES_DIR/speak.py" \
  "$VOICE_DIR/${VOICE_NAME}.onnx" "$VOICE_DIR/${VOICE_NAME}.onnx.json" \
  "$TEST_WAV" "$WORK_DIR/espeak_cache"

if [[ -s "$TEST_WAV" ]]; then
  echo "==> Done. Runtime installed at $RUNTIME_DIR"
else
  echo "Synthesis test failed - runtime may not work correctly." >&2
  exit 1
fi
