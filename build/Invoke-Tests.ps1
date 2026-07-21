# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

#Requires -Version 5.1
#Requires -PSEdition Desktop

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Integration
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requirementsPath = Join-Path $PSScriptRoot 'requirements.psd1'
$requirements = $null
Import-LocalizedData `
    -BindingVariable requirements `
    -BaseDirectory $PSScriptRoot `
    -FileName (Split-Path -Leaf $requirementsPath)
$localModulePath = Join-Path $repositoryRoot '.psmodules'
$env:PSModulePath = "$localModulePath;$env:PSModulePath"

foreach ($moduleName in @('Pester', 'PSScriptAnalyzer')) {
    $requiredVersion = [version]$requirements[$moduleName]
    $availableModule = Get-Module `
        -Name $moduleName `
        -ListAvailable |
            Where-Object { $_.Version -eq $requiredVersion } |
            Select-Object -First 1
    if ($null -eq $availableModule) {
        throw (
            "Falta $moduleName $requiredVersion. Deseu les dependències " +
            "fixades a $localModulePath abans d'executar les proves."
        )
    }

    Import-Module `
        -Name $availableModule.Path `
        -RequiredVersion $requiredVersion `
        -Force
}

$powerShellFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'src') `
        -Recurse `
        -File |
            Where-Object { $_.Extension -in @('.ps1', '.psd1', '.psm1') }
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'build') `
        -Recurse `
        -File |
            Where-Object { $_.Extension -in @('.ps1', '.psd1', '.psm1') }
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'tests') `
        -Recurse `
        -File |
            Where-Object { $_.Extension -in @('.ps1', '.psd1', '.psm1') }
    Get-Item -LiteralPath (
        Join-Path $repositoryRoot 'PSScriptAnalyzerSettings.psd1'
    )
)

$parserErrors = @()
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    $parserErrors += @($errors)

    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $hasUtf8Bom = (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    )
    if (-not $hasUtf8Bom) {
        throw "El fitxer PowerShell no és UTF-8 amb BOM: $($file.FullName)."
    }

    $source = [IO.File]::ReadAllText($file.FullName)
    if ($source -notmatch '(?m)^# SPDX-License-Identifier: MIT\r?$') {
        throw "Falta la capçalera SPDX a $($file.FullName)."
    }
    if ($source -notmatch (
            '(?m)^# Copyright \(c\) 2026 Jesús Corrius ' +
            '<jesus@softcatala\.org>\r?$'
        )) {
        throw "Falta la capçalera de copyright a $($file.FullName)."
    }
}

if ($parserErrors.Count -gt 0) {
    $parserMessage = @(
        $parserErrors |
            ForEach-Object {
                '{0}:{1}:{2}: {3}' -f
                $_.Extent.File,
                $_.Extent.StartLineNumber,
                $_.Extent.StartColumnNumber,
                $_.Message
            }
    ) -join [Environment]::NewLine
    throw "S'han trobat errors de sintaxi:`n$parserMessage"
}

$manifestPath = Join-Path $repositoryRoot (
    'src\Catalanitzador.Windows\Catalanitzador.Windows.psd1'
)
Test-ModuleManifest -Path $manifestPath | Out-Null

$analyzerSettings = Join-Path $repositoryRoot 'PSScriptAnalyzerSettings.psd1'
$analyzerFindings = @(
    foreach ($file in $powerShellFiles) {
        Invoke-ScriptAnalyzer `
            -Path $file.FullName `
            -Settings $analyzerSettings
    }
)
if ($analyzerFindings.Count -gt 0) {
    $analyzerMessage = @(
        $analyzerFindings |
            ForEach-Object {
                '{0}:{1}: [{2}] {3}' -f
                $_.ScriptPath,
                $_.Line,
                $_.RuleName,
                $_.Message
            }
    ) -join [Environment]::NewLine
    throw "PSScriptAnalyzer ha trobat incidències:`n$analyzerMessage"
}

$testResultsDirectory = Join-Path $repositoryRoot 'TestResults'
if (Test-Path -LiteralPath $testResultsDirectory) {
    Remove-Item -LiteralPath $testResultsDirectory -Recurse -Force
}
New-Item `
    -ItemType Directory `
    -Path $testResultsDirectory `
    -Force |
        Out-Null

$testPaths = @(
    Join-Path $repositoryRoot 'tests\Unit'
)
if ($Integration) {
    if ($env:CATALANITZADOR_DISPOSABLE_VM -ne '1') {
        throw (
            'Les proves d''integració només es poden executar quan ' +
            'CATALANITZADOR_DISPOSABLE_VM=1.'
        )
    }

    $env:CATALANITZADOR_RUN_INTEGRATION = '1'
    $testPaths += Join-Path $repositoryRoot 'tests\Integration'
}

$configuration = New-PesterConfiguration
$configuration.Run.Path = $testPaths
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = Join-Path (
    $testResultsDirectory
) 'pester-results.xml'
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = @(
    Join-Path $repositoryRoot (
        'src\Catalanitzador.Windows\Catalanitzador.Windows.psm1'
    )
)
$configuration.CodeCoverage.OutputFormat = 'JaCoCo'
$configuration.CodeCoverage.OutputPath = Join-Path (
    $testResultsDirectory
) 'coverage.xml'

$testResult = Invoke-Pester -Configuration $configuration
if (
    $testResult.FailedCount -gt 0 -or
    $testResult.FailedContainersCount -gt 0 -or
    $testResult.FailedBlocksCount -gt 0
) {
    throw (
        "Han fallat $($testResult.FailedCount) proves, " +
        "$($testResult.FailedBlocksCount) blocs i " +
        "$($testResult.FailedContainersCount) contenidors."
    )
}

[pscustomobject]@{
    TestsPassed = $testResult.PassedCount
    TestsSkipped = $testResult.SkippedCount
    AnalyzerFindings = $analyzerFindings.Count
    TestResultsPath = $configuration.TestResult.OutputPath.Value
    CoveragePath = $configuration.CodeCoverage.OutputPath.Value
}
