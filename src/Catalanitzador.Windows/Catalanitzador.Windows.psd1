# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

@{
    RootModule = 'Catalanitzador.Windows.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'f2ed23a8-ea3d-45bd-b794-cb908c70ea19'
    Author = 'Jesús Corrius'
    CompanyName = 'Softcatalà'
    Copyright = 'Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>'
    Description = 'Configura Windows 10 22H2 i Windows 11 en català mitjançant interfícies oficials de Microsoft.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop')
    FunctionsToExport = @(
        'Get-CatalanitzadorState'
        'Set-CatalanitzadorConfiguration'
        'Test-CatalanitzadorConfiguration'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @(
                'Catalan'
                'Windows'
                'Language'
                'Localization'
                'International'
            )
            LicenseUri = 'https://github.com/jcorrius/catalanitzador-windows/blob/main/LICENSE'
            ProjectUri = 'https://github.com/jcorrius/catalanitzador-windows'
        }
    }
}
