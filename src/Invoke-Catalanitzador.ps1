# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateRange(2, [int]::MaxValue)]
    [Nullable[int]]$HomeLocationGeoId,

    [Parameter()]
    [ValidatePattern('^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{8}$')]
    [string]$DefaultInputMethodTip,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RelaunchPayload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AdministratorSid = 'S-1-5-32-544'
$script:ExitCodeError = 1
$script:ExitCodePrerequisite = 2
$script:ExitCodeRestartRequired = 3010

function Get-CatalanitzadorCurrentSid {
    [CmdletBinding()]
    param()

    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Test-CatalanitzadorElevated {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Test-CatalanitzadorAdministratorMember {
    [CmdletBinding()]
    param()

    $whoAmIPath = Join-Path $env:WINDIR 'System32\whoami.exe'
    $groupLines = @(& $whoAmIPath /groups /fo csv /nh)
    if ($LASTEXITCODE -ne 0) {
        throw "No s'ha pogut determinar la pertinença al grup d'administradors."
    }

    $groups = @(
        $groupLines |
            ConvertFrom-Csv -Header @('Name', 'Type', 'Sid', 'Attributes')
    )

    return [bool](
        $groups |
            Where-Object { $_.Sid -eq $script:AdministratorSid } |
            Select-Object -First 1
    )
}

function Get-CatalanitzadorNativeWindowsPowerShell {
    [CmdletBinding()]
    param()

    $systemDirectory = if (
        [Environment]::Is64BitOperatingSystem -and
        -not [Environment]::Is64BitProcess
    ) {
        'Sysnative'
    }
    else {
        'System32'
    }

    $powerShellPath = Join-Path $env:WINDIR (
        "$systemDirectory\WindowsPowerShell\v1.0\powershell.exe"
    )
    if (-not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) {
        throw "No s'ha trobat el Windows PowerShell natiu a $powerShellPath."
    }

    return $powerShellPath
}

function Test-CatalanitzadorNativeHost {
    [CmdletBinding()]
    param()

    $isDesktopEdition = (
        -not $PSVersionTable.ContainsKey('PSEdition') -or
        $PSVersionTable.PSEdition -eq 'Desktop'
    )
    $isNativeArchitecture = (
        -not [Environment]::Is64BitOperatingSystem -or
        [Environment]::Is64BitProcess
    )

    return ($isDesktopEdition -and $isNativeArchitecture)
}

function Start-CatalanitzadorProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter()]
        [switch]$Elevated
    )

    $previousWhatIfPreference = $WhatIfPreference
    try {
        $WhatIfPreference = $false
        if ($Elevated) {
            return Start-Process `
                -FilePath $FilePath `
                -ArgumentList $ArgumentList `
                -Verb RunAs `
                -Wait `
                -PassThru
        }

        return Start-Process `
            -FilePath $FilePath `
            -ArgumentList $ArgumentList `
            -NoNewWindow `
            -Wait `
            -PassThru
    }
    finally {
        $WhatIfPreference = $previousWhatIfPreference
    }
}

function ConvertTo-CatalanitzadorPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Value
    )

    $json = $Value | ConvertTo-Json -Compress
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
}

function ConvertFrom-CatalanitzadorPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    try {
        $json = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($Value)
        )
        $payload = $json | ConvertFrom-Json
    }
    catch {
        throw 'Les dades internes de rellançament no són vàlides.'
    }

    $schemaVersionProperty = if ($null -eq $payload) {
        $null
    }
    else {
        $payload.PSObject.Properties['SchemaVersion']
    }
    if (
        ($null -eq $schemaVersionProperty) -or
        ($schemaVersionProperty.Value -ne 3)
    ) {
        throw 'La versió de les dades internes de rellançament no és compatible.'
    }

    return $payload
}

function ConvertTo-CatalanitzadorEncodedCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Payload
    )

    $escapedScriptPath = $PSCommandPath.Replace("'", "''")
    $command = (
        "`$ProgressPreference = 'SilentlyContinue'; " +
        "& '$escapedScriptPath' -RelaunchPayload '$Payload'; " +
        'exit $LASTEXITCODE'
    )
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
}

function New-CatalanitzadorRelaunchPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InitiatingSid,

        [Parameter()]
        [AllowNull()]
        [object]$HomeLocation,

        [Parameter()]
        [AllowNull()]
        [string]$DefaultInputMethod,

        [Parameter()]
        [AllowNull()]
        [string]$RequestedLogPath,

        [Parameter(Mandatory)]
        [bool]$WhatIfRequested,

        [Parameter(Mandatory)]
        [bool]$ConfirmBound,

        [Parameter(Mandatory)]
        [bool]$ConfirmRequested,

        [Parameter(Mandatory)]
        [bool]$VerboseBound,

        [Parameter(Mandatory)]
        [bool]$VerboseRequested,

        [Parameter(Mandatory)]
        [bool]$PassThruRequested,

        [Parameter(Mandatory)]
        [bool]$NativeHostRequested,

        [Parameter(Mandatory)]
        [bool]$ElevationRequested,

        [Parameter()]
        [AllowNull()]
        [string]$RelayPath,

        [Parameter()]
        [AllowNull()]
        [string]$RelayNonce
    )

    [pscustomobject]@{
        SchemaVersion = 3
        InitiatingSid = $InitiatingSid
        HomeLocationGeoId = $HomeLocation
        DefaultInputMethodTip = $DefaultInputMethod
        LogPath = $RequestedLogPath
        WhatIf = $WhatIfRequested
        ConfirmBound = $ConfirmBound
        Confirm = $ConfirmRequested
        VerboseBound = $VerboseBound
        Verbose = $VerboseRequested
        PassThru = $PassThruRequested
        NativeHostRequested = $NativeHostRequested
        ElevationRequested = $ElevationRequested
        RelayPath = $RelayPath
        RelayNonce = $RelayNonce
    }
}

function New-CatalanitzadorRelayPath {
    [CmdletBinding()]
    param()

    $fileName = 'Catalanitzador-Relay-{0}.clixml' -f (
        [guid]::NewGuid().ToString('N')
    )
    return Join-Path ([IO.Path]::GetTempPath()) $fileName
}

function Test-CatalanitzadorRelayPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $tempRoot = [IO.Path]::GetFullPath(
        [IO.Path]::GetTempPath()
    ).TrimEnd('\') + '\'
    $isInTemp = $fullPath.StartsWith(
        $tempRoot,
        [StringComparison]::OrdinalIgnoreCase
    )
    $hasExpectedName = (
        [IO.Path]::GetFileName($fullPath) -match
        '^Catalanitzador-Relay-[a-f0-9]{32}\.clixml$'
    )

    return ($isInTemp -and $hasExpectedName)
}

function Write-CatalanitzadorRelay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    if (-not (Test-CatalanitzadorRelayPath -Path $Path)) {
        throw 'El camí intern de retorn no és vàlid.'
    }

    $serialized = [Management.Automation.PSSerializer]::Serialize($Value, 12)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($serialized)
    $stream = $null
    try {
        $stream = [IO.File]::Open(
            $Path,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Read-CatalanitzadorRelay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-CatalanitzadorRelayPath -Path $Path)) {
        throw 'El camí intern de retorn no és vàlid.'
    }

    $serialized = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    return [Management.Automation.PSSerializer]::Deserialize($serialized)
}

function Receive-CatalanitzadorRelay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{32}$')]
        [string]$Nonce,

        [Parameter(Mandatory)]
        [int]$ProcessExitCode
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'El procés rellançat no ha retornat cap resultat.'
    }

    try {
        $relay = Read-CatalanitzadorRelay -Path $Path
    }
    finally {
        [IO.File]::Delete($Path)
    }

    if (($relay.SchemaVersion -ne 1) -or
        ([string]$relay.Nonce -cne $Nonce)) {
        throw 'El resultat retornat pel procés rellançat no és vàlid.'
    }
    if ([int]$relay.ExitCode -ne $ProcessExitCode) {
        throw 'El codi del procés rellançat no coincideix amb el resultat.'
    }

    return $relay
}

function Get-CatalanitzadorDefaultLogPath {
    [CmdletBinding()]
    param()

    $logDirectory = Join-Path $env:LOCALAPPDATA 'Catalanitzador.Windows\Logs'
    $logName = 'Catalanitzador-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
    return Join-Path $logDirectory $logName
}

function Initialize-CatalanitzadorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) {
        throw "El camí del registre ha d'incloure un directori."
    }

    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $header = '{0:o} [INFO] Inici del Catalanitzador Windows.' -f (Get-Date)
    $header | Out-File -LiteralPath $Path -Encoding utf8 -Append
}

function Write-CatalanitzadorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    $line = '{0:o} [{1}] {2}' -f (Get-Date), $Level, $Message
    $line | Out-File -LiteralPath $Path -Encoding utf8 -Append
}

