# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>

@{
    Severity = @(
        'Error'
        'Warning'
    )
    ExcludeRules = @(
        # Private helpers delegate confirmation to the public advanced function.
        'PSShouldProcess'
        'PSUseShouldProcessForStateChangingFunctions'
    )
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1')
        }
    }
}
