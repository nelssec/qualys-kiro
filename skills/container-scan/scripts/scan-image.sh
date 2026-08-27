#!/usr/bin/env bash
# Qualys QScanner container image scan — mirrors the qualys-container-scan GitHub Action:
# get-report / evaluate-policy on an image, then SARIF summary + threshold/policy evaluation.
set -uo pipefail

POWER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SUMMARIZER="$POWER_ROOT/skills/triage/scripts/summarize-sarif.py"

IMAGE_ID="${1:-}"
if [ -z "$IMAGE_ID" ]; then
  echo "Usage: scan-image.sh <image-name:tag | image-id | registry-ref>" >&2
  exit 2
fi

POD="$(echo "${QUALYS_POD:-US3}" | tr '[:lower:]' '[:upper:]')"
STORAGE_DRIVER="${STORAGE_DRIVER:-none}"
IMAGE_PLATFORM="${IMAGE_PLATFORM:-}"
SCAN_SECRETS="${SCAN_SECRETS:-false}"
USE_POLICY_EVALUATION="${USE_POLICY_EVALUATION:-false}"
POLICY_TAGS="${POLICY_TAGS:-}"
MAX_CRITICAL="${MAX_CRITICAL:-0}"
MAX_HIGH="${MAX_HIGH:-0}"
MAX_MEDIUM="${MAX_MEDIUM:--1}"
MAX_LOW="${MAX_LOW:--1}"
SCAN_TIMEOUT="${SCAN_TIMEOUT:-300}"
MAX_NETWORK_RETRIES="${MAX_NETWORK_RETRIES:-30}"
NETWORK_RETRY_WAIT_MIN="${NETWORK_RETRY_WAIT_MIN:-15}"
NETWORK_RETRY_WAIT_MAX="${NETWORK_RETRY_WAIT_MAX:-30}"
LOG_LEVEL="${LOG_LEVEL:-info}"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/.qualys/scans/$(date +%Y%m%d-%H%M%S)}"
QSCANNER_DOCKER_IMAGE="${QSCANNER_DOCKER_IMAGE:-qualys/qscanner:latest}"

if [ -z "${QUALYS_ACCESS_TOKEN:-}" ]; then
  echo "ERROR: QUALYS_ACCESS_TOKEN is not set. Run the setup skill first." >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"

# --- Resolve scanner: native binary preferred, Docker fallback ---
RUN_MODE=""
QSCANNER_BIN=""
if [ -x "$HOME/.qualys/bin/qscanner" ]; then
  QSCANNER_BIN="$HOME/.qualys/bin/qscanner"; RUN_MODE=binary
elif command -v qscanner >/dev/null 2>&1; then
  QSCANNER_BIN="$(command -v qscanner)"; RUN_MODE=binary
elif command -v docker >/dev/null 2>&1; then
  RUN_MODE=docker
  if [ "$STORAGE_DRIVER" != "none" ]; then
    echo "ERROR: STORAGE_DRIVER=$STORAGE_DRIVER requires the native QScanner binary on the host." >&2
    exit 2
  fi
else
  echo "ERROR: QScanner not found and Docker unavailable. Run the setup skill." >&2
  exit 2
fi

scan_types="pkg"
[ "$SCAN_SECRETS" = "true" ] && scan_types="pkg,secret"

mode="get-report"
[ "$USE_POLICY_EVALUATION" = "true" ] && mode="evaluate-policy"

args=(
  --pod "$POD"
  --mode "$mode"
  --scan-types "$scan_types"
  --format "json"
  --report-format "sarif,json"
  --scan-timeout "${SCAN_TIMEOUT}s"
  --log-level "$LOG_LEVEL"
  --max-network-retries "$MAX_NETWORK_RETRIES"
  --network-retry-wait-min "${NETWORK_RETRY_WAIT_MIN}s"
  --network-retry-wait-max "${NETWORK_RETRY_WAIT_MAX}s"
)
[ -n "$POLICY_TAGS" ] && args+=(--policy-tags "$POLICY_TAGS")

echo "============================================================"
echo "Qualys Container Scan"
echo "============================================================"
echo "Image:          $IMAGE_ID"
echo "POD:            $POD"
echo "Storage Driver: $STORAGE_DRIVER"
[ -n "$IMAGE_PLATFORM" ] && echo "Platform:       $IMAGE_PLATFORM"
echo "Scan Types:     $scan_types"
echo "Output:         $OUTPUT_DIR"
echo "Runner:         $RUN_MODE"
echo "============================================================"

if [ "$RUN_MODE" = "binary" ]; then
  args+=(--output-dir "$OUTPUT_DIR" image "$IMAGE_ID")
  [ "$STORAGE_DRIVER" != "none" ] && args+=(--storage-driver "$STORAGE_DRIVER")
  [ -n "$IMAGE_PLATFORM" ] && args+=(--platform "$IMAGE_PLATFORM")
  "$QSCANNER_BIN" "${args[@]}"
  exit_code=$?
else
  args+=(--output-dir /qscanner-output image "$IMAGE_ID")
  [ -n "$IMAGE_PLATFORM" ] && args+=(--platform "$IMAGE_PLATFORM")
  docker run --rm \
    -e QUALYS_ACCESS_TOKEN \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$OUTPUT_DIR":/qscanner-output \
    "$QSCANNER_DOCKER_IMAGE" "${args[@]}"
  exit_code=$?
fi

# --- Summarize + evaluate ---
sarif_file="$(ls "$OUTPUT_DIR"/*-Report.sarif.json 2>/dev/null | head -n1 || true)"

if [ "$USE_POLICY_EVALUATION" = "true" ]; then
  [ -n "$sarif_file" ] && python3 "$SUMMARIZER" "$sarif_file" || true
  case "$exit_code" in
    0)  echo "Policy result: ALLOW — scan PASSED"; exit 0 ;;
    42) echo "Policy result: DENY — scan FAILED" >&2; exit 1 ;;
    43) echo "Policy result: AUDIT — scan passed with warnings"; exit 0 ;;
    *)  echo "Policy evaluation failed (exit $exit_code)" >&2; exit 1 ;;
  esac
fi

if [ -z "$sarif_file" ]; then
  echo "ERROR: no SARIF report found in $OUTPUT_DIR (scanner exit $exit_code)." >&2
  if [ "$exit_code" -eq 40 ]; then
    echo "Qualys cloud is still processing the report — retry in a few minutes." >&2
  fi
  exit 1
fi

python3 "$SUMMARIZER" "$sarif_file" \
  --max-critical "$MAX_CRITICAL" --max-high "$MAX_HIGH" \
  --max-medium "$MAX_MEDIUM" --max-low "$MAX_LOW"
verdict=$?

echo ""
echo "Reports in: $OUTPUT_DIR"
exit "$verdict"
