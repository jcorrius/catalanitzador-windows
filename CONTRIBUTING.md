# Com contribuir

Gràcies per ajudar a millorar Catalanitzador Windows.

## Abans de començar

- Obriu una incidència per als canvis de comportament importants.
- No proposeu modificacions directes del registre, automatització de la interfície gràfica ni paquets de llengua no oficials.
- Manteniu la compatibilitat amb Windows PowerShell 5.1 i els mecanismes documentats per Microsoft.
- No inclogueu dades personals, secrets, certificats de signatura ni registres de màquines reals.

## Flux de treball

1. Creeu una branca des de `main`.
2. Feu canvis petits i enfocats.
3. Instal·leu localment les versions fixades de Pester i PSScriptAnalyzer:

   ```powershell
   $requirements = Import-PowerShellDataFile .\build\requirements.psd1
   New-Item -ItemType Directory .\.psmodules -Force | Out-Null
   Save-Module Pester -RequiredVersion $requirements.Pester `
       -Path .\.psmodules -Repository PSGallery -Force
   Save-Module PSScriptAnalyzer -RequiredVersion $requirements.PSScriptAnalyzer `
       -Path .\.psmodules -Repository PSGallery -Force
   ```

4. Executeu la validació autoritativa amb Windows PowerShell 5.1:

   ```powershell
   powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned `
       -File .\build\Invoke-Tests.ps1
   ```

5. Obriu una sol·licitud de canvis amb una explicació del comportament i les
   proves.

Tots els canvis han de conservar el funcionament idempotent: una màquina que ja compleix la configuració no ha d'executar cap operació de modificació.

Les proves d'integració només es poden executar en una VM client descartable:

```powershell
$env:CATALANITZADOR_DISPOSABLE_VM = '1'
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    .\build\Invoke-Tests.ps1 -Integration
```
