# Security Pipeline

Phase 03 adds a dedicated security workflow alongside the foundational CI workflow:

```text
Pull Request / Push
        │
        ├── ci.yml
        │     ├── Foundation
        │     ├── Quality
        │     ├── Tests
        │     └── Build
        │
        └── security.yml
              ├── SAST (Semgrep)
              ├── Secret Detection (Gitleaks)
              └── Security Gate
```

The two scanner jobs execute independently and produce JSON evidence. The gate runs even when a scanner job fails, then blocks unless both jobs succeeded. A finding and a scanner/tool failure are both blocking, while the scanner wrappers classify them separately as `SECURITY_FAILURE` and `TOOL_FAILURE` in local metadata and output.

The workflow uses `contents: read`, does not use repository secrets, disables checkout credential persistence and retains evidence for 14 days. Gitleaks reports are redacted because secret evidence is sensitive.

The current repository has no application code or package manager, so no dependency installation, linting, testing or build setup is part of this phase. Future security stages will be added progressively without changing this gate’s fail-closed contract.
