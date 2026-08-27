---
name: container-scan
description: Scan a container image for OS and package vulnerabilities and secrets with Qualys QScanner
---

# Qualys Container Scan

Scans a container image (local Docker/Podman/containerd image, or a registry reference) for OS package and software vulnerabilities, optionally secrets. Kiro equivalent of the `qualys-container-scan` GitHub Action.

## Prerequisites

- `QUALYS_ACCESS_TOKEN` set and QScanner installed (`setup` skill).
- The image present locally (`docker images`) or pullable from a registry.

## Run

```bash
bash scripts/scan-image.sh <image>
```

`<image>` can be a name:tag (`myapp:latest`), image ID/digest, or registry reference. Options via environment variables:

| Variable | Default | Meaning |
|----------|---------|---------|
| `QUALYS_POD` | `US3` | Qualys platform POD |
| `STORAGE_DRIVER` | `none` | `docker-overlay2`, `containerd-overlayfs`, `podman-overlay` — scan directly from host storage |
| `IMAGE_PLATFORM` | – | e.g. `linux/amd64` for multi-arch images |
| `SCAN_SECRETS` | `false` | Also detect secrets in image layers |
| `USE_POLICY_EVALUATION` | `false` | Qualys cloud policy instead of local thresholds |
| `POLICY_TAGS` | – | Comma-separated policy tags |
| `MAX_CRITICAL` / `MAX_HIGH` | `0` / `0` | Thresholds; `-1` = unlimited |
| `MAX_MEDIUM` / `MAX_LOW` | `-1` / `-1` | Thresholds; `-1` = unlimited |
| `SCAN_TIMEOUT` | `300` | Seconds |
| `OUTPUT_DIR` | `./.qualys/scans/<timestamp>` | Where reports land |

Example — scan the image just built, fail on any critical or high:

```bash
bash scripts/scan-image.sh myapp:latest
```

## What the script does

1. Runs `qscanner --mode get-report ... image <image>` (or `evaluate-policy`), with `--storage-driver` / `--platform` when set.
2. Parses the SARIF report, prints the severity summary, evaluates thresholds or policy. Exit `0` = pass, `1` = fail.

## Docker-fallback caveat

When QScanner runs via its Docker image (no native binary), the script mounts the Docker socket so QScanner can read local images. `STORAGE_DRIVER` modes other than `none` require the native binary on the host — tell the user that if they ask for it on macOS.

## After the scan

Follow the `triage` skill: severity breakdown, base-image assessment (many container findings are fixed by bumping the base image tag), verdict, remediation.
