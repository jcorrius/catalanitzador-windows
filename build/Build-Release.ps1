# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory,

    [Parameter()]
    [ValidatePattern('^[A-Fa-f0-9]{40}$')]
    [string]$SigningCertificateThumbprint,

    [Parameter()]
    [ValidatePattern('^https?://')]
    [string]$TimestampServer = 'http://timestamp.digicert.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CatalanitzadorFileSha256 {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
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
        $hashBytes = $algorithm.ComputeHash($stream)
        return [BitConverter]::ToString($hashBytes).Replace('-', '')
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

function Get-CatalanitzadorSigningCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Fa-f0-9]{40}$')]
        [string]$Thumbprint
    )

    $normalizedThumbprint = $Thumbprint.ToUpperInvariant()
    $certificate = @(
        Get-ChildItem -Path @(
            'Cert:\CurrentUser\My'
            'Cert:\LocalMachine\My'
        ) -CodeSigningCert |
            Where-Object {
                $_.Thumbprint.ToUpperInvariant() -eq $normalizedThumbprint
            }
    ) | Select-Object -First 1

    if ($null -eq $certificate) {
        throw "No s'ha trobat el certificat de signatura $normalizedThumbprint."
    }
    if (-not $certificate.HasPrivateKey) {
        throw 'El certificat de signatura no té cap clau privada disponible.'
    }
    if (($certificate.NotBefore -gt (Get-Date)) -or
        ($certificate.NotAfter -le (Get-Date))) {
        throw 'El certificat de signatura no és vigent.'
    }

    return $certificate
}

function Get-CatalanitzadorCrc32 {
    [CmdletBinding()]
    [OutputType([uint32])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes
    )

    [uint32]$crc = [uint32]::MaxValue
    foreach ($byte in $Bytes) {
        $crc = [uint32]($crc -bxor [uint32]$byte)
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = [uint32](
                    ($crc -shr 1) -bxor [uint32]3988292384
                )
            }
            else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }

    return [uint32]($crc -bxor [uint32]::MaxValue)
}

