# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

BeforeAll {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Get-TestFileSha256 {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        $stream = $null
        $algorithm = $null
        try {
            $stream = [IO.File]::Open(
                $Path,
                [IO.FileMode]::Open,
                [IO.FileAccess]::Read,
                [IO.FileShare]::Read
            )
            $algorithm = [Security.Cryptography.SHA256]::Create()
            return [BitConverter]::ToString(
                $algorithm.ComputeHash($stream)
            ).Replace('-', '')
        }
        finally {
            if ($null -ne $algorithm) {
                $algorithm.Dispose()
            }
            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }

    $script:TestRepositoryRoot = Split-Path -Parent (
        Split-Path -Parent $PSScriptRoot
    )
    $script:TestBuildScript = Join-Path $script:TestRepositoryRoot (
        'build\Build-Release.ps1'
    )
    $script:TestOutputOne = Join-Path $TestDrive 'release-one'
    $script:TestOutputTwo = Join-Path $TestDrive 'release-two'
    $script:TestReleaseOne = & $script:TestBuildScript `
        -OutputDirectory $script:TestOutputOne
    $script:TestReleaseTwo = & $script:TestBuildScript `
        -OutputDirectory $script:TestOutputTwo
}

Describe 'Release package' {
    It 'produces only the expected release assets' {
        @(
            Get-ChildItem -LiteralPath $script:TestOutputOne -File |
                Select-Object -ExpandProperty Name |
                Sort-Object
        ) | Should -Be @(
            "Catalanitzador.Windows-v$($script:TestReleaseOne.Version).zip"
            'Install-Catalanitzador.ps1'
            'SHA256SUMS'
        )
    }

    It 'contains only the expected public files' {
        $archive = [IO.Compression.ZipFile]::OpenRead(
            $script:TestReleaseOne.ArchivePath
        )
        try {
            $root = "Catalanitzador.Windows-v$($script:TestReleaseOne.Version)"
            $entryNames = @(
                $archive.Entries |
                    Select-Object -ExpandProperty FullName |
                    Sort-Object
            )
            $entryNames | Should -Be @(
                "$root/Catalanitzador.Windows/Catalanitzador.Windows.psd1"
                "$root/Catalanitzador.Windows/Catalanitzador.Windows.psm1"
                "$root/Invoke-Catalanitzador.ps1"
                "$root/LICENSE"
                "$root/USAGE.txt"
            )
        }
        finally {
            $archive.Dispose()
        }
    }

    It 'uses deterministic ZIP metadata and content' {
        $script:TestReleaseOne.Sha256 |
            Should -Be $script:TestReleaseTwo.Sha256
        $script:TestReleaseOne.InstallerSha256 |
            Should -Be $script:TestReleaseTwo.InstallerSha256

        $archive = [IO.Compression.ZipFile]::OpenRead(
            $script:TestReleaseOne.ArchivePath
        )
        try {
            foreach ($entry in $archive.Entries) {
                $entry.LastWriteTime.DateTime |
                    Should -Be ([datetime]'2000-01-01T00:00:00')
            }
        }
        finally {
            $archive.Dispose()
        }
    }

    It 'stores files without implementation-dependent compression metadata' {
        $archive = [IO.Compression.ZipFile]::OpenRead(
            $script:TestReleaseOne.ArchivePath
        )
        try {
            foreach ($entry in $archive.Entries) {
                $entry.CompressedLength | Should -Be $entry.Length
                $entry.ExternalAttributes | Should -Be 0
            }
        }
        finally {
            $archive.Dispose()
        }
    }

    It 'writes a matching SHA-256 checksum' {
        $checksumLines = @(
            Get-Content `
            -LiteralPath $script:TestReleaseOne.ChecksumPath `
        )
        $actualHash = Get-TestFileSha256 `
            -Path $script:TestReleaseOne.ArchivePath

        $actualInstallerHash = Get-TestFileSha256 `
            -Path $script:TestReleaseOne.InstallerPath

        $checksumLines | Should -Be @(
            (
                '{0}  {1}' -f
                $actualHash,
                (Split-Path -Leaf $script:TestReleaseOne.ArchivePath)
            )
            (
                '{0}  {1}' -f
                $actualInstallerHash,
                (Split-Path -Leaf $script:TestReleaseOne.InstallerPath)
            )
        )
    }

    It 'generates a fixed-version bootstrap that verifies the ZIP' {
        $installer = Get-Content `
            -LiteralPath $script:TestReleaseOne.InstallerPath `
            -Raw

        $installer | Should -Match (
            [regex]::Escape(
                "`$version = 'v$($script:TestReleaseOne.Version)'"
            )
        )
        $installer | Should -Match (
            [regex]::Escape(
                "`$expectedHash = '$($script:TestReleaseOne.Sha256)'"
            )
        )
        $installer | Should -Match (
            [regex]::Escape(
                'https://github.com/jcorrius/catalanitzador-windows/' +
                "releases/download/v$($script:TestReleaseOne.Version)/" +
                "Catalanitzador.Windows-v$($script:TestReleaseOne.Version).zip"
            )
        )
        $installer | Should -Match 'Test-CatalanitzadorReleaseUri'
        $installer | Should -Match 'AllowAutoRedirect = \$false'
        $installer | Should -Not -Match '__[A-Z0-9_]+__'
        $installer | Should -Not -Match '(?i)\b(Invoke-Expression|iex)\b'
        $installer |
            Should -Not -Match '(?i)/latest/|/main/|raw\.githubusercontent'

        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile(
            $script:TestReleaseOne.InstallerPath,
            [ref]$tokens,
            [ref]$errors
        ) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'keeps the README one-line command pinned to this exact ZIP' {
        $readme = Get-Content `
            -LiteralPath (Join-Path $script:TestRepositoryRoot 'README.md') `
            -Raw
        $commandMatch = [regex]::Match(
            $readme,
            '(?m)^(& \{ \$ErrorActionPreference = ''Stop''; [^\r\n]+\})\r?$'
        )
        $commandMatch.Success | Should -BeTrue
        $command = $commandMatch.Groups[1].Value
        $hashMatch = [regex]::Match(
            $command,
            '\$ExpectedHash = ''([A-F0-9]{64})'''
        )
        $hashMatch.Success | Should -BeTrue
        $hashMatch.Groups[1].Value |
            Should -Be $script:TestReleaseOne.Sha256
        $command | Should -Not -Match '\|\s*(iex|Invoke-Expression)\b'
        $readme | Should -Match (
            [regex]::Escape(
                'iwr -UseBasicParsing https://github.com/' +
                'jcorrius/catalanitzador-windows/releases/download/v0.1.0/' +
                'Install-Catalanitzador.ps1 | iex'
            )
        )
        $readme | Should -Not -Match 'releases/latest'
        $readme | Should -Not -Match 'raw\.githubusercontent\.com'

        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseInput(
            $command,
            [ref]$tokens,
            [ref]$errors
        ) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'contains a valid importable module manifest' {
        $extractPath = Join-Path $TestDrive 'extracted'
        [IO.Compression.ZipFile]::ExtractToDirectory(
            $script:TestReleaseOne.ArchivePath,
            $extractPath
        )
        $manifestPath = Get-ChildItem `
            -LiteralPath $extractPath `
            -Filter Catalanitzador.Windows.psd1 `
            -Recurse |
                Select-Object -ExpandProperty FullName -First 1

        { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
    }

    It 'does not claim Authenticode signing when no certificate is supplied' {
        $script:TestReleaseOne.Signed | Should -BeFalse
    }
}