function Test-CatalanitzadorFileInvocation {
    [CmdletBinding()]
    param()

    $arguments = [Environment]::GetCommandLineArgs()
    $currentScriptPath = [IO.Path]::GetFullPath($PSCommandPath)
    for ($index = 0; $index -lt ($arguments.Count - 1); $index++) {
        if ($arguments[$index] -in @('-File', '-f')) {
            try {
                $fileArgumentPath = [IO.Path]::GetFullPath($arguments[$index + 1])
                return $fileArgumentPath -ieq $currentScriptPath
            }
            catch {
                return $false
            }
        }
    }

    return $false
}

function Show-CatalanitzadorResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter()]
        [AllowNull()]
        [string]$EffectiveLogPath
    )

    Write-Host $Result.Message

    foreach ($change in @($Result.Changes)) {
        Write-Host "  Canvi: $change"
    }

    foreach ($plannedChange in @($Result.PlannedChanges)) {
        Write-Host "  Canvi previst: $plannedChange"
    }

    foreach ($warning in @($Result.Warnings)) {
        Write-Warning $warning
    }

    if ($Result.RestartRequired) {
        Write-Host 'Cal reiniciar Windows per completar tots els canvis.'
    }
    elseif ($Result.SignOutRequired) {
        Write-Host 'Cal tancar la sessió i tornar-la a iniciar per completar els canvis.'
    }

    if (-not [string]::IsNullOrWhiteSpace($EffectiveLogPath)) {
        Write-Host "Registre local: $EffectiveLogPath"
    }
}

