---
name: "Qualys QScanner"
description: "Scan code repositories and container images for vulnerabilities, exposed secrets, and generate SBOMs using Qualys QScanner"
keywords: ["qualys", "qscanner", "vulnerability", "vulnerability scan", "security scan", "container scan", "image scan", "code scan", "sca", "sbom", "secrets", "cve"]
---

# Qualys QScanner Power

This power lets you scan the user's code and container images for vulnerabilities using Qualys QScanner — the same scanner behind the Qualys GitHub Actions (qualys-code-scan, qualys-container-scan) and the other Qualys CI/CD integrations (GitLab, Jenkins, Azure DevOps, Harness).

## What you can do

| Task | Skill | Script |
|------|-------|--------|
| Install / verify QScanner and credentials | `skills/setup` | `scripts/install-qscanner.sh` |
| Scan a code repository (SCA + secrets + SBOM) | `skills/code-scan` | `scripts/scan-repo.sh` |
| Scan a container image | `skills/container-scan` | `scripts/scan-image.sh` |
| Summarize results, evaluate pass/fail, remediate | `skills/triage` | `scripts/summarize-sarif.py` |

## Required configuration

Two environment variables drive everything (same contract as the GitHub Actions):

- `QUALYS_ACCESS_TOKEN` — Qualys API access token from the Container Security module. **Secret. Never print, echo, or log it.**
- `QUALYS_POD` — Qualys platform POD: `US1`, `US2`, `US3`, `US4`, `EU1`, `EU2`, `CA1`, `IN1`, `AU1`, `UK1`, `AE1`, `KSA1`. Defaults to `US3`.

If `QUALYS_ACCESS_TOKEN` is not set, run the `setup` skill first and ask the user to provide the token (tell them to set it in their shell or Kiro environment — do not ask them to paste it into chat).

## Typical workflows

- "Scan my code / repo for vulnerabilities" → `setup` (if needed) → `code-scan` → `triage`
- "Scan this image" / "scan my container" → `setup` (if needed) → `container-scan` → `triage`
- "Check for secrets in my code" → `code-scan` with `SCAN_SECRETS=true`
- "Generate an SBOM" → `code-scan` with `GENERATE_SBOM=true` (`SBOM_FORMAT=spdx|cyclonedx|both`)
- "Does this pass our security policy?" → scan with `USE_POLICY_EVALUATION=true` (optionally `POLICY_TAGS=...`)

## Ground rules

1. Never print or persist the access token. Scripts read it from the environment.
2. Scan results land in `.qualys/scans/<timestamp>/` inside the workspace — `*-Report.sarif.json` (findings) and `*-ScanResult.json` (raw). Parse the SARIF, don't dump it raw into chat.
3. Default pass/fail thresholds mirror the GitHub Actions: 0 critical, 0 high, unlimited medium/low. The scan scripts exit non-zero when thresholds are exceeded — that's a finding to report, not an error to debug.
4. QScanner exit codes 40/41 mean "Qualys cloud is still processing the report" — the scripts already retry; if they still fail, tell the user to re-run in a minute or two.
5. Exit code 42 = policy DENY (fail), 43 = policy AUDIT (warn but pass). See `references/exit-codes.md`.
6. After a scan, always give the user the severity breakdown (critical/high/medium/low), the pass/fail verdict and why, and concrete remediation steps for the worst findings.
