# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:TestEntrypointPath = Join-Path $repositoryRoot (
        'src\Invoke-Catalanitzador.ps1'
    )
    $script:TestEntrypointSource = Get-Content `
        -LiteralPath $script:TestEntrypointPath `
        -Raw
}

Describe 'Invoke-Catalanitzador entrypoint' {
    It 'does not use dynamic code execution or execution-policy bypasses' {
        $script:TestEntrypointSource |
            Should -Not -Match '\bInvoke-Expression\b'
        $script:TestEntrypointSource |
            Should -Not -Match '(?i)-ExecutionPolicy\s+Bypass'
        $script:TestEntrypointSource | Should -Not -Match '(?i)\biex\b'
    }

    It 'uses encoded parameters and a create-new result relay' {
        $script:TestEntrypointSource | Should -Match 'ToBase64String'
        $script:TestEntrypointSource | Should -Match 'FromBase64String'
        $script:TestEntrypointSource | Should -Match 'FileMode\]::CreateNew'
        $script:TestEntrypointSource | Should -Not -Match 'Export-Clixml'
        $script:TestEntrypointSource | Should -Not -Match 'Import-Clixml'
    }

    It 'allows host normalization and UAC while configuration WhatIf is active' {
        $script:TestEntrypointSource |
            Should -Match '\$previousWhatIfPreference = \$WhatIfPreference'
        $script:TestEntrypointSource |
            Should -Match '\$WhatIfPreference = \$false'
        $script:TestEntrypointSource |
            Should -Match '\$WhatIfPreference = \$previousWhatIfPreference'
    }

    It 'uses the relayed exit code after every child process hop' {
        [regex]::Matches(
            $script:TestEntrypointSource,
            '\$exitCode\s*=\s*\[int\]\$relay\.ExitCode'
        ).Count | Should -Be 2
    }

    It 'does not hide a pending Windows 11 system copy as a no-op' {
        $script:TestEntrypointSource | Should -Match (
            '(?s)\$preflightCompliance\.IsCompliant\s+-and\s+' +
            '-not\s+\$preflightCompliance\.PendingSystemCopy'
        )
    }

    It 'rejects a mismatched initiating SID before elevation or mutation' {
        $payload = [pscustomobject]@{
            SchemaVersion = 3
            InitiatingSid = 'S-1-5-18'
            HomeLocationGeoId = $null
            DefaultInputMethodTip = $null
            LogPath = $null
            WhatIf = $true
            ConfirmBound = $false
            Confirm = $false
            VerboseBound = $false
            Verbose = $false
            PassThru = $false
            NativeHostRequested = $true
            ElevationRequested = $true
            RelayPath = $null
            RelayNonce = $null
        }
        $payloadText = $payload | ConvertTo-Json -Compress
        $encodedPayload = [Convert]::ToBase64String(
            [Text.Encoding]::UTF8.GetBytes($payloadText)
        )
        $powerShellPath = Join-Path $env:WINDIR (
            'System32\WindowsPowerShell\v1.0\powershell.exe'
        )

        $process = Start-Process `
            -FilePath $powerShellPath `
            -ArgumentList @(
                '-NoLogo'
                '-NoProfile'
                '-ExecutionPolicy'
                'RemoteSigned'
                '-File'
                "`"$script:TestEntrypointPath`""
                '-RelaunchPayload'
                $encodedPayload
            ) `
            -WindowStyle Hidden `
            -Wait `
            -PassThru

        $process.ExitCode | Should -Be 2
    }
}