$isRelaunched = -not [string]::IsNullOrWhiteSpace($RelaunchPayload)
$exitCode = 0
$result = $null
$effectiveLogPath = $null
$logInitialized = $false
$errorMessage = $null
$effectiveRelayPath = $null
$effectiveRelayNonce = $null
$relayPathToRemove = $null
$writeRelayOnExit = $false
$failureExitCode = $script:ExitCodeError

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        $failureExitCode = $script:ExitCodePrerequisite
        throw 'Aquest projecte només es pot executar a Windows.'
    }

    if ($isRelaunched) {
        $payload = ConvertFrom-CatalanitzadorPayload -Value $RelaunchPayload
        $initiatingSid = [string]$payload.InitiatingSid
        $effectiveHomeLocation = if ($null -eq $payload.HomeLocationGeoId) {
            $null
        }
        else {
            [Nullable[int]]([int]$payload.HomeLocationGeoId)
        }
        $effectiveDefaultInputMethod = [string]$payload.DefaultInputMethodTip
        $effectiveLogPath = [string]$payload.LogPath
        $effectiveWhatIf = [bool]$payload.WhatIf
        $effectiveConfirmBound = [bool]$payload.ConfirmBound
        $effectiveConfirm = [bool]$payload.Confirm
        $effectiveVerboseBound = [bool]$payload.VerboseBound
        $effectiveVerbose = [bool]$payload.Verbose
        $effectivePassThru = [bool]$payload.PassThru
        $nativeHostRequested = [bool]$payload.NativeHostRequested
        $elevationRequested = [bool]$payload.ElevationRequested
        $effectiveRelayPath = [string]$payload.RelayPath
        $effectiveRelayNonce = [string]$payload.RelayNonce
        if (-not [string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
            if (-not (Test-CatalanitzadorRelayPath -Path $effectiveRelayPath) -or
                $effectiveRelayNonce -notmatch '^[a-f0-9]{32}$') {
                throw 'Les dades internes de retorn no són vàlides.'
            }
            $writeRelayOnExit = $true
        }
    }
    else {
        $initiatingSid = Get-CatalanitzadorCurrentSid
        $effectiveHomeLocation = $HomeLocationGeoId
        $effectiveDefaultInputMethod = $DefaultInputMethodTip
        $effectiveLogPath = $LogPath
        $effectiveWhatIf = [bool]$WhatIfPreference
        $effectiveConfirmBound = $PSBoundParameters.ContainsKey('Confirm')
        $effectiveConfirm = if ($effectiveConfirmBound) {
            [bool]$PSBoundParameters['Confirm']
        }
        else {
            $false
        }
        $effectiveVerboseBound = $PSBoundParameters.ContainsKey('Verbose')
        $effectiveVerbose = if ($effectiveVerboseBound) {
            [bool]$PSBoundParameters['Verbose']
        }
        else {
            $false
        }
        $effectivePassThru = [bool]$PassThru
        $nativeHostRequested = $false
        $elevationRequested = $false
        $effectiveRelayPath = $null
        $effectiveRelayNonce = $null
    }

    $currentSid = Get-CatalanitzadorCurrentSid
    if ($currentSid -ne $initiatingSid) {
        $failureExitCode = $script:ExitCodePrerequisite
        throw (
            'La identitat elevada no coincideix amb el compte que ha iniciat ' +
            'el Catalanitzador. No s''ha aplicat cap canvi.'
        )
    }

    if (-not (Test-CatalanitzadorNativeHost)) {
        if ($nativeHostRequested) {
            $failureExitCode = $script:ExitCodePrerequisite
            throw 'No s''ha pogut iniciar el Windows PowerShell natiu de 64 bits.'
        }

        $ownsRelay = $false
        if ([string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
            $effectiveRelayPath = New-CatalanitzadorRelayPath
            $effectiveRelayNonce = [guid]::NewGuid().ToString('N')
            $relayPathToRemove = $effectiveRelayPath
            $ownsRelay = $true
        }
        $writeRelayOnExit = $false

        $nativePayload = New-CatalanitzadorRelaunchPayload `
            -InitiatingSid $initiatingSid `
            -HomeLocation $effectiveHomeLocation `
            -DefaultInputMethod $effectiveDefaultInputMethod `
            -RequestedLogPath $effectiveLogPath `
            -WhatIfRequested $effectiveWhatIf `
            -ConfirmBound $effectiveConfirmBound `
            -ConfirmRequested $effectiveConfirm `
            -VerboseBound $effectiveVerboseBound `
            -VerboseRequested $effectiveVerbose `
            -PassThruRequested $effectivePassThru `
            -NativeHostRequested $true `
            -ElevationRequested $elevationRequested `
            -RelayPath $effectiveRelayPath `
            -RelayNonce $effectiveRelayNonce
        $encodedPayload = ConvertTo-CatalanitzadorPayload -Value $nativePayload
        $encodedCommand = ConvertTo-CatalanitzadorEncodedCommand `
            -Payload $encodedPayload
        $nativePowerShell = Get-CatalanitzadorNativeWindowsPowerShell

        try {
            $nativeProcess = Start-CatalanitzadorProcess `
                -FilePath $nativePowerShell `
                -ArgumentList @(
                    '-NoLogo'
                    '-NoProfile'
                    '-ExecutionPolicy'
                    'RemoteSigned'
                    '-EncodedCommand'
                    $encodedCommand
                )
        }
        catch {
            if ($ownsRelay) {
                $effectiveRelayPath = $null
            }
            else {
                $writeRelayOnExit = $true
            }
            throw
        }
        $exitCode = $nativeProcess.ExitCode
        if ($ownsRelay) {
            try {
                $relay = Receive-CatalanitzadorRelay `
                    -Path $effectiveRelayPath `
                    -Nonce $effectiveRelayNonce `
                    -ProcessExitCode $nativeProcess.ExitCode
                $relayPathToRemove = $null
            }
            catch {
                $effectiveRelayPath = $null
                throw
            }

            $exitCode = [int]$relay.ExitCode
            if (-not [bool]$relay.Success) {
                $effectiveRelayPath = $null
                $failureExitCode = $exitCode
                throw [string]$relay.ErrorMessage
            }

            $result = $relay.Result
            Show-CatalanitzadorResult `
                -Result $result `
                -EffectiveLogPath ([string]$relay.LogPath)
            if ($effectivePassThru) {
                Write-Output $result
            }
            $effectiveRelayPath = $null
        }
    }
    else {
        if (-not (Test-CatalanitzadorAdministratorMember)) {
            $failureExitCode = $script:ExitCodePrerequisite
            throw (
                'El compte que executa el Catalanitzador ha de ser membre del ' +
                'grup local Administradors.'
            )
        }

        if (-not (Test-CatalanitzadorElevated)) {
            if ($elevationRequested) {
                $failureExitCode = $script:ExitCodePrerequisite
                throw 'Windows no ha concedit un testimoni d''administrador elevat.'
            }

            $ownsRelay = $false
            if ([string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
                $effectiveRelayPath = New-CatalanitzadorRelayPath
                $effectiveRelayNonce = [guid]::NewGuid().ToString('N')
                $relayPathToRemove = $effectiveRelayPath
                $ownsRelay = $true
            }
            $writeRelayOnExit = $false
            $elevatedPayload = New-CatalanitzadorRelaunchPayload `
                -InitiatingSid $initiatingSid `
                -HomeLocation $effectiveHomeLocation `
                -DefaultInputMethod $effectiveDefaultInputMethod `
                -RequestedLogPath $effectiveLogPath `
                -WhatIfRequested $effectiveWhatIf `
                -ConfirmBound $effectiveConfirmBound `
                -ConfirmRequested $effectiveConfirm `
                -VerboseBound $effectiveVerboseBound `
                -VerboseRequested $effectiveVerbose `
                -PassThruRequested $effectivePassThru `
                -NativeHostRequested $true `
                -ElevationRequested $true `
                -RelayPath $effectiveRelayPath `
                -RelayNonce $effectiveRelayNonce
            $encodedPayload = ConvertTo-CatalanitzadorPayload -Value $elevatedPayload
            $encodedCommand = ConvertTo-CatalanitzadorEncodedCommand `
                -Payload $encodedPayload
            $nativePowerShell = Get-CatalanitzadorNativeWindowsPowerShell

            try {
                $elevatedProcess = Start-CatalanitzadorProcess `
                    -FilePath $nativePowerShell `
                    -ArgumentList @(
                        '-NoLogo'
                        '-NoProfile'
                        '-ExecutionPolicy'
                        'RemoteSigned'
                        '-EncodedCommand'
                        $encodedCommand
                    ) `
                    -Elevated
                $exitCode = $elevatedProcess.ExitCode
                if ($ownsRelay) {
                    try {
                        $relay = Receive-CatalanitzadorRelay `
                            -Path $effectiveRelayPath `
                            -Nonce $effectiveRelayNonce `
                            -ProcessExitCode $elevatedProcess.ExitCode
                        $relayPathToRemove = $null
                    }
                    catch {
                        $effectiveRelayPath = $null
                        throw
                    }

                    $exitCode = [int]$relay.ExitCode
                    if (-not [bool]$relay.Success) {
                        $effectiveRelayPath = $null
                        $failureExitCode = $exitCode
                        throw [string]$relay.ErrorMessage
                    }

                    $result = $relay.Result
                    Show-CatalanitzadorResult `
                        -Result $result `
                        -EffectiveLogPath ([string]$relay.LogPath)
                    if ($effectivePassThru) {
                        Write-Output $result
                    }
                    $effectiveRelayPath = $null
                }
            }
            catch [System.ComponentModel.Win32Exception] {
                if ($ownsRelay) {
                    $effectiveRelayPath = $null
                }
                else {
                    $writeRelayOnExit = $true
                }
                if ($_.Exception.NativeErrorCode -eq 1223) {
                    $failureExitCode = $script:ExitCodePrerequisite
                    throw 'S''ha cancel·lat la sol·licitud d''elevació de Windows.'
                }

                throw
            }
            catch {
                if ($ownsRelay) {
                    $effectiveRelayPath = $null
                }
                else {
                    $writeRelayOnExit = $true
                }
                throw
            }
        }
        else {
            $writeRelayOnExit = (
                -not [string]::IsNullOrWhiteSpace($effectiveRelayPath)
            )
            if ([string]::IsNullOrWhiteSpace($effectiveLogPath)) {
                $effectiveLogPath = Get-CatalanitzadorDefaultLogPath
            }
            else {
                $effectiveLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                    $effectiveLogPath
                )
            }

            $moduleManifest = Join-Path $PSScriptRoot (
                'Catalanitzador.Windows\Catalanitzador.Windows.psd1'
            )
            Import-Module -Name $moduleManifest -Force -ErrorAction Stop

            $configurationParameters = @{}
            if ($null -ne $effectiveHomeLocation) {
                $configurationParameters['HomeLocationGeoId'] = $effectiveHomeLocation
            }
            if (-not [string]::IsNullOrWhiteSpace(
                    $effectiveDefaultInputMethod
                )) {
                $configurationParameters['DefaultInputMethodTip'] = (
                    $effectiveDefaultInputMethod
                )
            }
            if ($effectiveWhatIf) {
                $configurationParameters['WhatIf'] = $true
            }
            if ($effectiveConfirmBound) {
                $configurationParameters['Confirm'] = $effectiveConfirm
            }
            if ($effectiveVerboseBound) {
                $configurationParameters['Verbose'] = $effectiveVerbose
            }

            $complianceParameters = @{}
            if ($null -ne $effectiveHomeLocation) {
                $complianceParameters['HomeLocationGeoId'] = (
                    $effectiveHomeLocation
                )
            }
            if (-not [string]::IsNullOrWhiteSpace(
                    $effectiveDefaultInputMethod
                )) {
                $complianceParameters['DefaultInputMethodTip'] = (
                    $effectiveDefaultInputMethod
                )
            }
            $preflightCompliance = Test-CatalanitzadorConfiguration `
                @complianceParameters
            if (
                $preflightCompliance.IsCompliant -and
                -not $preflightCompliance.PendingSystemCopy
            ) {
                $result = [pscustomobject]@{
                    PSTypeName = 'Catalanitzador.Windows.Result'
                    Changed = $false
                    AlreadyCompliant = $true
                    WhatIf = $effectiveWhatIf
                    Message = (
                        'Windows ja està configurat completament en català. ' +
                        'No cal fer cap canvi.'
                    )
                    Changes = @()
                    PlannedChanges = @()
                    DeclinedSettings = @()
                    DeferredSettings = @()
                    Warnings = @()
                    SignOutRequired = $false
                    RestartRequired = $false
                    InitialCompliance = $preflightCompliance
                    FinalCompliance = $preflightCompliance
                }
            }
            else {
                if (-not $effectiveWhatIf) {
                    Initialize-CatalanitzadorLog -Path $effectiveLogPath
                    $logInitialized = $true
                    Write-CatalanitzadorLog `
                        -Path $effectiveLogPath `
                        -Level INFO `
                        -Message "Identitat verificada: $currentSid."
                }

                $result = Set-CatalanitzadorConfiguration `
                    @configurationParameters
            }

            if ([string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
                Show-CatalanitzadorResult `
                    -Result $result `
                    -EffectiveLogPath $(if ($logInitialized) {
                        $effectiveLogPath
                    })
            }

            if ($logInitialized) {
                Write-CatalanitzadorLog `
                    -Path $effectiveLogPath `
                    -Level INFO `
                    -Message (
                        (
                            'Resultat: Changed={0}; AlreadyCompliant={1}; ' +
                            'WhatIf={2}; SignOutRequired={3}; ' +
                            'RestartRequired={4}.'
                        ) -f
                        $result.Changed,
                        $result.AlreadyCompliant,
                        $result.WhatIf,
                        $result.SignOutRequired,
                        $result.RestartRequired
                    )

                foreach ($change in @($result.Changes)) {
                    Write-CatalanitzadorLog `
                        -Path $effectiveLogPath `
                        -Level INFO `
                        -Message "Canvi: $change"
                }

                foreach ($warning in @($result.Warnings)) {
                    Write-CatalanitzadorLog `
                        -Path $effectiveLogPath `
                        -Level WARN `
                        -Message ([string]$warning)
                }
            }

            if ($effectivePassThru -and
                [string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
                Write-Output $result
            }

            if ($result.RestartRequired) {
                $exitCode = $script:ExitCodeRestartRequired
            }
        }
    }
}
catch {
    $exitCode = $failureExitCode
    $errorMessage = $_.Exception.Message

    if ($logInitialized) {
        try {
            Write-CatalanitzadorLog `
                -Path $effectiveLogPath `
                -Level ERROR `
                -Message $errorMessage
        }
        catch {
            [Console]::Error.WriteLine(
                'Catalanitzador: no s''ha pogut actualitzar el registre local.'
            )
        }
    }

    if ([string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
        [Console]::Error.WriteLine("Catalanitzador: $errorMessage")
    }
}

if ($writeRelayOnExit -and
    -not [string]::IsNullOrWhiteSpace($effectiveRelayPath)) {
    try {
        Write-CatalanitzadorRelay `
            -Path $effectiveRelayPath `
            -Value ([pscustomobject]@{
                SchemaVersion = 1
                Nonce = $effectiveRelayNonce
                Success = [string]::IsNullOrWhiteSpace($errorMessage)
                ExitCode = $exitCode
                ErrorMessage = $errorMessage
                Result = $result
                LogPath = $(if ($logInitialized) {
                    $effectiveLogPath
                })
            })
    }
    catch {
        $exitCode = $script:ExitCodeError
        [Console]::Error.WriteLine(
            "Catalanitzador: no s'ha pogut retornar el resultat elevat."
        )
    }
}

if (-not [string]::IsNullOrWhiteSpace($relayPathToRemove) -and
    (Test-Path -LiteralPath $relayPathToRemove)) {
    [IO.File]::Delete($relayPathToRemove)
}

$global:LASTEXITCODE = $exitCode
if ($isRelaunched -or (Test-CatalanitzadorFileInvocation)) {
    exit $exitCode
}
