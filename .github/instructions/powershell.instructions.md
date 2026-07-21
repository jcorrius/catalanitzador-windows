---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
---

# PowerShell source

- Preserve Windows PowerShell 5.1 Desktop compatibility and UTF-8 with BOM.
- Retain the SPDX and Jesús Corrius copyright headers.
- Do not use `Invoke-Expression`, execution-policy bypasses, registry edits,
  undocumented APIs, UI automation, or unofficial language payloads.
- Compare the complete requested state before mutation. Route every change
  through `ShouldProcess`, re-query Microsoft getters, and surface failures.
- Preserve typed Windows language objects and normalize non-enumerated
  collection objects explicitly.
- Add or update Pester coverage for behavior changes and run
  `build\Invoke-Tests.ps1` under Windows PowerShell 5.1.
