#!/usr/bin/env python3
"""Summarize a QScanner SARIF report and optionally evaluate severity thresholds.

Severity mapping matches the qualys-code-scan / qualys-container-scan GitHub Actions:
result.properties.severity -> rule.properties.severity -> SARIF level fallback
(error=5, warning=3, note=2, else 1). Buckets: 5=critical, 4=high, 3=medium,
2=low, else informational.

Exit codes: 0 = pass (or no thresholds given), 1 = thresholds exceeded, 2 = usage/parse error.
"""
import argparse
import json
import sys

LEVEL_FALLBACK = {"error": 5, "warning": 3, "note": 2}


def summarize(report):
    summary = {"total": 0, "critical": 0, "high": 0, "medium": 0, "low": 0, "informational": 0}
    findings = []
    for run in report.get("runs", []):
        rule_severity = {}
        rules = (run.get("tool", {}).get("driver", {}) or {}).get("rules") or []
        rule_meta = {}
        for rule in rules:
            rid = rule.get("id")
            if not rid:
                continue
            rule_meta[rid] = rule
            sev = (rule.get("properties") or {}).get("severity")
            if sev is not None:
                rule_severity[rid] = sev
        for result in run.get("results", []) or []:
            summary["total"] += 1
            sev = (result.get("properties") or {}).get("severity")
            if sev is None:
                sev = rule_severity.get(result.get("ruleId"))
            if sev is None:
                sev = LEVEL_FALLBACK.get(result.get("level"), 1)
            if sev == 5:
                bucket = "critical"
            elif sev == 4:
                bucket = "high"
            elif sev == 3:
                bucket = "medium"
            elif sev == 2:
                bucket = "low"
            else:
                bucket = "informational"
            summary[bucket] += 1
            findings.append({
                "ruleId": result.get("ruleId"),
                "severity": sev,
                "bucket": bucket,
                "message": ((result.get("message") or {}).get("text") or "").split("\n")[0][:200],
            })
    return summary, findings


def main():
    parser = argparse.ArgumentParser(description="Summarize QScanner SARIF report")
    parser.add_argument("sarif", help="Path to *-Report.sarif.json")
    parser.add_argument("--max-critical", type=int, default=None)
    parser.add_argument("--max-high", type=int, default=None)
    parser.add_argument("--max-medium", type=int, default=None)
    parser.add_argument("--max-low", type=int, default=None)
    parser.add_argument("--top", type=int, default=10, help="Show N worst findings (0 to hide)")
    args = parser.parse_args()

    try:
        with open(args.sarif, encoding="utf-8") as fh:
            report = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"ERROR: cannot read SARIF report: {exc}", file=sys.stderr)
        return 2

    summary, findings = summarize(report)

    print("=" * 60)
    print("Scan Results Summary")
    print("=" * 60)
    print(f"Total Vulnerabilities: {summary['total']}")
    print(f"  Critical: {summary['critical']}")
    print(f"  High:     {summary['high']}")
    print(f"  Medium:   {summary['medium']}")
    print(f"  Low:      {summary['low']}")
    print(f"  Info:     {summary['informational']}")
    print("=" * 60)

    if args.top and findings:
        worst = sorted(findings, key=lambda f: -f["severity"])[: args.top]
        print(f"Top {len(worst)} findings:")
        for f in worst:
            print(f"  [{f['bucket']:<13}] {f['ruleId']}: {f['message']}")
        if len(findings) > len(worst):
            print(f"  ... and {len(findings) - len(worst)} more (see SARIF report)")

    thresholds = {
        "critical": args.max_critical,
        "high": args.max_high,
        "medium": args.max_medium,
        "low": args.max_low,
    }
    if all(v is None for v in thresholds.values()):
        return 0

    failures = []
    for bucket, limit in thresholds.items():
        if limit is None or limit < 0:
            continue
        if summary[bucket] > limit:
            failures.append(f"{bucket} count {summary[bucket]} exceeds maximum {limit}")

    print()
    if failures:
        print("Scan FAILED: " + "; ".join(failures))
        return 1
    print("Scan PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
