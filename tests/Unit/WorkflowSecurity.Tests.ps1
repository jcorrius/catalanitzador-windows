# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:TestWorkflowFiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $repositoryRoot '.github\workflows') `
            -Filter '*.yml' `
            -File
    )
    $script:TestClaudeSettingsPath = Join-Path $repositoryRoot (
        '.claude\settings.json'
    )
    $script:TestAgentInstructionPaths = @(
        Join-Path $repositoryRoot 'AGENTS.md'
        Join-Path $repositoryRoot 'CLAUDE.md'
        Join-Path $repositoryRoot '.github\copilot-instructions.md'
        Join-Path $repositoryRoot (
            '.github\instructions\powershell.instructions.md'
        )
        Join-Path $repositoryRoot (
            '.github\instructions\tests.instructions.md'
        )
        Join-Path $repositoryRoot (
            '.github\instructions\workflows.instructions.md'
        )
        Join-Path $repositoryRoot (
            '.github\instructions\documentation.instructions.md'
        )
    )
}

Describe 'GitHub Actions security policy' {
    It 'pins every action to a full commit SHA' {
        foreach ($file in $script:TestWorkflowFiles) {
            $source = Get-Content -LiteralPath $file.FullName -Raw
            $usesLines = @(
                $source -split '\r?\n' |
                    Where-Object { $_ -match '^\s*uses:' }
            )
            foreach ($line in $usesLines) {
                $line | Should -Match (
                    'uses:\s+[^@\s]+@[0-9a-f]{40}\s+#\s+v'
                )
            }
        }

    }

    It 'does not use privileged untrusted-code triggers' {
        foreach ($file in $script:TestWorkflowFiles) {
            $source = Get-Content -LiteralPath $file.FullName -Raw
            $source | Should -Not -Match '(?m)^\s*pull_request_target:'
            $source | Should -Not -Match '(?m)^\s*workflow_run:'
        }
    }

    It 'declares read-only contents permission by default' {
        foreach ($file in $script:TestWorkflowFiles) {
            $source = Get-Content -LiteralPath $file.FullName -Raw
            $source | Should -Match (
                '(?ms)^permissions:\s*\r?\n\s+contents:\s+read'
            )
        }
    }

    It 'disables persisted checkout credentials' {
        foreach ($file in $script:TestWorkflowFiles) {
            $source = Get-Content -LiteralPath $file.FullName -Raw
            $checkoutCount = @(
                [regex]::Matches($source, 'uses:\s+actions/checkout@')
            ).Count
            $disabledCredentialCount = @(
                [regex]::Matches(
                    $source,
                    'persist-credentials:\s+false'
                )
            ).Count

            $disabledCredentialCount | Should -Be $checkoutCount
        }
    }

    It 'grants contents write only in the release workflow' {
        foreach ($file in $script:TestWorkflowFiles) {
            $source = Get-Content -LiteralPath $file.FullName -Raw
            if ($file.Name -eq 'release.yml') {
                $source | Should -Match 'contents:\s+write'
            }
            else {
                $source | Should -Not -Match 'contents:\s+write'
            }
        }
    }

    Describe 'Coding-agent security policy' {
        It 'commits guidance for the supported coding agents' {
            foreach ($path in $script:TestAgentInstructionPaths) {
                $path | Should -Exist
                (Get-Item -LiteralPath $path).Length | Should -BeGreaterThan 0
            }
        }

        It 'keeps Claude Code in prompted modes and protects sensitive files' {
            $settings = Get-Content `
                -LiteralPath $script:TestClaudeSettingsPath `
                -Raw |
                    ConvertFrom-Json

            $settings.permissions.defaultMode | Should -Be 'default'
            $settings.permissions.disableAutoMode | Should -Be 'disable'
            $settings.permissions.disableBypassPermissionsMode |
                Should -Be 'disable'
            @($settings.permissions.deny) |
                Should -Contain 'Read(/**/*.pfx)'
            @($settings.permissions.deny) |
                Should -Contain 'PowerShell(Invoke-Expression *)'
            @($settings.permissions.deny) |
                Should -Contain 'PowerShell(git push *--force*)'
            @($settings.permissions.ask) |
                Should -Contain 'PowerShell(git push *)'
        }
    }

    It 'publishes release assets through a verified draft' {
        $releaseWorkflowPath = @(
            $script:TestWorkflowFiles |
                Where-Object { $_.Name -eq 'release.yml' }
        ) | Select-Object -ExpandProperty FullName -First 1
        $releaseWorkflow = Get-Content `
            -LiteralPath $releaseWorkflowPath `
            -Raw

        $releaseWorkflow | Should -Match '(?s)gh release create .+--draft'
        $releaseWorkflow | Should -Match 'gh release upload'
        $releaseWorkflow | Should -Match 'gh release download'
        $releaseWorkflow | Should -Match '--clobber'
        $releaseWorkflow | Should -Match 'gh release view'
        $releaseWorkflow | Should -Match 'Get-FileHash'
        $releaseWorkflow | Should -Match (
            'The uploaded asset digest does not match'
        )
        $releaseWorkflow | Should -Match (
            'The release already exists and is not a draft'
        )
        $releaseWorkflow | Should -Match (
            'GH_REPO:\s*\$\{\{\s*github\.repository\s*\}\}'
        )
        $releaseWorkflow | Should -Match 'immutable-releases'
        $releaseWorkflow | Should -Match (
            '\$immutableReleasesEnabled -ne ''true'''
        )
        $releaseWorkflow | Should -Match (
            'Immutable releases must be enabled before publication'
        )
        $releaseWorkflow | Should -Match 'dist/\*\.ps1'
        $releaseWorkflow | Should -Match (
            'if \(\$assets\.Count -ne 3\)'
        )
        $releaseWorkflow | Should -Match (
            '(?s)gh release edit .+--draft=false'
        )
    }

    It 'does not interpolate event payload fields into workflow scripts' {
        foreach ($file in $script:TestWorkflowFiles) {
            $source = Get-Content -LiteralPath $file.FullName -Raw
            $source | Should -Not -Match '\$\{\{\s*github\.event\.'
        }
    }
}