function New-CatalanitzadorStoredZip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ArchivePath,

        [Parameter(Mandatory)]
        [object[]]$Entries,

        [Parameter(Mandatory)]
        [DateTimeOffset]$Timestamp
    )

    if ($Entries.Count -gt [uint16]::MaxValue) {
        throw 'El ZIP conté massa entrades.'
    }

    $date = $Timestamp.UtcDateTime
    if ($date.Year -lt 1980 -or $date.Year -gt 2107) {
        throw 'La data del ZIP no es pot representar en format DOS.'
    }
    [uint16]$dosTime = (
        ($date.Hour -shl 11) -bor
        ($date.Minute -shl 5) -bor
        [math]::Floor($date.Second / 2)
    )
    [uint16]$dosDate = (
        (($date.Year - 1980) -shl 9) -bor
        ($date.Month -shl 5) -bor
        $date.Day
    )
    [uint16]$utf8Flag = 0x0800
    [uint16]$storedMethod = 0
    [uint16]$zipVersion = 20
    $utf8 = New-Object Text.UTF8Encoding($false)
    $records = @()
    $archiveStream = $null
    $writer = $null

    try {
        $archiveStream = [IO.File]::Open(
            $ArchivePath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        $writer = New-Object IO.BinaryWriter -ArgumentList (, $archiveStream)

        foreach ($entry in $Entries) {
            $nameBytes = $utf8.GetBytes([string]$entry.EntryName)
            $content = [IO.File]::ReadAllBytes($entry.File.FullName)
            if ($nameBytes.Length -gt [uint16]::MaxValue) {
                throw "El nom de l'entrada ZIP és massa llarg: $($entry.EntryName)."
            }
            if ($content.LongLength -gt [uint32]::MaxValue) {
                throw "El fitxer és massa gran per al ZIP: $($entry.File.FullName)."
            }

            [uint32]$size = $content.Length
            [uint32]$crc32 = Get-CatalanitzadorCrc32 -Bytes $content
            [uint32]$localHeaderOffset = $archiveStream.Position

            $writer.Write([uint32]0x04034B50)
            $writer.Write($zipVersion)
            $writer.Write($utf8Flag)
            $writer.Write($storedMethod)
            $writer.Write($dosTime)
            $writer.Write($dosDate)
            $writer.Write($crc32)
            $writer.Write($size)
            $writer.Write($size)
            $writer.Write([uint16]$nameBytes.Length)
            $writer.Write([uint16]0)
            $writer.Write($nameBytes)
            $writer.Write($content)

            $records += [pscustomobject]@{
                Crc32 = $crc32
                EntryName = [string]$entry.EntryName
                LocalHeaderOffset = $localHeaderOffset
                NameBytes = $nameBytes
                Size = $size
            }
        }

        [uint32]$centralDirectoryOffset = $archiveStream.Position
        foreach ($record in $records) {
            $writer.Write([uint32]0x02014B50)
            $writer.Write($zipVersion)
            $writer.Write($zipVersion)
            $writer.Write($utf8Flag)
            $writer.Write($storedMethod)
            $writer.Write($dosTime)
            $writer.Write($dosDate)
            $writer.Write([uint32]$record.Crc32)
            $writer.Write([uint32]$record.Size)
            $writer.Write([uint32]$record.Size)
            $writer.Write([uint16]$record.NameBytes.Length)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint32]0)
            $writer.Write([uint32]$record.LocalHeaderOffset)
            $writer.Write([byte[]]$record.NameBytes)
        }
        [uint32]$centralDirectorySize = (
            $archiveStream.Position - $centralDirectoryOffset
        )

        $writer.Write([uint32]0x06054B50)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]$records.Count)
        $writer.Write([uint16]$records.Count)
        $writer.Write($centralDirectorySize)
        $writer.Write($centralDirectoryOffset)
        $writer.Write([uint16]0)
    }
    finally {
        if ($null -ne $writer) {
            $writer.Dispose()
        }
        elseif ($null -ne $archiveStream) {
            $archiveStream.Dispose()
        }
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$moduleManifestPath = Join-Path $repositoryRoot (
    'src\Catalanitzador.Windows\Catalanitzador.Windows.psd1'
)
$module = Test-ModuleManifest -Path $moduleManifestPath
$moduleVersion = $module.Version.ToString()

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $moduleVersion
}
elseif ($Version -ne $moduleVersion) {
    throw (
        "La versió sol·licitada ($Version) no coincideix amb la versió del " +
        "mòdul ($moduleVersion)."
    )
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'dist'
}
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $OutputDirectory
)

$requiredFiles = @(
    'LICENSE'
    'build\Install-Catalanitzador.ps1.in'
    'build\release-usage.ca.txt'
    'src\Invoke-Catalanitzador.ps1'
    'src\Catalanitzador.Windows\Catalanitzador.Windows.psd1'
    'src\Catalanitzador.Windows\Catalanitzador.Windows.psm1'
)
foreach ($relativePath in $requiredFiles) {
    $sourcePath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Falta el fitxer necessari per al paquet: $relativePath."
    }
}

$packageName = "Catalanitzador.Windows-v$Version"
$stagingRoot = Join-Path $OutputDirectory '.staging'
$packageRoot = Join-Path $stagingRoot $packageName
$archivePath = Join-Path $OutputDirectory "$packageName.zip"
$installerPath = Join-Path $OutputDirectory 'Install-Catalanitzador.ps1'
$checksumPath = Join-Path $OutputDirectory 'SHA256SUMS'

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $installerPath) {
    Remove-Item -LiteralPath $installerPath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}

New-Item -ItemType Directory -Path (
    Join-Path $packageRoot 'Catalanitzador.Windows'
) -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE') `
    -Destination (Join-Path $packageRoot 'LICENSE')
Copy-Item -LiteralPath (
    Join-Path $repositoryRoot 'build\release-usage.ca.txt'
) -Destination (Join-Path $packageRoot 'USAGE.txt')
Copy-Item -LiteralPath (
    Join-Path $repositoryRoot 'src\Invoke-Catalanitzador.ps1'
) -Destination (Join-Path $packageRoot 'Invoke-Catalanitzador.ps1')
Copy-Item -LiteralPath $moduleManifestPath -Destination (
    Join-Path $packageRoot 'Catalanitzador.Windows\Catalanitzador.Windows.psd1'
)
Copy-Item -LiteralPath (
    Join-Path $repositoryRoot (
        'src\Catalanitzador.Windows\Catalanitzador.Windows.psm1'
    )
) -Destination (
    Join-Path $packageRoot 'Catalanitzador.Windows\Catalanitzador.Windows.psm1'
)

