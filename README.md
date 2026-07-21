# Catalanitzador Windows

Configura Windows 10 22H2 i Windows 11 en català amb paquets, capacitats i
ordres oficials de Microsoft. No modifica directament el registre, no automatitza
la interfície gràfica i no elimina cap llengua ni teclat existent.

El projecte és programari lliure sota la llicència MIT:
`Copyright (c) 2026 Jesús Corrius <jesus@softcatala.org>`.

## Què configura

| Àmbit | Comportament |
| --- | --- |
| Paquet de visualització | Instal·la el paquet oficial `ca-ES` amb `Install-Language`. |
| Capacitats de llengua | Instal·la, si Microsoft les publica per a la versió de Windows, Basic, OCR, escriptura a mà, text a veu i veu. |
| Preferència d'aplicacions i webs | Posa `ca-ES` al principi de la llista de llengües de Windows i conserva totes les alternatives. |
| Interfície de l'usuari | Estableix `ca-ES` com a llengua de visualització. |
| Formats regionals | Estableix la cultura `ca-ES`. |
| Teclat | Afegeix el perfil oficial català amb teclat espanyol `0403:0000040A`, però conserva el mètode predeterminat actual si no se'n demana un altre. |
| Sistema | Estableix el català com a llengua d'interfície preferida i configuració regional per a aplicacions no Unicode. |
| Pantalla de benvinguda i usuaris nous | A Windows 11, copia la configuració internacional amb `Copy-UserInternationalSettingsToSystem`. |
| Ubicació principal | No la canvia per defecte. Es pot indicar explícitament amb qualsevol GeoID que Windows reconegui. |

La llista de llengües de Windows és la preferència admesa pel sistema que poden
consultar les aplicacions i els llocs web. Els navegadors poden mantenir, a més,
preferències pròpies de perfil.

El català no determina cap país, disposició física de teclat ni fus horari.
L'eina funciona igual per a usuaris d'Andorra, França, Itàlia, Espanya o
qualsevol altra regió: conserva aquests valors si no es demana explícitament un
canvi compatible.

## Què no fa

- No canvia el fus horari.
- No canvia la ubicació principal si no es demana explícitament.
- No canvia altres usuaris existents.
- No elimina llengües, paquets ni teclats.
- No modifica polítiques empresarials de Windows Update o del navegador.
- No canvia l'opció de privadesa que permet als llocs web consultar la llista de
  llengües.
- No reinicia ni tanca la sessió automàticament.
- No recull telemetria ni envia registres.
- No admet Windows Server, Windows Home Single Language ni edicions Country
  Specific.

## Requisits

- Windows 11, recomanat, o Windows 10 22H2 compilació `19045`.
- Un compte que sigui membre del grup local **Administradors**.
- Accés als orígens de Windows Update autoritzats per l'organització.
- Windows PowerShell 5.1. Si s'inicia des de PowerShell 7 o un procés de 32 bits,
  el llançador es normalitza de manera segura al Windows PowerShell natiu de
  64 bits.

Windows 10 22H2 ja no té suport general de Microsoft. La compatibilitat d'aquest
projecte s'adreça a equips amb ESU o escenaris administrats que encara utilitzen
la compilació 19045. S'han investigat totes les versions de Windows 10, però les
anteriors no s'accepten sense una ruta oficial completa i una validació real.
Consulteu la [matriu completa](docs/compatibility.md).

## Execució en una sola ordre

Obriu un terminal de PowerShell i enganxeu aquesta única ordre. Està fixada a
`v0.1.0` i a la suma exacta del seu ZIP; no descarrega mai codi directament a
`Invoke-Expression`.

