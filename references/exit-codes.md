# QScanner Exit Codes

| Code | Meaning | How to handle |
|------|---------|---------------|
| 0 | Success (policy ALLOW when in evaluate-policy mode) | Pass |
| 1 | Generic error | Check scanner log output |
| 2 | Invalid parameter | Fix the command arguments |
| 3 | Logger init failed | Check output dir permissions |
| 5 | Filesystem artifact failed | Verify scan path exists/readable |
| 6 | Image artifact failed | Verify image exists locally or is pullable |
| 7 | Image archive artifact failed | Verify archive path |
| 8 | Image storage driver artifact failed | Check `--storage-driver` value and host storage access |
| 9 | Container artifact failed | Verify container exists |
| 10 | Other artifact failed | Check scanner log |
| 11 | Metadata scan failed | Check scanner log |
| 12 | OS scan failed | Check scanner log |
| 13 | SCA scan failed | Check scanner log |
| 14 | Secret scan failed | Check scanner log |
| 15 | OS not found | Image has no detectable OS (e.g. scratch/distroless) — SCA results may still be valid |
| 16 | Malware scan failed | Check scanner log |
| 17 | OS not supported | Vulnerability data unavailable for this OS |
| 18 | File insight scan failed | Check scanner log |
| 19 | Compliance scan failed | Check scanner log |
| 20 | Manifest scan failed | Check scanner log |
| 21 | Windows registry scan failed | Check scanner log |
| 30 | JSON result handler failed | Check output dir |
| 31–33 | Changelist creation/compression/upload failed | Network/auth issue with Qualys cloud |
| 34–37 | SBOM (SPDX/CDX) handling or upload failed | Check output dir / network |
| 38–39 | Secret result creation/upload failed | Check output dir / network |
| 40 | Failed to get vulnerability report | Qualys cloud still processing — retry after ~60s (scan scripts do this automatically) |
| 41 | Failed to get policy evaluation result | Same as 40, for evaluate-policy mode |
| 42 | Policy evaluation: DENY | Treat as scan FAILED |
| 43 | Policy evaluation: AUDIT | Warn, but treat as passed |

# Qualys Platform PODs

Valid values for `QUALYS_POD`:

| POD | Region |
|-----|--------|
| US1–US4 | United States |
| EU1, EU2 | Europe |
| CA1 | Canada |
| IN1 | India |
| AU1 | Australia |
| UK1 | United Kingdom |
| AE1 | UAE |
| KSA1 | Saudi Arabia |
