# Catalanitzador Windows: English usage

Catalanitzador Windows configures Windows 10 22H2 build 19045 and Windows 11
in Catalan using supported Microsoft language and international-settings
cmdlets.

It installs the official `ca-ES` display package and every user-facing Catalan
language capability published for the current build, places Catalan first in
the current user's language list, preserves all fallback languages and input
methods, and configures supported system and new-user defaults. It makes the
official Catalan input profile available but preserves the current default
keyboard unless one is explicitly requested.

It does not edit the registry, remove languages, change the time zone, modify
other existing users, bypass organizational Windows Update policy, restart, or
sign out automatically.

## Requirements

- Windows 11, recommended, or Windows 10 22H2 build 19045.
- The initiating account must itself belong to the local Administrators group.
- Access to the Windows Update sources permitted by the organization.

Windows 10 22H2 is outside normal Microsoft support. Technical compatibility is
retained for ESU and managed scenarios. Every earlier Windows 10 feature release
is covered in [compatibility.md](compatibility.md), but is rejected because the
complete documented path has not been proven on that build.

## One-line run

The primary [README](../README.md#execució-en-una-sola-ordre) contains the
copy-paste PowerShell command for `v0.1.0`. It embeds the exact release ZIP
SHA-256, downloads to a random directory on disk, verifies before extraction,
optionally verifies the GitHub attestation when `gh` is installed, runs the
local launcher, and cleans up. It never pipes downloaded content to
`Invoke-Expression`.

For a shorter convenience path, an exact immutable release also publishes a
bootstrap:

```powershell
iwr -UseBasicParsing https://github.com/jcorrius/catalanitzador-windows/releases/download/v0.1.0/Install-Catalanitzador.ps1 | iex
```

This executes the bootstrap before independently verifying it. Use it only with
the exact repository, tag, and asset shown above; never substitute `latest`,
`main`, a raw branch, a URL shortener, or a third-party domain. The bootstrap
accepts only GitHub's official release-asset redirect, limits the download size,
and verifies the fixed ZIP hash. The fixed-hash command in the README remains
the recommended option.

## Verified download

Download a specific release ZIP and `SHA256SUMS`, compare the ZIP with
`Get-FileHash -Algorithm SHA256`, and verify its GitHub provenance:

```powershell
gh attestation verify .\Catalanitzador.Windows-v0.1.0.zip `
    --repo jcorrius/catalanitzador-windows
```

Only after verification, extract the ZIP and remove Mark-of-the-Web:

```powershell
Expand-Archive .\Catalanitzador.Windows-v0.1.0.zip .\Catalanitzador
Get-ChildItem .\Catalanitzador -Recurse -File | Unblock-File
```

Outside the exact immutable-release bootstrap above, do not pipe a download to
`Invoke-Expression`, run a mutable branch, disable TLS checks, or permanently
relax the execution policy.

The command-line `-ExecutionPolicy RemoteSigned` setting applies only to that
new PowerShell process. It does not persist and cannot override a stricter
Group Policy.

## Run

Preview:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    .\Catalanitzador\Catalanitzador.Windows-v0.1.0\Invoke-Catalanitzador.ps1 `
    -WhatIf
```

Apply:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    .\Catalanitzador\Catalanitzador.Windows-v0.1.0\Invoke-Catalanitzador.ps1
```

Set Spain as the home location only when explicitly wanted:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    .\Catalanitzador\Catalanitzador.Windows-v0.1.0\Invoke-Catalanitzador.ps1 `
    -HomeLocationGeoId 217
```

Other examples are Andorra `8`, France `84`, and Italy `118`. No country or time
zone is inferred from Catalan.

Select the official Catalan language plus Spanish keyboard profile as the
default only when explicitly wanted:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    .\Catalanitzador\Catalanitzador.Windows-v0.1.0\Invoke-Catalanitzador.ps1 `
    -DefaultInputMethodTip '0403:0000040A'
```

`-Confirm` prompts for each operation. Declining one operation reports it as
skipped and defers any dependent system-copy step rather than reporting a
Windows failure.

An already-compliant machine is a successful read-only no-op: no servicing or
setting cmdlet runs and no log file is created.

Exit codes are `0` for success, `1` for configuration failure, `2` for a
prerequisite/elevation/identity failure, and `3010` for success with a required
restart. A sign-out-only result uses `0`.

See [compatibility.md](compatibility.md),
[security-model.md](security-model.md), and
[troubleshooting.md](troubleshooting.md).