```powershell
& { $ErrorActionPreference = 'Stop'; $Repo = 'jcorrius/catalanitzador-windows'; $Version = 'v0.1.0'; $ZipName = "Catalanitzador.Windows-$Version.zip"; $ExpectedHash = 'BA957FEDAB58943AB4D8515EB848AD25863F5A40CBF1F75553DE6DAD03C363CC'; $Directory = Join-Path $env:TEMP ("Catalanitzador-$Version-" + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $Directory | Out-Null; try { $Zip = Join-Path $Directory $ZipName; Invoke-WebRequest -UseBasicParsing "https://github.com/$Repo/releases/download/$Version/$ZipName" -OutFile $Zip; if ((Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash -ine $ExpectedHash) { throw 'La suma SHA-256 del paquet no coincideix.' }; if (Get-Command gh -ErrorAction SilentlyContinue) { & gh attestation verify $Zip --repo $Repo; if ($LASTEXITCODE -ne 0) { throw 'La certificació de GitHub no és vàlida.' } } else { Write-Warning 'GitHub CLI no està instal·lat: s''ha verificat la suma fixada, però no la certificació.' }; Expand-Archive -LiteralPath $Zip -DestinationPath $Directory; $Package = Join-Path $Directory "Catalanitzador.Windows-$Version"; Get-ChildItem -LiteralPath $Package -Recurse -File | Unblock-File; & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $Package 'Invoke-Catalanitzador.ps1'); $ExitCode = $LASTEXITCODE; if ($ExitCode -notin @(0, 3010)) { throw "El Catalanitzador ha acabat amb el codi $ExitCode." } } finally { Remove-Item -LiteralPath $Directory -Recurse -Force -ErrorAction SilentlyContinue }; if ($ExitCode -eq 3010) { Write-Warning 'La configuració ha acabat correctament, però cal reiniciar Windows.' } }
```

L'ordre crea un directori temporal aleatori, descarrega el ZIP a disc, comprova
la suma abans d'extreure'l, verifica també la certificació si GitHub CLI (`gh`)
és disponible, elimina Mark-of-the-Web només després de les comprovacions,
executa el llançador local i neteja els fitxers temporals.

### Opció curta

Si preferiu la comoditat i accepteu confiar directament en l'asset de la release
immutable abans de verificar-lo de manera independent:

```powershell
iwr -UseBasicParsing https://github.com/jcorrius/catalanitzador-windows/releases/download/v0.1.0/Install-Catalanitzador.ps1 | iex
```

Aquesta excepció només és segura dins el model de confiança del projecte perquè
fixa el repositori, l'etiqueta i l'asset d'una release immutable. No substituïu
mai `v0.1.0` per `latest`, `main`, una branca `raw`, un escurçador d'URL o un
altre domini. El bootstrap només admet la redirecció oficial de GitHub cap al
seu host d'assets, limita la mida i comprova la suma fixada del ZIP abans
d'executar el Catalanitzador. El bootstrap mateix ja s'ha executat; per això
l'ordre anterior amb SHA-256 incrustat continua sent la recomanada.

## Descàrrega verificada

Feu servir sempre una versió concreta. Fora de l'opció curta, no executeu
`main`, `latest` ni cap resposta web amb `Invoke-Expression`.

```powershell
$Repository = 'jcorrius/catalanitzador-windows'
$Version = 'v0.1.0'
$Directory = Join-Path $env:TEMP "Catalanitzador-$Version"
$BaseUri = "https://github.com/$Repository/releases/download/$Version"
$ZipName = "Catalanitzador.Windows-$Version.zip"

New-Item -ItemType Directory -Path $Directory -Force | Out-Null
Invoke-WebRequest "$BaseUri/$ZipName" -OutFile (Join-Path $Directory $ZipName)
Invoke-WebRequest "$BaseUri/SHA256SUMS" -OutFile (Join-Path $Directory 'SHA256SUMS')

$checksumLine = @(
    Get-Content (Join-Path $Directory 'SHA256SUMS') |
        Where-Object { $_ -match "\s+$([regex]::Escape($ZipName))$" }
)
if ($checksumLine.Count -ne 1) {
    throw 'No s''ha trobat una suma única per al ZIP.'
}
$expectedHash = ($checksumLine[0] -split '\s+', 2)[0]
$actualHash = (Get-FileHash (Join-Path $Directory $ZipName) -Algorithm SHA256).Hash
if ($actualHash -ine $expectedHash) {
    throw 'La suma SHA-256 del paquet no coincideix.'
}

gh attestation verify (Join-Path $Directory $ZipName) --repo $Repository
if ($LASTEXITCODE -ne 0) {
    throw 'La procedència de GitHub no és vàlida.'
}

Expand-Archive (Join-Path $Directory $ZipName) -DestinationPath $Directory
$Package = Join-Path $Directory "Catalanitzador.Windows-$Version"
Get-ChildItem $Package -Recurse -File | Unblock-File
```

