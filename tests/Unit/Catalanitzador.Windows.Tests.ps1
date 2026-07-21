# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$moduleManifest = Join-Path $repositoryRoot (
    'src\Catalanitzador.Windows\Catalanitzador.Windows.psd1'
)
Import-Module $moduleManifest -Force
Import-Module International -Force

Describe 'Catalanitzador.Windows module' {
    InModuleScope Catalanitzador.Windows {
        BeforeAll {
            if (-not (Get-Command Get-InstalledLanguage -ErrorAction SilentlyContinue)) {
                function Get-InstalledLanguage {
                    [CmdletBinding()]
                    param()
                }
            }
            if (-not (Get-Command Install-Language -ErrorAction SilentlyContinue)) {
                function Install-Language {
                    [CmdletBinding()]
                    param(
                        [string]$Language,
                        [switch]$CopyToSettings
                    )

                    $null = $Language
                    $null = $CopyToSettings
                }
            }
            if (-not (Get-Command Get-SystemPreferredUILanguage -ErrorAction SilentlyContinue)) {
                function Get-SystemPreferredUILanguage {
                    [CmdletBinding()]
                    param()
                }
            }
            if (-not (Get-Command Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue)) {
                function Set-SystemPreferredUILanguage {
                    [CmdletBinding()]
                    param(
                        [string]$Language
                    )

                    $null = $Language
                }
            }
            if (-not (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue)) {
                function Copy-UserInternationalSettingsToSystem {
                    [CmdletBinding()]
                    param(
                        [bool]$WelcomeScreen,
                        [bool]$NewUser
                    )

                    $null = $WelcomeScreen
                    $null = $NewUser
                }
            }

            function New-TestLanguage {
                param(
                    [Parameter(Mandatory)]
                    [string]$LanguageTag,

                    [Parameter()]
                    [string[]]$InputMethodTips = @(),

                    [Parameter()]
                    [bool]$Spellchecking = $true,

                    [Parameter()]
                    [bool]$Handwriting = $false,

                    [Parameter()]
                    [string]$Marker
                )

                $language = New-Object `
                    -TypeName Microsoft.InternationalSettings.Commands.WinUserLanguage `
                    -ArgumentList $LanguageTag
                $language.InputMethodTips.Clear()
                foreach ($tip in $InputMethodTips) {
                    $language.InputMethodTips.Add($tip)
                }
                $language.Spellchecking = $Spellchecking
                $language.Handwriting = $Handwriting
                $language | Add-Member `
                    -MemberType NoteProperty `
                    -Name Marker `
                    -Value $Marker `
                    -Force
                return $language
            }

            function New-TestCapability {
                param(
                    [Parameter(Mandatory)]
                    [ValidateSet(
                        'Basic',
                        'OCR',
                        'Handwriting',
                        'TextToSpeech',
                        'Speech'
                    )]
                    [string]$Kind,

                    [Parameter()]
                    [ValidateSet('Installed', 'NotPresent')]
                    [string]$State = 'Installed'
                )

                [pscustomobject]@{
                    Name = "Language.$Kind~~~ca-ES~0.0.1.0"
                    State = $State
                }
            }

            function Reset-TestState {
                $script:TestBuild = 22631
                $script:TestEdition = 'Professional'
                $script:TestProductType = 'WorkStation'
                $script:TestMissingCommand = $null
                $script:TestLanguagePresent = $true
                $script:TestLanguagePacks = @('LpCab', 'LXP')
                $script:TestCapabilities = @(
                    New-TestCapability -Kind Basic
                    New-TestCapability -Kind OCR
                    New-TestCapability -Kind Handwriting
                    New-TestCapability -Kind TextToSpeech
                    New-TestCapability -Kind Speech
                )
                $script:TestUserLanguages = @(
                    New-TestLanguage `
                        -LanguageTag 'ca-ES' `
                        -InputMethodTips @('0403:0000040A') `
                        -Marker 'catalan'
                    New-TestLanguage `
                        -LanguageTag 'en-US' `
                        -InputMethodTips @('0409:00000409') `
                        -Marker 'fallback'
                )
                $script:TestUiOverride = 'ca-ES'
                $script:TestDefaultInput = '0403:0000040A'
                $script:TestCulture = 'ca-ES'
                $script:TestSystemLocale = 'ca-ES'
                $script:TestSystemUi = 'ca-ES'
                $script:TestGeoId = 217
                $script:CapturedLanguageList = $null
                $script:CapabilityInstallOrder = @()
                $script:TestPendingSystemCopy = $false
            }

            function Set-TestNonCompliantState {
                $script:TestLanguagePresent = $false
                $script:TestLanguagePacks = @()
                $script:TestCapabilities = @(
                    New-TestCapability -Kind Basic -State NotPresent
                    New-TestCapability -Kind OCR -State NotPresent
                    New-TestCapability -Kind Handwriting -State NotPresent
                    New-TestCapability -Kind TextToSpeech -State NotPresent
                    New-TestCapability -Kind Speech -State NotPresent
                )
                $script:TestUserLanguages = @(
                    New-TestLanguage `
                        -LanguageTag 'en-US' `
                        -InputMethodTips @(
                            '0409:00000409'
                            '0409:00010409'
                        ) `
                        -Marker 'fallback'
                )
                $script:TestUiOverride = 'en-US'
                $script:TestDefaultInput = '0409:00000409'
                $script:TestCulture = 'en-US'
                $script:TestSystemLocale = 'en-US'
                $script:TestSystemUi = 'en-US'
                $script:TestGeoId = 244
            }
        }

        BeforeEach {
            Reset-TestState

            Mock Get-ComputerInfo {
                [pscustomobject]@{
                    WindowsProductName = if ($script:TestBuild -ge 22000) {
                        'Windows 11 Pro'
                    }
                    else {
                        'Windows 10 Pro'
                    }
                    WindowsEditionId = $script:TestEdition
                    OsBuildNumber = [string]$script:TestBuild
                    OsArchitecture = '64-bit'
                    OsProductType = $script:TestProductType
                }
            }

            Mock Get-Command {
                param($Name)

                if ([string]$Name -eq [string]$script:TestMissingCommand) {
                    return $null
                }

                [pscustomobject]@{
                    Name = [string]$Name
                    CommandType = 'Cmdlet'
                }
            }

            Mock Get-InstalledLanguage {
                if ($script:TestLanguagePresent) {
                    [pscustomobject]@{
                        LanguageId = 'ca-ES'
                        LanguagePacks = $script:TestLanguagePacks
                        LanguageFeatures = @('BasicTyping')
                    }
                }

                [pscustomobject]@{
                    LanguageId = 'en-US'
                    LanguagePacks = @('LpCab')
                    LanguageFeatures = @('BasicTyping')
                }
            }

            Mock Get-WindowsCapability {
                $script:TestCapabilities
                [pscustomobject]@{
                    Name = 'Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0'
                    State = 'Installed'
                }
                [pscustomobject]@{
                    Name = 'Language.Basic~~~fr-FR~0.0.1.0'
                    State = 'Installed'
                }
            }

            Mock Get-WinUserLanguageList {
                $script:TestUserLanguages
            }
            Mock Get-WinUILanguageOverride {
                [Globalization.CultureInfo]::GetCultureInfo(
                    $script:TestUiOverride
                )
            }
            Mock Get-WinDefaultInputMethodOverride {
                if ($null -eq $script:TestDefaultInput) {
                    return $null
                }

                [pscustomobject]@{
                    InputMethodTip = $script:TestDefaultInput
                }
            }
            Mock Get-Culture {
                [Globalization.CultureInfo]::GetCultureInfo(
                    $script:TestCulture
                )
            }
            Mock Get-WinSystemLocale {
                [Globalization.CultureInfo]::GetCultureInfo(
                    $script:TestSystemLocale
                )
            }
            Mock Get-WinHomeLocation {
                [pscustomobject]@{
                    GeoId = $script:TestGeoId
                }
            }
            Mock Get-SystemPreferredUILanguage {
                $script:TestSystemUi
            }

            Mock Install-Language {
                $script:TestLanguagePresent = $true
                $script:TestLanguagePacks = @('LpCab', 'LXP')
            }
            Mock Add-WindowsCapability {
                param($Name)

                $script:CapabilityInstallOrder += $Name
                foreach ($capability in $script:TestCapabilities) {
                    if ($capability.Name -eq $Name) {
                        $capability.State = 'Installed'
                    }
                }

                [pscustomobject]@{
                    RestartNeeded = $false
                }
            }
            Mock New-WinUserLanguageList {
                param($Language)

                $languageList = New-Object (
                    'Collections.Generic.List[' +
                    'Microsoft.InternationalSettings.Commands.WinUserLanguage]'
                )
                $languageList.Add(
                    (New-TestLanguage `
                        -LanguageTag $Language `
                        -InputMethodTips @('0403:0000040A') `
                        -Marker 'new-catalan')
                )
                $languageList[0] | Add-Member `
                    -MemberType NoteProperty `
                    -Name Marker `
                    -Value 'new-catalan' `
                    -Force
                return ,$languageList
            }
            Mock Set-WinUserLanguageList {
                param($LanguageList)

                $script:CapturedLanguageList = @($LanguageList)
                $script:TestUserLanguages = @($LanguageList)
            }
            Mock Set-WinDefaultInputMethodOverride {
                param($InputTip)
                $script:TestDefaultInput = $InputTip
            }
            Mock Set-WinUILanguageOverride {
                param($Language)
                $script:TestUiOverride = $Language
            }
            Mock Set-Culture {
                param($CultureInfo)
                $script:TestCulture = [string]$CultureInfo
            }
            Mock Set-WinHomeLocation {
                param($GeoId)
                $script:TestGeoId = $GeoId
            }
            Mock Set-SystemPreferredUILanguage {
                param($Language)
                $script:TestSystemUi = $Language
            }
            Mock Set-WinSystemLocale {
                param($SystemLocale)
                $script:TestSystemLocale = [string]$SystemLocale
            }
            Mock Copy-UserInternationalSettingsToSystem {}
            Mock Test-CatalanitzadorPendingSystemCopy {
                $script:TestPendingSystemCopy
            }
            Mock Set-CatalanitzadorPendingSystemCopy {
                $script:TestPendingSystemCopy = $true
            }
            Mock Clear-CatalanitzadorPendingSystemCopy {
                $script:TestPendingSystemCopy = $false
            }
        }

        Context 'platform validation' {
            It 'identifies Windows 10 by build number rather than product name' {
                $script:TestBuild = 19045

                $platform = Get-CatalanitzadorPlatform

                $platform.Family | Should -Be 'Windows 10 22H2'
                $platform.CanCopyUserSettingsToSystem | Should -BeFalse
            }

            It 'rejects unsupported Windows builds' {
                $script:TestBuild = 19044

                { Get-CatalanitzadorPlatform } |
                    Should -Throw '*no és compatible*'
            }

            It 'rejects Windows Server' {
                $script:TestProductType = 'Server'

                { Get-CatalanitzadorPlatform } |
                    Should -Throw '*edicions client*'
            }

            It 'rejects single-language editions' {
                $script:TestEdition = 'CoreSingleLanguage'

                { Get-CatalanitzadorPlatform } |
                    Should -Throw '*no permet afegir*'
            }

            It 'requires the Windows 11 copy-to-system cmdlet' {
                $script:TestMissingCommand = (
                    'Copy-UserInternationalSettingsToSystem'
                )

                { Get-CatalanitzadorPlatform } |
                    Should -Throw '*Copy-UserInternationalSettingsToSystem*'
            }

            It 'requires every mutating cmdlet used by convergence' {
                $script:TestMissingCommand = 'Set-WinUILanguageOverride'

                { Get-CatalanitzadorPlatform } |
                    Should -Throw '*Set-WinUILanguageOverride*'
            }

            It 'does not require the Windows 11 copy cmdlet on Windows 10' {
                $script:TestBuild = 19045
                $script:TestMissingCommand = (
                    'Copy-UserInternationalSettingsToSystem'
                )

                { Get-CatalanitzadorPlatform } | Should -Not -Throw
            }
        }

        Context 'state and compliance' {
            It 'filters and orders only supported Catalan capabilities' {
                $script:TestCapabilities = @(
                    New-TestCapability -Kind Speech
                    New-TestCapability -Kind Basic
                    New-TestCapability -Kind OCR
                )

                $state = Get-CatalanitzadorState

                $state.Language.Capabilities.Kind |
                    Should -Be @('Basic', 'OCR', 'Speech')
            }

            It 'normalizes collection objects emitted without enumeration' {
                Mock Get-InstalledLanguage {
                    Write-Output -InputObject @(
                            [pscustomobject]@{
                                LanguageId = 'ca-ES'
                                LanguagePacks = @('LpCab')
                                LanguageFeatures = @('BasicTyping')
                            }
                            [pscustomobject]@{
                                LanguageId = 'en-US'
                                LanguagePacks = @('LpCab')
                                LanguageFeatures = @('BasicTyping')
                            }
                        ) `
                        -NoEnumerate
                }
                Mock Get-WindowsCapability {
                    Write-Output `
                        -InputObject @($script:TestCapabilities) `
                        -NoEnumerate
                }
                Mock Get-WinUserLanguageList {
                    Write-Output `
                        -InputObject @($script:TestUserLanguages) `
                        -NoEnumerate
                }

                $state = Get-CatalanitzadorState

                $state.Language.IsPresent | Should -BeTrue
                $state.Language.LanguagePacks | Should -Contain 'LpCab'
                $state.Language.Capabilities | Should -HaveCount 5
                $state.User.Languages | Should -HaveCount 2
                $state.User.Languages[0].LanguageTag | Should -Be 'ca-ES'
            }

            It 'reports a fully compliant system' {
                $compliance = Test-CatalanitzadorConfiguration

                $compliance.IsCompliant | Should -BeTrue
                $compliance.PendingSettings | Should -BeNullOrEmpty
                $compliance.PendingSystemCopy | Should -BeFalse
            }

            It 'reports a pending Windows 11 system copy as noncompliant' {
                $script:TestPendingSystemCopy = $true

                $compliance = Test-CatalanitzadorConfiguration

                $compliance.IsCompliant | Should -BeFalse
                $compliance.PendingSystemCopy | Should -BeTrue
                $compliance.PendingSettings.Name |
                    Should -Contain 'WelcomeScreenAndNewUsers'
            }

            It 'accepts the neutral Catalan tag returned by Windows 10' {
                $script:TestUserLanguages[0] = New-TestLanguage `
                    -LanguageTag 'ca' `
                    -InputMethodTips @('0403:0000040A') `
                    -Marker 'windows-10-catalan'
                $script:TestUiOverride = 'ca'
                $script:TestSystemLocale = 'ca'
                $script:TestSystemUi = 'ca'

                $compliance = Test-CatalanitzadorConfiguration

                $compliance.IsCompliant | Should -BeTrue
                $compliance.PendingSettings | Should -BeNullOrEmpty
            }

            It 'accepts worldwide optional home locations' {
                foreach ($geoId in @(8, 84, 118, 217, 303)) {
                    Test-CatalanitzadorGeoId -GeoId $geoId |
                        Should -BeTrue
                    {
                        Test-CatalanitzadorConfiguration `
                            -HomeLocationGeoId $geoId
                    } | Should -Not -Throw
                }
            }

            It 'rejects an unknown home-location GeoID before changing state' {
                {
                    Set-CatalanitzadorConfiguration `
                        -HomeLocationGeoId ([int]::MaxValue)
                } | Should -Throw '*no correspon*'

                Assert-MockCalled Install-Language -Times 0 -Exactly
                Assert-MockCalled Set-WinHomeLocation -Times 0 -Exactly
            }
        }

        Context 'idempotency' {
            It 'returns a successful no-op without invoking any mutating command' {
                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeFalse
                $result.AlreadyCompliant | Should -BeTrue
                $result.Message | Should -Match 'No cal fer cap canvi'

                Assert-MockCalled Install-Language -Times 0 -Exactly
                Assert-MockCalled Add-WindowsCapability -Times 0 -Exactly
                Assert-MockCalled New-WinUserLanguageList -Times 0 -Exactly
                Assert-MockCalled Set-WinUserLanguageList -Times 0 -Exactly
                Assert-MockCalled Set-WinDefaultInputMethodOverride `
                    -Times 0 `
                    -Exactly
                Assert-MockCalled Set-WinUILanguageOverride -Times 0 -Exactly
                Assert-MockCalled Set-Culture -Times 0 -Exactly
                Assert-MockCalled Set-WinHomeLocation -Times 0 -Exactly
                Assert-MockCalled Set-SystemPreferredUILanguage `
                    -Times 0 `
                    -Exactly
                Assert-MockCalled Set-WinSystemLocale -Times 0 -Exactly
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 0 `
                    -Exactly
            }

            It 'does not invoke mutating commands with WhatIf' {
                Set-TestNonCompliantState

                $result = Set-CatalanitzadorConfiguration -WhatIf

                $result.WhatIf | Should -BeTrue
                $result.Changed | Should -BeFalse
                $result.PlannedChanges | Should -Not -BeNullOrEmpty
                Assert-MockCalled Install-Language -Times 0 -Exactly
                Assert-MockCalled Add-WindowsCapability -Times 0 -Exactly
                Assert-MockCalled Set-WinUserLanguageList -Times 0 -Exactly
                Assert-MockCalled Set-SystemPreferredUILanguage `
                    -Times 0 `
                    -Exactly
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 0 `
                    -Exactly
            }
        }

        Context 'configuration convergence' {
            It 'converges Windows 11 and preserves fallback language objects' {
                Set-TestNonCompliantState
                $fallbackLanguage = $script:TestUserLanguages[0]

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                $result.RestartRequired | Should -BeTrue
                $result.SignOutRequired | Should -BeTrue
                $script:CapturedLanguageList[0].LanguageTag |
                    Should -Be 'ca-ES'
                [object]::ReferenceEquals(
                    $script:CapturedLanguageList[1],
                    $fallbackLanguage
                ) | Should -BeTrue
                $script:CapturedLanguageList[1].InputMethodTips |
                    Should -Contain '0409:00010409'
                Assert-MockCalled Install-Language -Times 1 -Exactly `
                    -ParameterFilter {
                        $Language -eq 'ca-ES' -and -not $CopyToSettings
                    }
                Assert-MockCalled Add-WindowsCapability -Times 5 -Exactly
                $script:CapabilityInstallOrder | Should -Be @(
                    'Language.Basic~~~ca-ES~0.0.1.0'
                    'Language.OCR~~~ca-ES~0.0.1.0'
                    'Language.Handwriting~~~ca-ES~0.0.1.0'
                    'Language.TextToSpeech~~~ca-ES~0.0.1.0'
                    'Language.Speech~~~ca-ES~0.0.1.0'
                )
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 1 `
                    -Exactly `
                    -ParameterFilter {
                        $WelcomeScreen -and $NewUser
                    }

                $secondResult = Set-CatalanitzadorConfiguration
                $secondResult.Changed | Should -BeFalse
                $secondResult.AlreadyCompliant | Should -BeTrue
                Assert-MockCalled Install-Language -Times 1 -Exactly
                Assert-MockCalled Add-WindowsCapability -Times 5 -Exactly
                Assert-MockCalled Set-WinUserLanguageList -Times 1 -Exactly
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 1 `
                    -Exactly
            }

            It 'uses CopyToSettings on Windows 10 and reports its limitation' {
                Set-TestNonCompliantState
                $script:TestBuild = 19045
                $script:TestMissingCommand = (
                    'Copy-UserInternationalSettingsToSystem'
                )

                $result = Set-CatalanitzadorConfiguration

                Assert-MockCalled Install-Language -Times 1 -Exactly `
                    -ParameterFilter {
                        $Language -eq 'ca-ES' -and $CopyToSettings
                    }
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 0 `
                    -Exactly
                $result.Warnings | Should -HaveCount 1
                $result.Warnings[0] | Should -Match 'Windows 10'
            }

            It 'installs only capabilities that are available and missing' {
                $script:TestCapabilities = @(
                    New-TestCapability -Kind Basic
                    New-TestCapability -Kind OCR -State NotPresent
                )

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                Assert-MockCalled Install-Language -Times 0 -Exactly
                Assert-MockCalled Add-WindowsCapability -Times 1 -Exactly `
                    -ParameterFilter {
                        $Name -eq 'Language.OCR~~~ca-ES~0.0.1.0'
                    }
            }

            It 'preserves an existing Catalan language object when reordering' {
                $fallbackLanguage = New-TestLanguage `
                    -LanguageTag 'en-US' `
                    -InputMethodTips @('0409:00000409') `
                    -Marker 'fallback'
                $catalanLanguage = New-TestLanguage `
                    -LanguageTag 'ca-ES' `
                    -InputMethodTips @(
                        '0403:0000040A'
                        '0403:0001040A'
                    ) `
                    -Handwriting $true `
                    -Marker 'existing-catalan'
                $script:TestUserLanguages = @(
                    $fallbackLanguage
                    $catalanLanguage
                )

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                [object]::ReferenceEquals(
                    $script:CapturedLanguageList[0],
                    $catalanLanguage
                ) | Should -BeTrue
                $script:CapturedLanguageList[0].InputMethodTips |
                    Should -Contain '0403:0001040A'
                $script:CapturedLanguageList[0].Handwriting |
                    Should -BeTrue
                Assert-MockCalled Install-Language -Times 0 -Exactly
                Assert-MockCalled Add-WindowsCapability -Times 0 -Exactly
            }

            It 'preserves the current default input method unless one is requested' {
                Set-TestNonCompliantState

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                $script:TestDefaultInput | Should -Be '0409:00000409'
                $result.Changes | Should -Not -Contain 'DefaultInputMethod'
                Assert-MockCalled Set-WinDefaultInputMethodOverride `
                    -Times 0 `
                    -Exactly
            }

            It 'pins the effective default before reordering when no override exists' {
                Set-TestNonCompliantState
                $script:TestDefaultInput = $null

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                $script:TestDefaultInput | Should -Be '0409:00000409'
                $result.Changes | Should -Contain 'DefaultInputMethod'
                Assert-MockCalled Set-WinDefaultInputMethodOverride `
                    -Times 1 `
                    -Exactly `
                    -ParameterFilter {
                        $InputTip -eq '0409:00000409'
                    }
            }

            It 'sets an explicitly requested installed input method' {
                Set-TestNonCompliantState
                $script:TestUserLanguages += New-TestLanguage `
                    -LanguageTag 'fr-FR' `
                    -InputMethodTips @('040C:0000040C') `
                    -Marker 'french'

                $result = Set-CatalanitzadorConfiguration `
                    -DefaultInputMethodTip '040c:0000040c'

                $result.Changed | Should -BeTrue
                $script:TestDefaultInput | Should -Be '040C:0000040C'
                $result.Changes | Should -Contain 'DefaultInputMethod'
                Assert-MockCalled Set-WinDefaultInputMethodOverride `
                    -Times 1 `
                    -Exactly `
                    -ParameterFilter {
                        $InputTip -eq '040C:0000040C'
                    }
            }

            It 'rejects an unavailable requested input method before mutation' {
                Set-TestNonCompliantState

                {
                    Set-CatalanitzadorConfiguration `
                        -DefaultInputMethodTip '0410:00000410'
                } | Should -Throw '*no està instal·lat*'

                Assert-MockCalled Install-Language -Times 0 -Exactly
                Assert-MockCalled Add-WindowsCapability -Times 0 -Exactly
                Assert-MockCalled Set-WinUserLanguageList -Times 0 -Exactly
                Assert-MockCalled Set-WinDefaultInputMethodOverride `
                    -Times 0 `
                    -Exactly
            }

            It 'changes home location only when explicitly requested' {
                $script:TestGeoId = 244

                $result = Set-CatalanitzadorConfiguration `
                    -HomeLocationGeoId 217

                $result.Changed | Should -BeTrue
                $script:TestGeoId | Should -Be 217
                Assert-MockCalled Set-WinHomeLocation -Times 1 -Exactly `
                    -ParameterFilter { $GeoId -eq 217 }
                Assert-MockCalled Set-Culture -Times 0 -Exactly
                Assert-MockCalled Set-WinSystemLocale -Times 0 -Exactly
            }

            It 'propagates a capability restart requirement' {
                $script:TestCapabilities = @(
                    New-TestCapability -Kind Basic
                    New-TestCapability -Kind OCR -State NotPresent
                )
                Mock Add-WindowsCapability {
                    param($Name)

                    foreach ($capability in $script:TestCapabilities) {
                        if ($capability.Name -eq $Name) {
                            $capability.State = 'Installed'
                        }
                    }

                    [pscustomobject]@{
                        RestartNeeded = $true
                    }
                }

                $result = Set-CatalanitzadorConfiguration

                $result.RestartRequired | Should -BeTrue
            }

            It 'requires a restart after installing the display language' {
                $script:TestLanguagePresent = $false
                $script:TestLanguagePacks = @()

                $result = Set-CatalanitzadorConfiguration

                $result.RestartRequired | Should -BeTrue
                $result.Changes | Should -Contain 'DisplayLanguagePackage'
            }

            It 'allows documented settings to remain pending until restart' {
                Set-TestNonCompliantState
                Mock Install-Language {}
                Mock Set-SystemPreferredUILanguage {}
                Mock Set-WinSystemLocale {}

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                $result.RestartRequired | Should -BeTrue
                $result.FinalCompliance.PendingSettings.Name |
                    Should -Contain 'DisplayLanguagePackage'
                $result.FinalCompliance.PendingSettings.Name |
                    Should -Contain 'SystemPreferredUILanguage'
                $result.FinalCompliance.PendingSettings.Name |
                    Should -Contain 'SystemLocale'
            }

            It 'does not treat an unperformed user setting as activation-pending' {
                $script:TestCulture = 'en-US'
                Mock Set-CatalanitzadorUserSetting {
                    [pscustomobject]@{
                        Changes = @()
                        DeclinedSettings = @()
                        SignOutRequired = $false
                    }
                }

                {
                    Set-CatalanitzadorConfiguration
                } | Should -Throw '*Culture*'
            }

            It 'returns partial success when a confirmation is declined' {
                Set-TestNonCompliantState
                Mock Test-CatalanitzadorShouldProcess {
                    param($Caller, $Target, $Action)

                    $null = $Caller
                    $null = $Action
                    return $Target -ne "Format regional de l'usuari actual"
                }

                $result = Set-CatalanitzadorConfiguration

                $result.Changed | Should -BeTrue
                $result.AlreadyCompliant | Should -BeFalse
                $result.DeclinedSettings | Should -Contain 'Culture'
                $result.DeferredSettings |
                    Should -Contain 'WelcomeScreenAndNewUsers'
                $result.Warnings -join ' ' | Should -Match 'decisió de l''usuari'
                $result.FinalCompliance.PendingSettings.Name |
                    Should -Contain 'Culture'
                $script:TestPendingSystemCopy | Should -BeTrue
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 0 `
                    -Exactly
            }

            It 'retries a failed Windows 11 copy on the next run' {
                Set-TestNonCompliantState
                $script:CopyAttemptCount = 0
                Mock Copy-UserInternationalSettingsToSystem {
                    $script:CopyAttemptCount++
                    if ($script:CopyAttemptCount -eq 1) {
                        throw 'Copy failure'
                    }
                }

                {
                    Set-CatalanitzadorConfiguration
                } | Should -Throw '*Copy failure*'
                $script:TestPendingSystemCopy | Should -BeTrue

                $retryResult = Set-CatalanitzadorConfiguration

                $retryResult.Changed | Should -BeTrue
                $retryResult.Changes |
                    Should -Contain 'WelcomeScreenAndNewUsers'
                $script:TestPendingSystemCopy | Should -BeFalse
                Assert-MockCalled Copy-UserInternationalSettingsToSystem `
                    -Times 2 `
                    -Exactly
            }

            It 'records a pending copy before changing user settings' {
                Set-TestNonCompliantState
                $script:PendingSeenBeforeUserMutation = $false
                Mock Set-WinUserLanguageList {
                    param($LanguageList)

                    $script:PendingSeenBeforeUserMutation = (
                        $script:TestPendingSystemCopy
                    )
                    $script:CapturedLanguageList = @($LanguageList)
                    $script:TestUserLanguages = @($LanguageList)
                }

                Set-CatalanitzadorConfiguration | Out-Null

                $script:PendingSeenBeforeUserMutation | Should -BeTrue
            }

            It 'records a pending copy before changing system settings' {
                $script:TestSystemUi = 'en-US'
                $script:PendingSeenBeforeSystemMutation = $false
                Mock Set-SystemPreferredUILanguage {
                    param($Language)

                    $script:PendingSeenBeforeSystemMutation = (
                        $script:TestPendingSystemCopy
                    )
                    $script:TestSystemUi = $Language
                }

                Set-CatalanitzadorConfiguration | Out-Null

                $script:PendingSeenBeforeSystemMutation | Should -BeTrue
            }

            It 'surfaces a servicing failure and stops convergence' {
                Set-TestNonCompliantState
                Mock Add-WindowsCapability {
                    throw 'Windows Update failure'
                }

                {
                    Set-CatalanitzadorConfiguration
                } | Should -Throw '*Windows Update failure*'

                Assert-MockCalled Set-WinUserLanguageList -Times 0 -Exactly
                Assert-MockCalled Set-SystemPreferredUILanguage `
                    -Times 0 `
                    -Exactly
            }
        }
    }
}
