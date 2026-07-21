# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

$integrationEnabled = (
    $env:CATALANITZADOR_RUN_INTEGRATION -eq '1' -and
    $env:CATALANITZADOR_DISPOSABLE_VM -eq '1'
)

Describe 'Catalanitzador Windows disposable-VM integration' -Skip:(-not $integrationEnabled) {
    BeforeAll {
        $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $moduleManifest = Join-Path $repositoryRoot (
            'src\Catalanitzador.Windows\Catalanitzador.Windows.psd1'
        )
        Import-Module $moduleManifest -Force

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )) {
            throw 'Les proves d''integració requereixen una sessió elevada.'
        }
    }

    It 'converges once and is a no-op on the second execution' {
        $firstResult = Set-CatalanitzadorConfiguration -Confirm:$false
        $secondResult = Set-CatalanitzadorConfiguration -Confirm:$false

        $firstResult.AlreadyCompliant | Should -BeFalse
        $secondResult.Changed | Should -BeFalse
        $secondResult.AlreadyCompliant | Should -BeTrue
        $secondResult.Changes | Should -BeNullOrEmpty
    }
}
