# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

#Requires -Version 5.1

Set-StrictMode -Version Latest

$script:TargetLanguage = 'ca-ES'
$script:TargetLanguageAliases = @('ca', 'ca-ES')
$script:TargetInputTip = '0403:0000040A'
$script:SupportedCapabilityKinds = @(
    'Basic'
    'OCR'
    'Handwriting'
    'TextToSpeech'
    'Speech'
)

function ConvertTo-CatalanitzadorObjectArray {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return
    }

    if (($Value -is [string]) -or
        ($Value -is [Collections.IDictionary]) -or
        -not ($Value -is [Collections.IEnumerable])) {
        return ,$Value
    }

    foreach ($item in $Value) {
        Write-Output -InputObject $item -NoEnumerate
    }
}

function ConvertTo-CatalanitzadorStringArray {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    $values = @()
    foreach ($item in @(ConvertTo-CatalanitzadorObjectArray -Value $Value)) {
        if ($null -eq $item) {
            continue
        }

        foreach ($part in ([string]$item -split ',\s*')) {
            if (-not [string]::IsNullOrWhiteSpace($part)) {
                $values += $part.Trim()
            }
        }
    }

    return @($values | Select-Object -Unique)
}

function Get-CatalanitzadorCultureName {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    $nameProperty = $Value.PSObject.Properties['Name']
    if ($null -ne $nameProperty) {
        return [string]$nameProperty.Value
    }

    return [string]$Value
}

function Get-CatalanitzadorInputTipValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    foreach ($propertyName in @('InputMethodTip', 'InputTip')) {
        $property = $Value.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            return [string]$property.Value
        }
    }

    return [string]$Value
}

function Test-CatalanitzadorTargetLanguage {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    $name = Get-CatalanitzadorCultureName -Value $Value
    return (
        -not [string]::IsNullOrWhiteSpace($name) -and
        $script:TargetLanguageAliases -icontains $name
    )
}

function Get-CatalanitzadorPlatform {
    [CmdletBinding()]
    param()

    $computerInfo = Get-ComputerInfo -Property @(
        'WindowsProductName'
        'WindowsEditionId'
        'OsBuildNumber'
        'OsArchitecture'
        'OsProductType'
    ) -ErrorAction Stop

    $buildNumber = 0
    if (-not [int]::TryParse([string]$computerInfo.OsBuildNumber, [ref]$buildNumber)) {
        throw "No s'ha pogut determinar la compilació de Windows."
    }

    if ([string]$computerInfo.OsProductType -ne 'WorkStation') {
        throw 'Aquest projecte només és compatible amb edicions client de Windows.'
    }

    if (($buildNumber -ne 19045) -and ($buildNumber -lt 22000)) {
        throw "La compilació $buildNumber no és compatible. Cal Windows 10 22H2 (19045) o Windows 11."
    }

    $editionId = [string]$computerInfo.WindowsEditionId
    if ($editionId -match '(?i)SingleLanguage|CountrySpecific') {
        throw "L'edició $editionId no permet afegir una llengua de visualització."
    }

    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        throw 'Cal executar el mòdul amb el Windows PowerShell natiu de 64 bits.'
    }

    $requiredCommands = @(
        'Get-InstalledLanguage'
        'Get-SystemPreferredUILanguage'
        'Get-WindowsCapability'
        'Get-WinUserLanguageList'
        'Get-WinUILanguageOverride'
        'Get-WinDefaultInputMethodOverride'
        'Get-Culture'
        'Get-WinSystemLocale'
        'Get-WinHomeLocation'
        'Install-Language'
        'Set-SystemPreferredUILanguage'
        'Add-WindowsCapability'
        'New-WinUserLanguageList'
        'Set-WinUserLanguageList'
        'Set-WinUILanguageOverride'
        'Set-WinDefaultInputMethodOverride'
        'Set-Culture'
        'Set-WinSystemLocale'
        'Set-WinHomeLocation'
    )
    if ($buildNumber -ge 22000) {
        $requiredCommands += 'Copy-UserInternationalSettingsToSystem'
    }

    $missingCommands = @(
        $requiredCommands |
            Where-Object { -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) }
    )

    if ($missingCommands.Count -gt 0) {
        throw "Falten ordres oficials necessàries: $($missingCommands -join ', ')."
    }

    $windowsFamily = if ($buildNumber -eq 19045) {
        'Windows 10 22H2'
    }
    else {
        'Windows 11'
    }

    [pscustomobject]@{
        PSTypeName = 'Catalanitzador.Windows.Platform'
        ProductName = [string]$computerInfo.WindowsProductName
        Family = $windowsFamily
        EditionId = $editionId
        BuildNumber = $buildNumber
        Architecture = [string]$computerInfo.OsArchitecture
        Is64BitProcess = [Environment]::Is64BitProcess
        CanCopyUserSettingsToSystem = ($buildNumber -ge 22000)
    }
}

function Get-CatalanitzadorCapabilityKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Name -match '^Language\.([^~]+)~~~ca-ES~') {
        return [string]$Matches[1]
    }

    return $null
}

function Get-CatalanitzadorCapability {
    [CmdletBinding()]
    param()

    $capabilityOrder = @{}
    for ($index = 0; $index -lt $script:SupportedCapabilityKinds.Count; $index++) {
        $capabilityOrder[$script:SupportedCapabilityKinds[$index]] = $index
    }

    $rawCapabilities = @(
        ConvertTo-CatalanitzadorObjectArray -Value (
            Get-WindowsCapability -Online -ErrorAction Stop
        )
    )

    @(
        $rawCapabilities |
            ForEach-Object {
                $kind = Get-CatalanitzadorCapabilityKind -Name ([string]$_.Name)
                if (($null -ne $kind) -and ($script:SupportedCapabilityKinds -contains $kind)) {
                    [pscustomobject]@{
                        Name = [string]$_.Name
                        Kind = $kind
                        State = [string]$_.State
                        Order = $capabilityOrder[$kind]
                    }
                }
            } |
            Sort-Object -Property Order, Name |
            Select-Object -Property Name, Kind, State
    )
}

