# Catalanitzador Windows

This repository is a security-sensitive Windows PowerShell 5.1 project. Follow
the project-wide rules in `AGENTS.md` and the matching files under
`.github/instructions/`.

- Use only documented Microsoft language, international-settings, and Windows
  capability cmdlets. Never add registry edits, UI automation, unofficial
  packages, or TLS bypasses.
- Preserve existing languages, keyboards, geography, time zone, policy, and
  other users. The default keyboard and home location change only when callers
  explicitly request supported values.
- Keep convergence idempotent. A compliant machine must call no mutating
  command and create no log.
- Target native 64-bit Windows PowerShell 5.1. Keep PowerShell source UTF-8 with
  BOM and retain the SPDX and copyright headers.
- Validate changes with
  `powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File .\build\Invoke-Tests.ps1`.
- Treat release and workflow changes as supply-chain security changes. Keep
  actions SHA-pinned, permissions minimal, and release downloads fixed-version
  and verify-before-execution. Pipe-to-execution is allowed only for the
  bootstrap asset of an exact immutable release, never for `main`, `latest`, raw
  branches, URL shorteners, or third-party hosts. Validate GitHub's required
  release-asset redirect explicitly rather than following redirects generally.
