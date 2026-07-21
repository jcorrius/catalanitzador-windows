---
applyTo: "tests/**/*.ps1"
---

# Pester tests

- Mock every Windows cmdlet that can mutate a host in unit tests.
- Assert both requested effects and forbidden side effects, especially the
  already-compliant and `-WhatIf` paths.
- Cover Windows 10 and Windows 11 normalization differences without weakening
  production checks.
- Keep destructive language installation behind the explicit disposable-VM
  integration opt-in.