La suma comprova la integritat del fitxer. La certificació de GitHub vincula
aquest fitxer amb el flux de publicació del repositori. `Unblock-File` només
s'executa després d'aquestes comprovacions. `-ExecutionPolicy RemoteSigned` només s'aplica al procés nou, no canvia cap
política permanent i no pot anul·lar una política de grup més restrictiva.

## Ús

Primer, simuleu:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    "$Package\Invoke-Catalanitzador.ps1" -WhatIf
```

Després, apliqueu la configuració:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    "$Package\Invoke-Catalanitzador.ps1"
```

Per establir també una ubicació principal concreta:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    "$Package\Invoke-Catalanitzador.ps1" -HomeLocationGeoId 217
```

Alguns GeoID útils són Andorra `8`, França `84`, Itàlia `118` i Espanya `217`.
No se'n tria cap automàticament.

Per seleccionar explícitament el perfil oficial català amb teclat espanyol com
a mètode d'entrada predeterminat:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File `
    "$Package\Invoke-Catalanitzador.ps1" `
    -DefaultInputMethodTip '0403:0000040A'
```

Paràmetres útils:

- `-WhatIf`: mostra les operacions previstes sense modificar Windows ni crear
  cap registre local.
- `-Confirm`: demana confirmació per a cada operació. Una resposta negativa
  omet aquella operació, n'informa al resultat i ajorna qualsevol còpia de
  configuració que en depengui; no es presenta com un error de Windows.
- `-Verbose`: mostra informació detallada de PowerShell.
- `-HomeLocationGeoId <n>`: canvia explícitament la ubicació principal.
- `-DefaultInputMethodTip <tip>`: selecciona explícitament un mètode d'entrada
  ja instal·lat; si s'omet, es conserva el predeterminat actual.
- `-LogPath <camí>`: selecciona el fitxer de registre d'una execució que aplica
  canvis.
- `-PassThru`: retorna l'objecte de resultat estructurat.

Si l'equip ja compleix tota la configuració sol·licitada, el programa només
consulta l'estat i ho informa. No invoca cap ordre de modificació, no fa
operacions de manteniment i no crea cap fitxer de registre.

## Resultat i codis de sortida

El programa indica si cal tancar la sessió o reiniciar, però no ho fa mai.

| Codi | Significat |
| --- | --- |
| `0` | Èxit, simulació, equip ja conforme o només cal tancar la sessió. |
| `1` | Error de configuració o manteniment. |
| `2` | Requisit, compte administrador, elevació o identitat no vàlids. |
| `3010` | Èxit; cal reiniciar Windows. |

Quan s'apliquen canvis, el registre predeterminat es desa a
`%LOCALAPPDATA%\Catalanitzador.Windows\Logs`. Els errors de Microsoft es
propaguen sense convertir-los en un fals resultat d'èxit.

## Desenvolupament

Les proves unitàries simulen totes les ordres que modifiquen Windows. Les proves
d'integració només es poden activar explícitament dins una màquina virtual
descartable.

El repositori inclou configuració compartida per al PowerShell de VS Code,
tasques de validació i depuració segura amb `-WhatIf`. També inclou instruccions
versionades per a GitHub Copilot, agents compatibles amb `AGENTS.md` i Claude
Code.

```powershell
$requirements = Import-PowerShellDataFile .\build\requirements.psd1
New-Item -ItemType Directory .\.psmodules -Force | Out-Null
Save-Module Pester -RequiredVersion $requirements.Pester `
    -Path .\.psmodules -Repository PSGallery -Force
Save-Module PSScriptAnalyzer -RequiredVersion $requirements.PSScriptAnalyzer `
    -Path .\.psmodules -Repository PSGallery -Force

powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned `
    -File .\build\Invoke-Tests.ps1
```

Consulteu [CONTRIBUTING.md](CONTRIBUTING.md), el
[model de seguretat](docs/security-model.md) i la
[resolució de problemes](docs/troubleshooting.md).

## Referències principals

- [Install-Language](https://learn.microsoft.com/powershell/module/languagepackmanagement/install-language)
- [Mòdul International](https://learn.microsoft.com/powershell/module/international/)
- [Capacitats de llengua de Windows](https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-language-fod)
- [Perfils d'entrada predeterminats](https://learn.microsoft.com/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs)
- [Configuració internacional d'una instal·lació en execució](https://learn.microsoft.com/windows-hardware/manufacture/desktop/configure-international-settings-in-windows)
- [Certificacions d'artefactes de GitHub](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations)