$signed = $false
$signingCertificate = $null
if (-not [string]::IsNullOrWhiteSpace($SigningCertificateThumbprint)) {
    $signingCertificate = Get-CatalanitzadorSigningCertificate `
        -Thumbprint $SigningCertificateThumbprint
    $signableFiles = @(
        Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
            Where-Object { $_.Extension -in @('.ps1', '.psd1', '.psm1') }
    )

    foreach ($file in $signableFiles) {
        $signature = Set-AuthenticodeSignature `
            -FilePath $file.FullName `
            -Certificate $signingCertificate `
            -HashAlgorithm SHA256 `
            -TimestampServer $TimestampServer
        if ($signature.Status -ne [Management.Automation.SignatureStatus]::Valid) {
            throw (
                "La signatura Authenticode de $($file.Name) no és vàlida: " +
                "$($signature.StatusMessage)"
            )
        }
    }

    $signed = $true
}

$zipEntries = @(
    foreach ($file in @(
            Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
                Sort-Object FullName
        )) {
        $relativePath = $file.FullName.Substring($packageRoot.Length)
        $relativePath = $relativePath.TrimStart('\')
        [pscustomobject]@{
            File = $file
            EntryName = (
                "$packageName\$relativePath"
            ).Replace('\', '/')
        }
    }
)
New-CatalanitzadorStoredZip `
    -ArchivePath $archivePath `
    -Entries $zipEntries `
    -Timestamp ([DateTimeOffset]::Parse('2000-01-01T00:00:00Z'))

$archiveHash = Get-CatalanitzadorFileSha256 -Path $archivePath
$installerTemplatePath = Join-Path $repositoryRoot (
    'build\Install-Catalanitzador.ps1.in'
)
$installerSource = [IO.File]::ReadAllText($installerTemplatePath)
$installerSource = $installerSource.Replace('__VERSION__', "v$Version")
$installerSource = $installerSource.Replace('__ZIP_SHA256__', $archiveHash)
$installerSource = $installerSource.Replace(
    '__ZIP_URI__',
    (
        'https://github.com/jcorrius/catalanitzador-windows/' +
        "releases/download/v$Version/" +
        (Split-Path -Leaf $archivePath)
    )
)
$installerSource = [Text.RegularExpressions.Regex]::Replace(
    $installerSource,
    "\r\n?|\n",
    "`r`n"
)
if ($installerSource -match '__[A-Z0-9_]+__') {
    throw 'L''instal·lador publicable conté un marcador sense substituir.'
}
[IO.File]::WriteAllText(
    $installerPath,
    $installerSource,
    (New-Object Text.UTF8Encoding($true))
)

if ($null -ne $signingCertificate) {
    $installerSignature = Set-AuthenticodeSignature `
        -FilePath $installerPath `
        -Certificate $signingCertificate `
        -HashAlgorithm SHA256 `
        -TimestampServer $TimestampServer
    if ($installerSignature.Status -ne [Management.Automation.SignatureStatus]::Valid) {
        throw (
            "La signatura Authenticode de l'instal·lador no és vàlida: " +
            "$($installerSignature.StatusMessage)"
        )
    }
}

$installerHash = Get-CatalanitzadorFileSha256 -Path $installerPath
$checksumLines = @(
    '{0}  {1}' -f $archiveHash, (Split-Path -Leaf $archivePath)
    '{0}  {1}' -f $installerHash, (Split-Path -Leaf $installerPath)
)
[IO.File]::WriteAllText(
    $checksumPath,
    "$($checksumLines -join "`n")`n",
    [Text.Encoding]::ASCII
)

Remove-Item -LiteralPath $stagingRoot -Recurse -Force

[pscustomobject]@{
    Version = $Version
    ArchivePath = $archivePath
    InstallerPath = $installerPath
    ChecksumPath = $checksumPath
    Sha256 = $archiveHash
    InstallerSha256 = $installerHash
    Signed = $signed
}
