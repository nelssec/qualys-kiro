# Qualys QScanner Power for Kiro

A [Kiro power](https://kiro.dev/docs/powers/) that scans your code repositories and container images for vulnerabilities, exposed secrets, and generates SBOMs using Qualys QScanner — the same scanner behind the [qualys-code-scan](https://github.com/nelssec/qualys-code-scan) and [qualys-container-scan](https://github.com/nelssec/qualys-container-scan) GitHub Actions and the other Qualys CI/CD integrations.

## Features

- **Code scanning (SCA):** vulnerable open-source dependencies in your repo
- **Container scanning:** OS and package vulnerabilities in local or registry images
- **Secrets detection** in source code and image layers
- **SBOM generation** (SPDX and CycloneDX)
- **Pass/fail gates:** local severity thresholds or centralized Qualys cloud policies
- **AI Compliance and Guardrails ([Qualys TotalAI](https://www.qualys.com/apps/totalai/)):** inventory AI/ML packages, frameworks, and embedded models in your code and images, and gate builds with AI guardrail policies — inventory feeds TotalAI for AI workload risk and compliance reporting
- **Agent-driven remediation:** Kiro reads the SARIF results and fixes the findings

## Installation

1. In Kiro, open the **Powers** panel → **Add Custom Power** → **Import power from GitHub** (or *from a folder*).
2. Point it at this repository.

## Configuration

Set two environment variables (shell profile or Kiro environment settings):

| Variable | Required | Description |
|----------|----------|-------------|
| `QUALYS_ACCESS_TOKEN` | Yes | Qualys API access token (Container Security module) |
| `QUALYS_POD` | No (default `US3`) | US1–US4, EU1, EU2, CA1, IN1, AU1, UK1, AE1, KSA1 |

## Usage

Just ask Kiro:

- *"Scan my code for vulnerabilities with Qualys"*
- *"Run a qscanner scan on this repo including secrets and an SBOM"*
- *"Scan the container image myapp:latest"*
- *"Does this repo pass our Qualys security policy?"*
- *"Inventory the AI/ML packages and models in this project and check them against our AI guardrails"*
- *"Fix the critical findings from the last scan"*

Scan reports land in `.qualys/scans/<timestamp>/` (SARIF + JSON + optional SBOMs). Default gate matches the GitHub Actions: 0 critical, 0 high, unlimited medium/low.

## Layout

```
plugin.json                     Agent Plugins manifest (activation keywords)
POWER.md                        Entry steering for the agent
skills/
  setup/                        Install QScanner + verify credentials
  code-scan/                    Repo scan (SCA, secrets, SBOM)
  container-scan/               Image scan
  triage/                       Summarize, gate, remediate
references/exit-codes.md        QScanner exit codes + POD table
```

## Requirements

- QScanner native binary (auto-installed on linux/amd64; other platforms: Qualys Container Security → Downloads, or Docker fallback)
- Qualys subscription with the Container Security module and API access
- `python3` for report summarization

## License

MIT