function Get-CatalanitzadorState {
    [CmdletBinding()]
    param()

    $platform = Get-CatalanitzadorPlatform

    $installedLanguages = @(
        ConvertTo-CatalanitzadorObjectArray -Value (
            Get-InstalledLanguage -ErrorAction Stop
        )
    )
    $targetInstalledLanguage = @(
        $installedLanguages |
            Where-Object {
                Test-CatalanitzadorTargetLanguage -Value $_.LanguageId
            }
    ) | Select-Object -First 1

    $languagePacks = @()
    $languageFeatures = @()
    if ($null -ne $targetInstalledLanguage) {
        $languagePacks = ConvertTo-CatalanitzadorStringArray -Value $targetInstalledLanguage.LanguagePacks
        $languageFeatures = ConvertTo-CatalanitzadorStringArray -Value $targetInstalledLanguage.LanguageFeatures
    }

    $capabilities = @(Get-CatalanitzadorCapability)

    $userLanguages = @(
        ConvertTo-CatalanitzadorObjectArray -Value (
            Get-WinUserLanguageList -ErrorAction Stop
        ) |
            ForEach-Object {
                [pscustomobject]@{
                    LanguageTag = [string]$_.LanguageTag
                    InputMethodTips = @(
                        $_.InputMethodTips |
                            ForEach-Object { [string]$_ }
                    )
                    Spellchecking = [bool]$_.Spellchecking
                    Handwriting = [bool]$_.Handwriting
                }
            }
    )

    $uiLanguageOverride = Get-CatalanitzadorCultureName -Value (
        Get-WinUILanguageOverride -ErrorAction Stop
    )
    $defaultInputMethod = Get-CatalanitzadorInputTipValue -Value (
        Get-WinDefaultInputMethodOverride -ErrorAction Stop
    )
    $effectiveDefaultInputMethod = $defaultInputMethod
    if ([string]::IsNullOrWhiteSpace($effectiveDefaultInputMethod)) {
        foreach ($language in $userLanguages) {
            $firstInputMethod = @($language.InputMethodTips) |
                Select-Object -First 1
            if (-not [string]::IsNullOrWhiteSpace($firstInputMethod)) {
                $effectiveDefaultInputMethod = [string]$firstInputMethod
                break
            }
        }
    }
    $culture = Get-CatalanitzadorCultureName -Value (Get-Culture -ErrorAction Stop)
    $systemLocale = Get-CatalanitzadorCultureName -Value (
        Get-WinSystemLocale -ErrorAction Stop
    )
    $homeLocation = Get-WinHomeLocation -ErrorAction Stop

    [pscustomobject]@{
        PSTypeName = 'Catalanitzador.Windows.State'
        CapturedAt = [DateTimeOffset]::Now
        Platform = $platform
        Language = [pscustomobject]@{
            LanguageId = $script:TargetLanguage
            IsPresent = ($null -ne $targetInstalledLanguage)
            HasDisplayLanguage = (
                @($languagePacks | Where-Object { $_ -ine 'None' }).Count -gt 0
            )
            LanguagePacks = $languagePacks
            LanguageFeatures = $languageFeatures
            Capabilities = $capabilities
        }
        User = [pscustomobject]@{
            Languages = $userLanguages
            UILanguageOverride = $uiLanguageOverride
            Culture = $culture
            DefaultInputMethod = $defaultInputMethod
            EffectiveDefaultInputMethod = $effectiveDefaultInputMethod
            HomeLocationGeoId = [int]$homeLocation.GeoId
        }
        Machine = [pscustomobject]@{
            SystemPreferredUILanguage = [string](
                Get-SystemPreferredUILanguage -ErrorAction Stop
            )
            SystemLocale = $systemLocale
        }
    }
}

function New-CatalanitzadorSettingResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Compliant,

        [Parameter()]
        [AllowNull()]
        [object]$Current,

        [Parameter()]
        [AllowNull()]
        [object]$Desired
    )

    [pscustomobject]@{
        Name = $Name
        Compliant = $Compliant
        Current = $Current
        Desired = $Desired
    }
}

function Test-CatalanitzadorShouldProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Caller,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Action
    )

    return $Caller.ShouldProcess($Target, $Action)
}

