# Repository agent guidance

## Mission and boundaries

- Configure Windows in Catalan only through documented Microsoft interfaces.
- Do not add registry edits, UI automation, undocumented COM calls, unofficial
  language packages, certificate bypasses, or execution-policy bypasses.
- Preserve existing languages, input methods, geography, time zone, enterprise
  update policy, and other users unless an explicit supported parameter says
  otherwise.
- A fully compliant machine must remain a read-only success path: no mutating
  cmdlets, servicing work, or log file.
- Never use mutable branches, `latest`, shortened URLs, or third-party hosts for
  pipe-to-execution. The only documented exception is the bootstrap asset of an
  exact immutable GitHub release; keep the fixed-hash download as the recommended
  path and state the bootstrap trust tradeoff explicitly.

## Runtime and architecture

- The authoritative runtime is native 64-bit Windows PowerShell 5.1 Desktop.
  PowerShell 7 and 32-bit callers are normalized by
  `src/Invoke-Catalanitzador.ps1`.
- `src/Catalanitzador.Windows/Catalanitzador.Windows.psm1` owns platform
  validation, state capture, compliance, and convergence.
- Use `ca-ES` for installation and setting requests. Windows 10 may report
  neutral `ca`; treat `ca` and `ca-ES` as equivalent where Windows normalizes
  the value.
- Windows cmdlets may emit a collection as one non-enumerated object. Normalize
  `IEnumerable` results explicitly before selecting or converting records.
- Keep the default input method unchanged unless
  `-DefaultInputMethodTip` is supplied. Home location is also opt-in; never
  infer a country or time zone from the Catalan language.
- All state changes belong behind the public advanced function's
  `ShouldProcess` boundary and must be verified with Microsoft getter cmdlets.
- Surface partial failures with their original error. Do not turn them into
  warnings or success-shaped fallback results.

## Source conventions

- PowerShell files must remain UTF-8 with BOM, compatible with PowerShell 5.1,
  and start with the repository SPDX and copyright headers.
- Follow `PSScriptAnalyzerSettings.psd1`; avoid unnecessary type assertions and
  dynamic code execution.
- Keep release contents constrained by `build/Build-Release.ps1`. Do not add
  development files, credentials, logs, or local tooling to the ZIP.
- Use Catalan for end-user messages and primary documentation. Keep
  `docs/usage.en.md` as the concise English guide.

## Validation

- Dependencies are pinned in `build/requirements.psd1` and restored under the
  ignored `.psmodules` directory.
- Run the authoritative check with:

  ```powershell
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File .\build\Invoke-Tests.ps1
  ```

- The command parses all PowerShell with 5.1, verifies encoding and headers,
  runs PSScriptAnalyzer, Pester, code coverage, package determinism, and workflow
  security tests.
- Integration tests are destructive. Run them only inside an explicitly
  disposable elevated Windows client VM with
  `CATALANITZADOR_DISPOSABLE_VM=1`.

## CI and release security

- Pin every GitHub Action to a full commit SHA and retain the release tag in a
  comment.
- Keep default workflow permissions read-only. Grant write, OIDC, or
  attestation permissions only to the exact job that needs them.
- Do not use `pull_request_target`, privileged processing of untrusted
  artifacts, or direct event-payload interpolation in shell scripts.
- Releases must come from exact semantic-version tags, rebuild and retest the
  tagged commit, publish SHA-256 sums, and create GitHub attestations.
- Never commit secrets, signing keys, PFX files, VM credentials, real-machine
  logs, or generated release artifacts.
