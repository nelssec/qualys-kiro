#!/usr/bin/env bash
# Qualys QScanner code (SCA) scan — mirrors the qualys-code-scan GitHub Action:
# Phase 1: inventory-only upload  →  Phase 2: get-report / evaluate-policy (with retries)
# then SARIF summary + threshold/policy evaluation.
set -uo pipefail

POWER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SUMMARIZER="$POWER_ROOT/skills/triage/scripts/summarize-sarif.py"

# --- Inputs (env, defaults mirror the GitHub Action) ---
SCAN_PATH="$(cd "${1:-.}" && pwd)"
POD="$(echo "${QUALYS_POD:-US3}" | tr '[:lower:]' '[:upper:]')"
SCAN_SECRETS="${SCAN_SECRETS:-false}"
GENERATE_SBOM="${GENERATE_SBOM:-false}"
SBOM_FORMAT="${SBOM_FORMAT:-spdx}"
EXCLUDE_DIRS="${EXCLUDE_DIRS:-}"
EXCLUDE_FILES="${EXCLUDE_FILES:-}"
USE_POLICY_EVALUATION="${USE_POLICY_EVALUATION:-false}"
POLICY_TAGS="${POLICY_TAGS:-}"
MAX_CRITICAL="${MAX_CRITICAL:-0}"
MAX_HIGH="${MAX_HIGH:-0}"
MAX_MEDIUM="${MAX_MEDIUM:--1}"
MAX_LOW="${MAX_LOW:--1}"
OFFLINE_SCAN="${OFFLINE_SCAN:-false}"
SCAN_MODE="${SCAN_MODE:-}"
SCAN_TIMEOUT="${SCAN_TIMEOUT:-300}"
REPORT_FETCH_RETRIES="${REPORT_FETCH_RETRIES:-3}"
REPORT_FETCH_DELAY="${REPORT_FETCH_DELAY:-60}"
MAX_NETWORK_RETRIES="${MAX_NETWORK_RETRIES:-5}"
NETWORK_RETRY_WAIT_MIN="${NETWORK_RETRY_WAIT_MIN:-10}"
NETWORK_RETRY_WAIT_MAX="${NETWORK_RETRY_WAIT_MAX:-15}"
LOG_LEVEL="${LOG_LEVEL:-info}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCAN_PATH/.qualys/scans/$(date +%Y%m%d-%H%M%S)}"
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
else
  echo "ERROR: QScanner not found and Docker unavailable. Run the setup skill." >&2
  exit 2
fi

# --- Build args ---
scan_types="pkg"
[ "$SCAN_SECRETS" = "true" ] && scan_types="pkg,secret"

formats="json"
if [ "$GENERATE_SBOM" = "true" ]; then
  case "$SBOM_FORMAT" in
    both) formats="json,spdx,cyclonedx" ;;
    cyclonedx) formats="json,cyclonedx" ;;
    *) formats="json,spdx" ;;
  esac
fi

run_qscanner() { # $1 = mode
  local mode="$1"
  local args=(
    --pod "$POD"
    --mode "$mode"
    --scan-types "$scan_types"
    --format "$formats"
    --report-format "sarif,json"
    --scan-timeout "${SCAN_TIMEOUT}s"
    --log-level "$LOG_LEVEL"
    --max-network-retries "$MAX_NETWORK_RETRIES"
    --network-retry-wait-min "${NETWORK_RETRY_WAIT_MIN}s"
    --network-retry-wait-max "${NETWORK_RETRY_WAIT_MAX}s"
  )
  [ -n "$POLICY_TAGS" ] && args+=(--policy-tags "$POLICY_TAGS")

  if [ "$RUN_MODE" = "binary" ]; then
    args+=(--output-dir "$OUTPUT_DIR" repo "$SCAN_PATH")
    [ -n "$EXCLUDE_DIRS" ] && args+=(--exclude-dirs "$EXCLUDE_DIRS")
    [ -n "$EXCLUDE_FILES" ] && args+=(--exclude-files "$EXCLUDE_FILES")
    [ "$OFFLINE_SCAN" = "true" ] && args+=(--offline-scan=true)
    "$QSCANNER_BIN" "${args[@]}"
  else
    args+=(--output-dir /qscanner-output repo /qscanner-scan)
    [ -n "$EXCLUDE_DIRS" ] && args+=(--exclude-dirs "$EXCLUDE_DIRS")
    [ -n "$EXCLUDE_FILES" ] && args+=(--exclude-files "$EXCLUDE_FILES")
    [ "$OFFLINE_SCAN" = "true" ] && args+=(--offline-scan=true)
    docker run --rm \
      -e QUALYS_ACCESS_TOKEN \
      -v "$SCAN_PATH":/qscanner-scan:ro \
      -v "$OUTPUT_DIR":/qscanner-output \
      "$QSCANNER_DOCKER_IMAGE" "${args[@]}"
  fi
}

echo "============================================================"
echo "Qualys Code Scan (SCA)"
echo "============================================================"
echo "Scan Path:  $SCAN_PATH"
echo "POD:        $POD"
echo "Scan Types: $scan_types"
echo "Output:     $OUTPUT_DIR"
echo "Runner:     $RUN_MODE"
echo "============================================================"

# --- Determine mode(s) ---
report_mode="get-report"
[ "$USE_POLICY_EVALUATION" = "true" ] && report_mode="evaluate-policy"

exit_code=0
if [ -n "$SCAN_MODE" ]; then
  # Explicit mode: run exactly what was requested
  run_qscanner "$SCAN_MODE"; exit_code=$?
  case "$SCAN_MODE" in inventory-only|scan-only) skip_report=true ;; *) skip_report=false ;; esac
else
  skip_report=false
  echo ""
  echo "Phase 1: Uploading inventory to Qualys..."
  run_qscanner "inventory-only"; inv_code=$?
  if [ "$inv_code" -eq 0 ]; then
    echo "Inventory uploaded. Waiting 10s for backend processing..."
    sleep 10
  else
    echo "WARNING: inventory upload exited with code $inv_code, proceeding to report fetch..."
  fi

  echo ""
  echo "Phase 2: Fetching vulnerability report..."
  attempt=1
  max_attempts=$((REPORT_FETCH_RETRIES + 1))
  while :; do
    run_qscanner "$report_mode"; exit_code=$?
    if [ "$exit_code" -ne 40 ] && [ "$exit_code" -ne 41 ]; then
      break
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "ERROR: vulnerability report not available after $max_attempts attempts." >&2
      echo "Qualys cloud may still be processing — retry in a few minutes." >&2
      break
    fi
    attempt=$((attempt + 1))
    echo "Report not ready (exit $exit_code). Retrying in ${REPORT_FETCH_DELAY}s (attempt $attempt/$max_attempts)..."
    sleep "$REPORT_FETCH_DELAY"
  done
fi

# --- Summarize + evaluate ---
if [ "$skip_report" = "true" ]; then
  echo "Mode '$SCAN_MODE' does not produce a report; done (exit $exit_code)."
  exit "$exit_code"
fi

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
  exit 1
fi

python3 "$SUMMARIZER" "$sarif_file" \
  --max-critical "$MAX_CRITICAL" --max-high "$MAX_HIGH" \
  --max-medium "$MAX_MEDIUM" --max-low "$MAX_LOW"
verdict=$?

echo ""
echo "Reports in: $OUTPUT_DIR"
exit "$verdict"