function Install-CatalanitzadorLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Compliance,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Caller
    )

    $changes = @()
    $declinedSettings = @()
    $restartRequired = $false
    $signOutRequired = $false

    $displayLanguageSetting = @(
        $Compliance.Settings |
            Where-Object { $_.Name -eq 'DisplayLanguagePackage' }
    ) | Select-Object -First 1

    $languageInstallAttempted = $false
    if (($null -ne $displayLanguageSetting) -and -not $displayLanguageSetting.Compliant) {
        $shouldInstallLanguage = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target 'Windows' `
            -Action (
                "Instal·la el paquet de llengua de visualització " +
                $script:TargetLanguage
            )
        if ($shouldInstallLanguage) {
            $installParameters = @{
                Language = $script:TargetLanguage
                ErrorAction = 'Stop'
            }

            if ($Compliance.State.Platform.BuildNumber -eq 19045) {
                $installParameters['CopyToSettings'] = $true
            }

            Install-Language @installParameters | Out-Null
            $languageInstallAttempted = $true
            $changes += 'DisplayLanguagePackage'
            $restartRequired = $true
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'DisplayLanguagePackage'
        }
    }

    $capabilities = if ($languageInstallAttempted) {
        @(Get-CatalanitzadorCapability)
    }
    else {
        @($Compliance.State.Language.Capabilities)
    }

    if ($capabilities.Count -eq 0) {
        throw "Windows no ha publicat cap capacitat de llengua per a $script:TargetLanguage."
    }

    foreach ($capability in @($capabilities | Where-Object { $_.State -ine 'Installed' })) {
        $shouldInstallCapability = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target $capability.Name `
            -Action 'Instal·la la capacitat oficial de llengua de Windows'
        if ($shouldInstallCapability) {
            $result = Add-WindowsCapability `
                -Online `
                -Name $capability.Name `
                -ErrorAction Stop

            if (($null -ne $result) -and ($result.PSObject.Properties['RestartNeeded'])) {
                $restartRequired = $restartRequired -or [bool]$result.RestartNeeded
            }

            $changes += "LanguageCapability:$($capability.Kind)"
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'LanguageCapabilities'
        }
    }

    [pscustomobject]@{
        Changes = @($changes)
        DeclinedSettings = @($declinedSettings | Select-Object -Unique)
        RestartRequired = $restartRequired
        SignOutRequired = $signOutRequired
    }
}

function Test-CatalanitzadorGeoId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$GeoId
    )

    $nativeType = 'Catalanitzador.Windows.NativeMethods' -as [type]
    if ($null -eq $nativeType) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Catalanitzador.Windows
{
    public static class NativeMethods
    {
        [DllImport(
            "kernel32.dll",
            CharSet = CharSet.Unicode,
            EntryPoint = "GetGeoInfoW",
            SetLastError = true)]
        public static extern int GetGeoInfo(
            int location,
            int geoType,
            StringBuilder geoData,
            int dataCount,
            int languageId);
    }
}
'@
        $nativeType = 'Catalanitzador.Windows.NativeMethods' -as [type]
    }

    return ($nativeType::GetGeoInfo($GeoId, 8, $null, 0, 0) -gt 0)
}

function Get-CatalanitzadorCommonApplicationDataPath {
    [CmdletBinding()]
    param()

    $path = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::CommonApplicationData
    )
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "No s'ha pogut determinar el directori ProgramData."
    }

    return $path
}

function Get-CatalanitzadorPendingSystemCopyPath {
    [CmdletBinding()]
    param()

    return Join-Path (Get-CatalanitzadorCommonApplicationDataPath) (
        'Catalanitzador.Windows\State\CopyUserInternationalSettings.pending'
    )
}

function New-CatalanitzadorStateDirectorySecurity {
    [CmdletBinding()]
    param()

    $administrators = New-Object Security.Principal.SecurityIdentifier(
        'S-1-5-32-544'
    )
    $system = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    $inheritance = (
        [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [Security.AccessControl.InheritanceFlags]::ObjectInherit
    )
    $security = New-Object Security.AccessControl.DirectorySecurity
    $security.SetAccessRuleProtection($true, $false)
    foreach ($identity in @($administrators, $system)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $identity,
            [Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$security.AddAccessRule($rule)
    }
    $security.SetOwner($administrators)
    return $security
}

function Assert-CatalanitzadorRestrictedDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) {
        throw "La ruta d'estat no és un directori: $Path."
    }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "El directori d'estat no pot ser un punt de reanàlisi: $Path."
    }

    $security = $item.GetAccessControl(
        [Security.AccessControl.AccessControlSections]::Access -bor
        [Security.AccessControl.AccessControlSections]::Owner
    )
    $administrators = New-Object Security.Principal.SecurityIdentifier(
        'S-1-5-32-544'
    )
    $system = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    $trustedIdentities = @(
        $administrators.Value
        $system.Value
    )
    $owner = $security.GetOwner(
        [Security.Principal.SecurityIdentifier]
    )
    if ($trustedIdentities -notcontains $owner.Value) {
        throw "El propietari del directori d'estat no és segur: $Path."
    }
    if (-not $security.AreAccessRulesProtected) {
        throw "El directori d'estat no està protegit contra permisos heretats: $Path."
    }

    $rules = @(
        $security.GetAccessRules(
            $true,
            $true,
            [Security.Principal.SecurityIdentifier]
        )
    )
    $requiredInheritance = (
        [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [Security.AccessControl.InheritanceFlags]::ObjectInherit
    )
    foreach ($rule in $rules) {
        if ($rule.AccessControlType -eq (
                [Security.AccessControl.AccessControlType]::Allow
            ) -and
            $trustedIdentities -notcontains $rule.IdentityReference.Value) {
            throw "El directori d'estat concedeix accés a una identitat no admesa: $Path."
        }
    }
    foreach ($trustedIdentity in $trustedIdentities) {
        $fullControlRule = @(
            $rules |
                Where-Object {
                    $_.AccessControlType -eq (
                        [Security.AccessControl.AccessControlType]::Allow
                    ) -and
                    $_.IdentityReference.Value -eq $trustedIdentity -and
                    ($_.FileSystemRights -band (
                            [Security.AccessControl.FileSystemRights]::FullControl
                        )) -eq (
                        [Security.AccessControl.FileSystemRights]::FullControl
                    ) -and
                    ($_.InheritanceFlags -band $requiredInheritance) -eq (
                        $requiredInheritance
                    )
                }
        ).Count -gt 0
        if (-not $fullControlRule) {
            throw "El directori d'estat no té els permisos administratius requerits: $Path."
        }
    }
}

function New-CatalanitzadorRestrictedDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ParentPath,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $parent = Get-Item -LiteralPath $ParentPath -Force -ErrorAction Stop
    if (-not $parent.PSIsContainer -or
        ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "El directori pare de l'estat no és segur: $ParentPath."
    }

    $path = Join-Path $ParentPath $Name
    if (-not (Test-Path -LiteralPath $path)) {
        $security = New-CatalanitzadorStateDirectorySecurity
        [void]$parent.CreateSubdirectory($Name, $security)
    }
    Assert-CatalanitzadorRestrictedDirectory -Path $path
    return $path
}

function Initialize-CatalanitzadorStateDirectory {
    [CmdletBinding()]
    param()

    $statePath = Get-CatalanitzadorPendingSystemCopyPath
    $stateDirectory = Split-Path -Parent $statePath
    $projectDirectory = Split-Path -Parent $stateDirectory
    $commonApplicationData = Split-Path -Parent $projectDirectory
    $createdProjectDirectory = New-CatalanitzadorRestrictedDirectory `
        -ParentPath $commonApplicationData `
        -Name (Split-Path -Leaf $projectDirectory)
    [void](New-CatalanitzadorRestrictedDirectory `
            -ParentPath $createdProjectDirectory `
            -Name (Split-Path -Leaf $stateDirectory))
}

function Assert-CatalanitzadorStateDirectory {
    [CmdletBinding()]
    param()

    $statePath = Get-CatalanitzadorPendingSystemCopyPath
    $stateDirectory = Split-Path -Parent $statePath
    $projectDirectory = Split-Path -Parent $stateDirectory
    foreach ($directory in @($projectDirectory, $stateDirectory)) {
        Assert-CatalanitzadorRestrictedDirectory -Path $directory
    }
}

function Test-CatalanitzadorPendingSystemCopy {
    [CmdletBinding()]
    param()

    $path = Get-CatalanitzadorPendingSystemCopyPath
    $stateDirectory = Split-Path -Parent $path
    $projectDirectory = Split-Path -Parent $stateDirectory
    if (-not (Test-Path -LiteralPath $projectDirectory)) {
        return $false
    }

    Assert-CatalanitzadorRestrictedDirectory -Path $projectDirectory
    if (-not (Test-Path -LiteralPath $stateDirectory)) {
        return $false
    }

    Assert-CatalanitzadorRestrictedDirectory -Path $stateDirectory
    if (-not (Test-Path -LiteralPath $path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        [IO.File]::ReadAllText($path, [Text.Encoding]::ASCII) -cne 'pending') {
        throw 'El marcador de còpia internacional no és vàlid.'
    }
    return $true
}

function Set-CatalanitzadorPendingSystemCopy {
    [CmdletBinding()]
    param()

    Initialize-CatalanitzadorStateDirectory
    $path = Get-CatalanitzadorPendingSystemCopyPath
    if (Test-CatalanitzadorPendingSystemCopy) {
        return
    }

    $stream = $null
    try {
        $stream = [IO.File]::Open(
            $path,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        $value = [Text.Encoding]::ASCII.GetBytes('pending')
        $stream.Write($value, 0, $value.Length)
    }
    catch [IO.IOException] {
        if (-not (Test-CatalanitzadorPendingSystemCopy)) {
            throw
        }
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Clear-CatalanitzadorPendingSystemCopy {
    [CmdletBinding()]
    param()

    $path = Get-CatalanitzadorPendingSystemCopyPath
    if (Test-CatalanitzadorPendingSystemCopy) {
        Assert-CatalanitzadorStateDirectory
        [IO.File]::Delete($path)
    }
}

function Set-CatalanitzadorPendingSystemCopyBeforeMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Compliance
    )

    if ($Compliance.State.Platform.CanCopyUserSettingsToSystem) {
        Set-CatalanitzadorPendingSystemCopy
    }
}

function Set-CatalanitzadorUserSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Compliance,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Caller,

        [Parameter()]
        [Nullable[int]]$HomeLocationGeoId,

        [Parameter()]
        [AllowNull()]
        [string]$DefaultInputMethodTip
    )

    $changes = @()
    $declinedSettings = @()
    $signOutRequired = $false
    $homeLocationValue = if ($null -eq $HomeLocationGeoId) {
        $null
    }
    else {
        [int]$HomeLocationGeoId
    }
    $settingsByName = @{}
    foreach ($setting in $Compliance.Settings) {
        $settingsByName[$setting.Name] = $setting
    }

    $languageListNeedsChange = (
        -not $settingsByName['PreferredLanguageOrder'].Compliant -or
        -not $settingsByName['CatalanInputMethod'].Compliant
    )

    if ($languageListNeedsChange) {
        $shouldChangeLanguageList = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target "Llista de llengües de l'usuari actual" `
            -Action (
                "Posa $script:TargetLanguage en primer lloc i conserva les " +
                'altres llengües'
            )
        if ($shouldChangeLanguageList) {
            $currentLanguages = @(
                ConvertTo-CatalanitzadorObjectArray -Value (
                    Get-WinUserLanguageList -ErrorAction Stop
                )
            )
            $catalanLanguage = @(
                $currentLanguages |
                    Where-Object {
                        Test-CatalanitzadorTargetLanguage -Value $_.LanguageTag
                    }
            ) | Select-Object -First 1

            if ($null -eq $catalanLanguage) {
                $catalanLanguage = (
                    New-WinUserLanguageList -Language $script:TargetLanguage
                )[0]
            }

            if ($catalanLanguage.InputMethodTips -inotcontains $script:TargetInputTip) {
                $catalanLanguage.InputMethodTips.Add($script:TargetInputTip)
            }

            $desiredLanguages = New-WinUserLanguageList `
                -Language $script:TargetLanguage
            $desiredLanguages.Clear()
            $desiredLanguages.Add($catalanLanguage)

            foreach ($language in $currentLanguages) {
                if (-not (
                        Test-CatalanitzadorTargetLanguage `
                            -Value $language.LanguageTag
                    )) {
                    $desiredLanguages.Add($language)
                }
            }

            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-WinUserLanguageList `
                -LanguageList $desiredLanguages `
                -Force `
                -ErrorAction Stop
            $changes += 'PreferredLanguageOrder'
            $changes += 'CatalanInputMethod'
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += @(
                'PreferredLanguageOrder'
                'CatalanInputMethod'
            )
        }
    }

    if ($settingsByName.ContainsKey('DefaultInputMethod') -and
        -not $settingsByName['DefaultInputMethod'].Compliant) {
        $shouldChangeDefaultInput = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target "Mètode d'entrada predeterminat" `
            -Action "Estableix $DefaultInputMethodTip"
        if ($shouldChangeDefaultInput) {
            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-WinDefaultInputMethodOverride `
                -InputTip $DefaultInputMethodTip `
                -ErrorAction Stop
            $changes += 'DefaultInputMethod'
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'DefaultInputMethod'
        }
    }

    if (-not $settingsByName['UserDisplayLanguage'].Compliant) {
        $shouldChangeDisplayLanguage = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target "Llengua de visualització de l'usuari actual" `
            -Action "Estableix $script:TargetLanguage"
        if ($shouldChangeDisplayLanguage) {
            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-WinUILanguageOverride `
                -Language $script:TargetLanguage `
                -ErrorAction Stop
            $changes += 'UserDisplayLanguage'
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'UserDisplayLanguage'
        }
    }

    if (-not $settingsByName['Culture'].Compliant) {
        $shouldChangeCulture = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target "Format regional de l'usuari actual" `
            -Action "Estableix $script:TargetLanguage"
        if ($shouldChangeCulture) {
            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-Culture -CultureInfo $script:TargetLanguage -ErrorAction Stop
            $changes += 'Culture'
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'Culture'
        }
    }

    if (($null -ne $HomeLocationGeoId) -and
        $settingsByName.ContainsKey('HomeLocation') -and
        -not $settingsByName['HomeLocation'].Compliant) {
        $shouldChangeHomeLocation = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target "Ubicació principal de l'usuari actual" `
            -Action "Estableix el GeoID $homeLocationValue"
        if ($shouldChangeHomeLocation) {
            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-WinHomeLocation -GeoId $homeLocationValue -ErrorAction Stop
            $changes += 'HomeLocation'
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'HomeLocation'
        }
    }

    [pscustomobject]@{
        Changes = @($changes | Select-Object -Unique)
        DeclinedSettings = @($declinedSettings | Select-Object -Unique)
        SignOutRequired = $signOutRequired
    }
}

function Set-CatalanitzadorMachineSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Compliance,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Caller,

        [Parameter(Mandatory)]
        [bool]$CopyUserSettings,

        [Parameter(Mandatory)]
        [bool]$ChangesAlreadyApplied,

        [Parameter(Mandatory)]
        [bool]$PrerequisiteSettingsDeclined
    )

    $changes = @()
    $declinedSettings = @()
    $deferredSettings = @()
    $warnings = @()
    $restartRequired = $false
    $signOutRequired = $false
    $settingsByName = @{}
    foreach ($setting in $Compliance.Settings) {
        $settingsByName[$setting.Name] = $setting
    }

    if (-not $settingsByName['SystemPreferredUILanguage'].Compliant) {
        $shouldChangeSystemLanguage = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target 'Llengua de visualització preferida del sistema' `
            -Action "Estableix $script:TargetLanguage"
        if ($shouldChangeSystemLanguage) {
            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-SystemPreferredUILanguage `
                -Language $script:TargetLanguage `
                -ErrorAction Stop
            $changes += 'SystemPreferredUILanguage'
            $restartRequired = $true
            $signOutRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'SystemPreferredUILanguage'
        }
    }

    if (-not $settingsByName['SystemLocale'].Compliant) {
        $shouldChangeSystemLocale = Test-CatalanitzadorShouldProcess `
            -Caller $Caller `
            -Target (
                'Configuració regional del sistema per a aplicacions no Unicode'
            ) `
            -Action "Estableix $script:TargetLanguage"
        if ($shouldChangeSystemLocale) {
            Set-CatalanitzadorPendingSystemCopyBeforeMutation `
                -Compliance $Compliance
            Set-WinSystemLocale `
                -SystemLocale $script:TargetLanguage `
                -ErrorAction Stop
            $changes += 'SystemLocale'
            $restartRequired = $true
        }
        elseif (-not $WhatIfPreference) {
            $declinedSettings += 'SystemLocale'
        }
    }

    if ($CopyUserSettings) {
        if ($Compliance.State.Platform.CanCopyUserSettingsToSystem) {
            $copyWasPending = Test-CatalanitzadorPendingSystemCopy
            $trackCopy = (
                $copyWasPending -or
                $ChangesAlreadyApplied -or
                $changes.Count -gt 0
            )
            $copyPrerequisitesDeclined = (
                $PrerequisiteSettingsDeclined -or
                $declinedSettings.Count -gt 0
            )
            if ($copyPrerequisitesDeclined) {
                $deferredSettings += 'WelcomeScreenAndNewUsers'
            }
            else {
                if ($trackCopy -and -not $WhatIfPreference) {
                    Set-CatalanitzadorPendingSystemCopy
                }
                if ($trackCopy -or $WhatIfPreference) {
                    $shouldCopyUserSettings = (
                        Test-CatalanitzadorShouldProcess `
                            -Caller $Caller `
                            -Target (
                                'Pantalla de benvinguda, comptes del sistema ' +
                                'i usuaris nous'
                            ) `
                            -Action (
                                'Copia la configuració internacional de ' +
                                "l'usuari actual"
                            )
                    )
                    if ($shouldCopyUserSettings) {
                        Copy-UserInternationalSettingsToSystem `
                            -WelcomeScreen $true `
                            -NewUser $true `
                            -ErrorAction Stop
                        Clear-CatalanitzadorPendingSystemCopy
                        $changes += 'WelcomeScreenAndNewUsers'
                        $restartRequired = $true
                    }
                    elseif (-not $WhatIfPreference) {
                        $declinedSettings += 'WelcomeScreenAndNewUsers'
                    }
                }
            }
        }
        elseif ($Compliance.State.Platform.BuildNumber -eq 19045) {
            $warnings += (
                'Windows 10 no ofereix Copy-UserInternationalSettingsToSystem. ' +
                "S'han aplicat només els valors de sistema documentats disponibles."
            )
        }
    }

    [pscustomobject]@{
        Changes = @($changes)
        DeclinedSettings = @($declinedSettings | Select-Object -Unique)
        DeferredSettings = @($deferredSettings | Select-Object -Unique)
        Warnings = @($warnings)
        RestartRequired = $restartRequired
        SignOutRequired = $signOutRequired
    }
}

