#!/usr/bin/env bash
# Install Qualys QScanner, mirroring the qualys-code-scan / qualys-container-scan
# GitHub Actions: download binary + sha256 from the release mirror, verify, install.
# Falls back to an existing PATH binary or the QScanner Docker image on non-linux/amd64.
set -euo pipefail

QSCANNER_BINARY_URL="${QSCANNER_BINARY_URL:-https://github.com/nelssec/qualys-code-scan/releases/latest/download/qscanner.gz}"
QSCANNER_SHA256_URL="${QSCANNER_SHA256_URL:-https://github.com/nelssec/qualys-code-scan/releases/latest/download/qscanner.sha256}"
QSCANNER_DOCKER_IMAGE="${QSCANNER_DOCKER_IMAGE:-qualys/qscanner:latest}"
INSTALL_DIR="${QSCANNER_INSTALL_DIR:-$HOME/.qualys/bin}"
BINARY_PATH="$INSTALL_DIR/qscanner"

log() { echo "[qscanner-setup] $*"; }

platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
esac

# 1. Already installed?
if [ -x "$BINARY_PATH" ]; then
  log "QScanner already installed at $BINARY_PATH"
  "$BINARY_PATH" version 2>/dev/null || true
  exit 0
fi

# 2. Already on PATH?
if command -v qscanner >/dev/null 2>&1; then
  log "Using existing QScanner on PATH: $(command -v qscanner)"
  qscanner version 2>/dev/null || true
  exit 0
fi

# 3. linux/amd64: download from the release mirror with checksum verification
if [ "$platform" = "linux" ] && [ "$arch" = "amd64" ]; then
  mkdir -p "$INSTALL_DIR"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  log "Downloading QScanner checksum..."
  curl -fsSL "$QSCANNER_SHA256_URL" -o "$tmpdir/qscanner.sha256"
  expected_hash="$(awk '{print $1}' "$tmpdir/qscanner.sha256" | head -n1)"
  log "Expected SHA256: $expected_hash"

  log "Downloading QScanner binary..."
  curl -fsSL "$QSCANNER_BINARY_URL" -o "$tmpdir/qscanner.gz"

  log "Verifying SHA256 checksum..."
  actual_hash="$(sha256sum "$tmpdir/qscanner.gz" | awk '{print $1}')"
  if [ "$actual_hash" != "$expected_hash" ]; then
    echo "ERROR: SHA256 mismatch. Expected: $expected_hash Got: $actual_hash" >&2
    exit 1
  fi
  log "Checksum verified."

  gunzip -c "$tmpdir/qscanner.gz" > "$BINARY_PATH"
  chmod 755 "$BINARY_PATH"
  log "QScanner installed at $BINARY_PATH"
  "$BINARY_PATH" version 2>/dev/null || true
  exit 0
fi

# 4. Non linux/amd64: fall back to Docker
if command -v docker >/dev/null 2>&1; then
  log "Platform is ${platform}/${arch}; no native binary on the release mirror."
  log "Docker detected — scans will run via image: $QSCANNER_DOCKER_IMAGE"
  docker pull "$QSCANNER_DOCKER_IMAGE" || {
    log "WARNING: could not pull $QSCANNER_DOCKER_IMAGE."
    log "Set QSCANNER_DOCKER_IMAGE to your registry's QScanner image, or download the"
    log "${platform}/${arch} build from the Qualys Container Security module (Downloads)"
    log "and place it at $BINARY_PATH"
    exit 1
  }
  exit 0
fi

echo "ERROR: No QScanner binary for ${platform}/${arch} and Docker is not available." >&2
echo "Download the QScanner build for your platform from the Qualys Container Security" >&2
echo "module (Downloads section) and place it at $BINARY_PATH (chmod +x)." >&2
exit 1
