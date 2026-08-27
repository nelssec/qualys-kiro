---
name: setup
description: Install QScanner and verify Qualys credentials before running any scan
---

# QScanner Setup

Run this before the first scan in a workspace, or whenever a scan script reports that QScanner or credentials are missing.

## Steps

1. **Check credentials.** Verify `QUALYS_ACCESS_TOKEN` is set (check existence only — `[ -n "$QUALYS_ACCESS_TOKEN" ]` — never print the value). If missing, stop and ask the user to set it:
   - Token: Qualys UI → Container Security module → an API access token with CS API scope.
   - Tell them to export it in their shell profile or add it to Kiro's environment settings, then retry.
   - Also confirm `QUALYS_POD` (default `US3`). Valid PODs: US1, US2, US3, US4, EU1, EU2, CA1, IN1, AU1, UK1, AE1, KSA1.

2. **Install the scanner.** Run:

   ```bash
   bash scripts/install-qscanner.sh
   ```

   Behavior (mirrors the GitHub Actions):
   - On **linux/amd64** it downloads `qscanner.gz` + `qscanner.sha256` from the qualys-code-scan release mirror, verifies the SHA256 checksum, and installs to `~/.qualys/bin/qscanner`.
   - On **macOS or other architectures** there is no binary on the mirror. The script falls back to checking for `qscanner` already on the `PATH`, then for Docker. If Docker is available, scans run through the QScanner container image instead (the scan scripts handle this automatically via `QSCANNER_DOCKER_IMAGE`, default `qualys/qscanner:latest`).
   - If neither is available, tell the user to download the QScanner build for their platform from the Qualys Container Security module (Downloads section) and place it at `~/.qualys/bin/qscanner` (`chmod +x` it).

3. **Verify.** The script finishes by printing the resolved scanner (binary path or Docker image) and its version. Report that to the user.

## Notes

- Installation is idempotent — if `~/.qualys/bin/qscanner` already exists it is reused.
- Never run the install with `sudo`; everything lives under `~/.qualys/`.
