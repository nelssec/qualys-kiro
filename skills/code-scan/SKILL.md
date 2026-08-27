---
name: code-scan
description: Scan a code repository for vulnerable dependencies (SCA), exposed secrets, and generate SBOMs with Qualys QScanner
---

# Qualys Code Scan (SCA)

Scans a source repository for vulnerable open-source dependencies, optionally detects secrets and generates an SBOM. This is the Kiro equivalent of the `qualys-code-scan` GitHub Action and uses the identical two-phase flow: upload inventory to Qualys, then fetch the vulnerability report.

## Prerequisites

`QUALYS_ACCESS_TOKEN` set in the environment and QScanner installed — if either is missing, run the `setup` skill first.

## Run

```bash
bash scripts/scan-repo.sh [path-to-repo]
```

Path defaults to the current directory. Options are environment variables (all optional, defaults mirror the GitHub Action):

| Variable | Default | Meaning |
|----------|---------|---------|
| `QUALYS_POD` | `US3` | Qualys platform POD |
| `SCAN_SECRETS` | `false` | Also detect secrets (`--scan-types pkg,secret`) |
| `GENERATE_SBOM` | `false` | Generate SBOM |
| `SBOM_FORMAT` | `spdx` | `spdx`, `cyclonedx`, or `both` |
| `EXCLUDE_DIRS` | – | Comma-separated dirs to skip |
| `EXCLUDE_FILES` | – | Comma-separated file patterns to skip |
| `USE_POLICY_EVALUATION` | `false` | Evaluate Qualys cloud policy instead of local thresholds |
| `POLICY_TAGS` | – | Comma-separated policy tags |
| `MAX_CRITICAL` / `MAX_HIGH` | `0` / `0` | Threshold; `-1` = unlimited |
| `MAX_MEDIUM` / `MAX_LOW` | `-1` / `-1` | Threshold; `-1` = unlimited |
| `OFFLINE_SCAN` | `false` | Local scan only, nothing uploaded to Qualys cloud |
| `SCAN_MODE` | – | Override: `inventory-only`, `scan-only`, `get-report`, `evaluate-policy` |
| `SCAN_TIMEOUT` | `300` | Seconds |
| `REPORT_FETCH_RETRIES` | `3` | Re-runs if the cloud report isn't ready (exit 40/41) |
| `REPORT_FETCH_DELAY` | `60` | Seconds between re-runs |
| `OUTPUT_DIR` | `.qualys/scans/<timestamp>` | Where reports land |

Example — full scan with secrets and SBOM:

```bash
SCAN_SECRETS=true GENERATE_SBOM=true SBOM_FORMAT=both bash scripts/scan-repo.sh .
```

## What the script does

1. Phase 1: `qscanner --mode inventory-only ... repo <path>` (uploads inventory, primes the Qualys backend), waits 10s.
2. Phase 2: `--mode get-report` (or `evaluate-policy` when `USE_POLICY_EVALUATION=true`), retried up to `REPORT_FETCH_RETRIES` times if the report isn't ready yet.
3. Parses the SARIF report, prints a severity summary, and evaluates thresholds/policy. Exits `0` on pass, `1` on threshold/policy failure.

## After the scan

Read `<output-dir>/*-Report.sarif.json` and follow the `triage` skill: report the severity breakdown, the verdict, and remediation guidance. Do not paste the raw SARIF into chat.

## Failure modes

- Exit 40/41 after all retries → Qualys cloud is still processing; suggest re-running in a couple of minutes.
- Exit 42 → policy DENY. Exit 43 → policy AUDIT (warn, don't fail). Full table: `../../references/exit-codes.md`.
- Auth errors → token invalid/expired or wrong `QUALYS_POD`; re-run `setup`.
