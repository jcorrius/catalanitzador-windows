# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$moduleManifest = Join-Path $repositoryRoot (
    'src\Catalanitzador.Windows\Catalanitzador.Windows.psd1'
)
Import-Module $moduleManifest -Force

Describe 'Catalanitzador.Windows state marker security' {
    InModuleScope Catalanitzador.Windows {
        BeforeEach {
            $script:TestCommonApplicationData = Join-Path $TestDrive (
                'ProgramData'
            )
            New-Item `
                -ItemType Directory `
                -Path $script:TestCommonApplicationData `
                -Force |
                    Out-Null
            Mock Get-CatalanitzadorCommonApplicationDataPath {
                $script:TestCommonApplicationData
            }
        }

        It 'does not create state during a read-only pending check' {
            Test-CatalanitzadorPendingSystemCopy | Should -BeFalse
            Test-Path -LiteralPath (
                Join-Path $script:TestCommonApplicationData (
                    'Catalanitzador.Windows'
                )
            ) | Should -BeFalse
        }

        It 'rejects a state path with user-inheritable permissions' {
            $stateDirectory = Join-Path $script:TestCommonApplicationData (
                'Catalanitzador.Windows\State'
            )
            New-Item -ItemType Directory -Path $stateDirectory -Force |
                Out-Null
            [IO.File]::WriteAllText(
                (
                    Join-Path $stateDirectory (
                        'CopyUserInternationalSettings.pending'
                    )
                ),
                'pending',
                [Text.Encoding]::ASCII
            )

            {
                Test-CatalanitzadorPendingSystemCopy
            } | Should -Throw '*directori d''estat*'
        }

        It 'builds a protected administrators-and-system ACL' {
            $security = New-CatalanitzadorStateDirectorySecurity
            $security.AreAccessRulesProtected | Should -BeTrue
            $security.GetOwner(
                [Security.Principal.SecurityIdentifier]
            ).Value | Should -Be 'S-1-5-32-544'

            $rules = @(
                $security.GetAccessRules(
                    $true,
                    $true,
                    [Security.Principal.SecurityIdentifier]
                )
            )
            $rules | Should -HaveCount 2
            @($rules.IdentityReference.Value | Sort-Object) |
                Should -Be @('S-1-5-18', 'S-1-5-32-544')
            foreach ($rule in $rules) {
                $rule.FileSystemRights |
                    Should -Be (
                        [Security.AccessControl.FileSystemRights]::FullControl
                    )
                $rule.InheritanceFlags |
                    Should -Be (
                        [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
                        [Security.AccessControl.InheritanceFlags]::ObjectInherit
                    )
            }
        }
    }
}
