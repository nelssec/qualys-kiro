---
name: triage
description: Interpret QScanner results, evaluate pass/fail, and guide remediation of findings
---

# Triage QScanner Results

Use after `code-scan` or `container-scan` to turn the reports into an actionable answer for the user.

## Inputs

Scan output directory (printed by the scan scripts, default `.qualys/scans/<timestamp>/`):

- `*-Report.sarif.json` — findings with severity, CVE/QID rule IDs, package locations. Primary source.
- `*-ScanResult.json` — raw QScanner result (full package inventory, metadata).
- `*spdx*` / `*cyclonedx*` — SBOMs, if requested.

## Steps

1. **Summarize.** Run:

   ```bash
   python3 scripts/summarize-sarif.py <path-to>/*-Report.sarif.json --top 10
   ```

   Add `--max-critical/--max-high/--max-medium/--max-low` to re-evaluate thresholds (`-1` = unlimited; exit 1 = failed).

2. **Report to the user**, in this order:
   - Verdict: PASSED / FAILED and why (which threshold or policy result).
   - Severity breakdown: critical / high / medium / low / info counts.
   - The worst findings: CVE or rule ID, affected package and installed version, one-line description.

3. **Remediate.** For each critical/high finding, read the SARIF result's message and rule help — it names the vulnerable package, the installed version, and usually the fixed version. Then:
   - **Code scans:** bump the dependency in the manifest (package.json, requirements.txt, go.mod, pom.xml, ...) to the fixed version, respecting semver constraints. Offer to make the edits, then suggest re-running the scan to verify.
   - **Container scans:** prefer updating the base image tag or applying OS package updates in the Dockerfile (`apt-get upgrade <pkg>` pinned, or a newer digest). Many findings vanish with a newer base image.
   - **Secrets findings:** never display the secret value. Name the file/line, tell the user to rotate the credential and purge it from history, and suggest moving it to a secret manager or environment variable.

4. **No fixed version available?** Say so explicitly, and suggest tracking it or ignoring it via policy rather than pretending it's fixable.

## Interpreting exit codes and policy results

See `../../references/exit-codes.md`. Quick rules: 0 = clean pass; 40/41 = report not ready in Qualys cloud (retry later, not a scan failure); 42 = policy DENY (fail); 43 = policy AUDIT (warn, pass); anything else = scanner error, check the log output.