function Test-CatalanitzadorConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(2, [int]::MaxValue)]
        [Nullable[int]]$HomeLocationGeoId,

        [Parameter()]
        [ValidatePattern('^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{8}$')]
        [string]$DefaultInputMethodTip
    )

    $state = Get-CatalanitzadorState
    $settings = @()
    $homeLocationValue = if ($null -eq $HomeLocationGeoId) {
        $null
    }
    else {
        [int]$HomeLocationGeoId
    }
    $desiredInputMethod = if (
        [string]::IsNullOrWhiteSpace($DefaultInputMethodTip)
    ) {
        $null
    }
    else {
        $DefaultInputMethodTip.ToUpperInvariant()
    }

    $settings += New-CatalanitzadorSettingResult `
        -Name 'DisplayLanguagePackage' `
        -Compliant $state.Language.HasDisplayLanguage `
        -Current $state.Language.LanguagePacks `
        -Desired 'Microsoft ca-ES display language package'

    $missingCapabilities = @(
        $state.Language.Capabilities |
            Where-Object { $_.State -ine 'Installed' } |
            Select-Object -ExpandProperty Name
    )
    $capabilitiesCompliant = (
        ($state.Language.Capabilities.Count -gt 0) -and
        ($missingCapabilities.Count -eq 0)
    )
    $settings += New-CatalanitzadorSettingResult `
        -Name 'LanguageCapabilities' `
        -Compliant $capabilitiesCompliant `
        -Current $state.Language.Capabilities `
        -Desired 'All available ca-ES end-user capabilities installed'

    $firstLanguage = $null
    if ($state.User.Languages.Count -gt 0) {
        $firstLanguage = [string]$state.User.Languages[0].LanguageTag
    }
    $settings += New-CatalanitzadorSettingResult `
        -Name 'PreferredLanguageOrder' `
        -Compliant (Test-CatalanitzadorTargetLanguage -Value $firstLanguage) `
        -Current $firstLanguage `
        -Desired $script:TargetLanguage

    $catalanLanguage = @(
        $state.User.Languages |
            Where-Object {
                Test-CatalanitzadorTargetLanguage -Value $_.LanguageTag
            }
    ) | Select-Object -First 1
    $hasCatalanInputMethod = (
        ($null -ne $catalanLanguage) -and
        ($catalanLanguage.InputMethodTips -icontains $script:TargetInputTip)
    )
    $settings += New-CatalanitzadorSettingResult `
        -Name 'CatalanInputMethod' `
        -Compliant $hasCatalanInputMethod `
        -Current $(if ($null -eq $catalanLanguage) { @() } else { $catalanLanguage.InputMethodTips }) `
        -Desired $script:TargetInputTip

    if ($null -ne $desiredInputMethod) {
        $settings += New-CatalanitzadorSettingResult `
            -Name 'DefaultInputMethod' `
            -Compliant ($state.User.DefaultInputMethod -ieq $desiredInputMethod) `
            -Current $state.User.DefaultInputMethod `
            -Desired $desiredInputMethod
    }

    $settings += New-CatalanitzadorSettingResult `
        -Name 'UserDisplayLanguage' `
        -Compliant (
            Test-CatalanitzadorTargetLanguage `
                -Value $state.User.UILanguageOverride
        ) `
        -Current $state.User.UILanguageOverride `
        -Desired $script:TargetLanguage

    $settings += New-CatalanitzadorSettingResult `
        -Name 'Culture' `
        -Compliant (
            Test-CatalanitzadorTargetLanguage -Value $state.User.Culture
        ) `
        -Current $state.User.Culture `
        -Desired $script:TargetLanguage

    $settings += New-CatalanitzadorSettingResult `
        -Name 'SystemPreferredUILanguage' `
        -Compliant (
            Test-CatalanitzadorTargetLanguage `
                -Value $state.Machine.SystemPreferredUILanguage
        ) `
        -Current $state.Machine.SystemPreferredUILanguage `
        -Desired $script:TargetLanguage

    $settings += New-CatalanitzadorSettingResult `
        -Name 'SystemLocale' `
        -Compliant (
            Test-CatalanitzadorTargetLanguage -Value $state.Machine.SystemLocale
        ) `
        -Current $state.Machine.SystemLocale `
        -Desired $script:TargetLanguage

    if ($null -ne $HomeLocationGeoId) {
        $settings += New-CatalanitzadorSettingResult `
            -Name 'HomeLocation' `
            -Compliant ($state.User.HomeLocationGeoId -eq $homeLocationValue) `
            -Current $state.User.HomeLocationGeoId `
            -Desired $homeLocationValue
    }

    $pendingSystemCopy = $false
    if ($state.Platform.CanCopyUserSettingsToSystem) {
        $pendingSystemCopy = [bool](
            Test-CatalanitzadorPendingSystemCopy
        )
        $settings += New-CatalanitzadorSettingResult `
            -Name 'WelcomeScreenAndNewUsers' `
            -Compliant (-not $pendingSystemCopy) `
            -Current $pendingSystemCopy `
            -Desired $false
    }

    $pendingSettings = @($settings | Where-Object { -not $_.Compliant })

    [pscustomobject]@{
        PSTypeName = 'Catalanitzador.Windows.Compliance'
        IsCompliant = ($pendingSettings.Count -eq 0)
        AlreadyCompliant = ($pendingSettings.Count -eq 0)
        Settings = $settings
        PendingSettings = $pendingSettings
        CompliantSettings = @($settings | Where-Object { $_.Compliant })
        MissingCapabilities = $missingCapabilities
        PendingSystemCopy = $pendingSystemCopy
        State = $state
    }
}

function Set-CatalanitzadorConfiguration {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter()]
        [ValidateRange(2, [int]::MaxValue)]
        [Nullable[int]]$HomeLocationGeoId,

        [Parameter()]
        [ValidatePattern('^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{8}$')]
        [string]$DefaultInputMethodTip
    )

    $homeLocationValue = if ($null -eq $HomeLocationGeoId) {
        $null
    }
    else {
        [int]$HomeLocationGeoId
    }
    $requestedInputMethod = if (
        [string]::IsNullOrWhiteSpace($DefaultInputMethodTip)
    ) {
        $null
    }
    else {
        $DefaultInputMethodTip.ToUpperInvariant()
    }

    if (($null -ne $homeLocationValue) -and
        -not (Test-CatalanitzadorGeoId -GeoId $homeLocationValue)) {
        throw "El GeoID $homeLocationValue no correspon a cap regió coneguda per Windows."
    }

    $initialComplianceParameters = @{}
    if ($null -ne $HomeLocationGeoId) {
        $initialComplianceParameters['HomeLocationGeoId'] = $HomeLocationGeoId
    }
    if ($null -ne $requestedInputMethod) {
        $initialComplianceParameters['DefaultInputMethodTip'] = (
            $requestedInputMethod
        )
    }

    $initialCompliance = Test-CatalanitzadorConfiguration @initialComplianceParameters
    $desiredInputMethod = $requestedInputMethod
    if ($null -eq $desiredInputMethod) {
        $languageListWillChange = @(
            $initialCompliance.PendingSettings |
                Where-Object {
                    $_.Name -in @(
                        'PreferredLanguageOrder'
                        'CatalanInputMethod'
                    )
                }
        ).Count -gt 0
        if ($languageListWillChange -and
            [string]::IsNullOrWhiteSpace(
                $initialCompliance.State.User.DefaultInputMethod
            )) {
            $desiredInputMethod = [string](
                $initialCompliance.State.User.EffectiveDefaultInputMethod
            )
            if ([string]::IsNullOrWhiteSpace($desiredInputMethod)) {
                throw (
                    "No s'ha pogut determinar el mètode d'entrada " +
                    'predeterminat actual abans de reordenar les llengües.'
                )
            }

            $initialComplianceParameters['DefaultInputMethodTip'] = (
                $desiredInputMethod
            )
            $initialCompliance = Test-CatalanitzadorConfiguration `
                @initialComplianceParameters
        }
    }

    $copyWasPending = [bool]$initialCompliance.PendingSystemCopy
    if ($initialCompliance.IsCompliant -and -not $copyWasPending) {
        return [pscustomobject]@{
            PSTypeName = 'Catalanitzador.Windows.Result'
            Changed = $false
            AlreadyCompliant = $true
            WhatIf = [bool]$WhatIfPreference
            Message = 'Windows ja està configurat completament en català. No cal fer cap canvi.'
            Changes = @()
            PlannedChanges = @()
            DeclinedSettings = @()
            DeferredSettings = @()
            Warnings = @()
            SignOutRequired = $false
            RestartRequired = $false
            InitialCompliance = $initialCompliance
            FinalCompliance = $initialCompliance
        }
    }

    if ($null -ne $desiredInputMethod) {
        $availableInputMethods = @(
            $initialCompliance.State.User.Languages |
                ForEach-Object { $_.InputMethodTips }
        )
        if (($desiredInputMethod -ine $script:TargetInputTip) -and
            ($availableInputMethods -inotcontains $desiredInputMethod)) {
            throw (
                "El mètode d'entrada $desiredInputMethod no està instal·lat. " +
                'Afegiu-lo a Windows abans de seleccionar-lo com a predeterminat.'
            )
        }
    }

    $languageResult = Install-CatalanitzadorLanguage `
        -Compliance $initialCompliance `
        -Caller $PSCmdlet

    $userResult = Set-CatalanitzadorUserSetting `
        -Compliance $initialCompliance `
        -Caller $PSCmdlet `
        -HomeLocationGeoId $HomeLocationGeoId `
        -DefaultInputMethodTip $desiredInputMethod

    $systemPreferredSetting = @(
        $initialCompliance.Settings |
            Where-Object { $_.Name -eq 'SystemPreferredUILanguage' }
    ) | Select-Object -First 1
    $systemLocaleSetting = @(
        $initialCompliance.Settings |
            Where-Object { $_.Name -eq 'SystemLocale' }
    ) | Select-Object -First 1
    $copyUserSettings = (
        $copyWasPending -or
        $userResult.Changes.Count -gt 0 -or
        ($null -eq $systemPreferredSetting) -or
        -not $systemPreferredSetting.Compliant -or
        ($null -eq $systemLocaleSetting) -or
        -not $systemLocaleSetting.Compliant
    )

    $machineResult = Set-CatalanitzadorMachineSetting `
        -Compliance $initialCompliance `
        -Caller $PSCmdlet `
        -CopyUserSettings $copyUserSettings `
        -ChangesAlreadyApplied (
            $languageResult.Changes.Count -gt 0 -or
            $userResult.Changes.Count -gt 0
        ) `
        -PrerequisiteSettingsDeclined (
            $languageResult.DeclinedSettings.Count -gt 0 -or
            $userResult.DeclinedSettings.Count -gt 0
        )

    $changes = @(
        @(
            $languageResult.Changes
            $userResult.Changes
            $machineResult.Changes
        ) | Select-Object -Unique
    )

    if ($WhatIfPreference) {
        return [pscustomobject]@{
            PSTypeName = 'Catalanitzador.Windows.Result'
            Changed = $false
            AlreadyCompliant = $false
            WhatIf = $true
            Message = "Simulació completada. No s'ha aplicat cap canvi."
            Changes = @()
            PlannedChanges = @(
                $initialCompliance.PendingSettings |
                    Select-Object -ExpandProperty Name
            )
            DeclinedSettings = @()
            DeferredSettings = @()
            Warnings = @($machineResult.Warnings)
            SignOutRequired = $false
            RestartRequired = $false
            InitialCompliance = $initialCompliance
            FinalCompliance = $initialCompliance
        }
    }

    $finalCompliance = Test-CatalanitzadorConfiguration @initialComplianceParameters
    $activationPendingNames = @()
    foreach ($settingName in @(
            'Culture'
            'DefaultInputMethod'
            'UserDisplayLanguage'
        )) {
        if ($userResult.Changes -contains $settingName) {
            $activationPendingNames += $settingName
        }
    }
    if ($languageResult.Changes -contains 'DisplayLanguagePackage') {
        $activationPendingNames += 'DisplayLanguagePackage'
    }
    if ($userResult.Changes -contains 'PreferredLanguageOrder') {
        $activationPendingNames += @(
            'PreferredLanguageOrder'
            'CatalanInputMethod'
        )
    }
    if ($machineResult.Changes -contains 'SystemPreferredUILanguage') {
        $activationPendingNames += 'SystemPreferredUILanguage'
    }
    if ($machineResult.Changes -contains 'SystemLocale') {
        $activationPendingNames += 'SystemLocale'
    }
    if ($languageResult.RestartRequired -and
        @(
            $languageResult.Changes |
                Where-Object { $_ -like 'LanguageCapability:*' }
        ).Count -gt 0) {
        $activationPendingNames += 'LanguageCapabilities'
    }
    $activationPendingNames = @($activationPendingNames | Select-Object -Unique)
    $declinedSettings = @(
        @(
            $languageResult.DeclinedSettings
            $userResult.DeclinedSettings
            $machineResult.DeclinedSettings
        ) | Select-Object -Unique
    )
    $deferredSettings = @(
        $machineResult.DeferredSettings |
            Select-Object -Unique
    )
    $deliberatelyPendingSettings = @(
        @(
            $declinedSettings
            $deferredSettings
        ) | Select-Object -Unique
    )
    $unexpectedPendingSettings = @(
        $finalCompliance.PendingSettings |
            Where-Object {
                $activationPendingNames -notcontains $_.Name -and
                $deliberatelyPendingSettings -notcontains $_.Name
            }
    )

    if ($unexpectedPendingSettings.Count -gt 0) {
        $pendingNames = @(
            $unexpectedPendingSettings |
                Select-Object -ExpandProperty Name
        )
        throw "No s'ha pogut verificar la configuració: $($pendingNames -join ', ')."
    }
    if ($initialCompliance.State.Platform.CanCopyUserSettingsToSystem -and
        (Test-CatalanitzadorPendingSystemCopy) -and
        $deliberatelyPendingSettings -notcontains 'WelcomeScreenAndNewUsers') {
        throw (
            "La còpia de la configuració internacional als comptes del " +
            'sistema i als usuaris nous continua pendent.'
        )
    }

    $warnings = @($machineResult.Warnings)
    if ($declinedSettings.Count -gt 0) {
        $warnings += (
            "Operacions omeses per decisió de l'usuari: " +
            "$($declinedSettings -join ', ')."
        )
    }
    if ($deferredSettings.Count -gt 0) {
        $warnings += (
            'Operacions ajornades fins que es confirmin els canvis previs: ' +
            "$($deferredSettings -join ', ')."
        )
    }

    [pscustomobject]@{
        PSTypeName = 'Catalanitzador.Windows.Result'
        Changed = ($changes.Count -gt 0)
        AlreadyCompliant = $false
        WhatIf = $false
        Message = if ($deliberatelyPendingSettings.Count -gt 0) {
            "S'han aplicat els canvis confirmats; algunes operacions s'han omès."
        }
        else {
            "La configuració en català s'ha aplicat correctament."
        }
        Changes = @($changes)
        PlannedChanges = @()
        DeclinedSettings = $declinedSettings
        DeferredSettings = $deferredSettings
        Warnings = $warnings
        SignOutRequired = (
            $languageResult.SignOutRequired -or
            $userResult.SignOutRequired -or
            $machineResult.SignOutRequired
        )
        RestartRequired = (
            $languageResult.RestartRequired -or
            $machineResult.RestartRequired
        )
        InitialCompliance = $initialCompliance
        FinalCompliance = $finalCompliance
    }
}

Export-ModuleMember -Function @(
    'Get-CatalanitzadorState'
    'Set-CatalanitzadorConfiguration'
    'Test-CatalanitzadorConfiguration'
)
