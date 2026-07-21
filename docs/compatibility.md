# Compatibilitat

## Política de suport

Windows 11 és la plataforma recomanada. A Windows 10, el projecte només accepta
22H2 compilació `19045`, que s'ha validat de punta a punta en una VM real.
Microsoft va finalitzar el suport general de Windows 10 el 14 d'octubre de 2025;
la compatibilitat amb 19045 s'adreça a ESU i entorns administrats.

No n'hi ha prou que una ordre aparegui en una màquina antiga. Per admetre una
compilació cal demostrar conjuntament:

1. Windows PowerShell 5.1.
2. Totes les ordres de `LanguagePackManagement`, `International` i capacitats
   que utilitza el mòdul.
3. Adquisició en línia del paquet `ca-ES` i de les capacitats publicades.
4. Convergència després del reinici i una segona execució sense canvis ni
   registre.

La família es determina pel número de compilació. El nom retornat per
`Get-ComputerInfo` pot continuar dient "Windows 10" en una instal·lació de
Windows 11.

## Totes les versions de Windows 10

| Versió | Compilació | Resultat de la investigació | Veredicte |
| --- | ---: | --- | --- |
| 1507 | `10240` | Inclou Windows PowerShell 5.0; no es pot satisfer el requisit 5.1 del projecte. | Rebutjada estructuralment. |
| 1511 | `10586` | Inclou Windows PowerShell 5.0; no es pot satisfer el requisit 5.1 del projecte. | Rebutjada estructuralment. |
| 1607 | `14393` | Inclou 5.1, però no s'ha documentat ni validat el conjunt complet de `LanguagePackManagement`. LTSB 2016 no canvia aquest bloqueig tècnic. | Rebutjada. |
| 1703 | `15063` | No hi ha una ruta completa de PowerShell documentada i validada per a l'adquisició en línia del LIP. | Rebutjada. |
| 1709 | `16299` | Mateix bloqueig que 1703. | Rebutjada. |
| 1803 | `17134` | Mateix bloqueig que 1703. | Rebutjada. |
| 1809 | `17763` | És la primera generació coberta pel docset `windowsserver2019-ps`, però això no prova la presència ni el funcionament del mòdul al client. `ca-ES` passa a distribuir-se com a LIP Appx. LTSC 2019 continua sense una prova real del projecte. | Candidata d'investigació, rebutjada ara. |
| 1903 | `18362` | Conjunt de cmdlets i adquisició en línia no validats. | Rebutjada. |
| 1909 | `18363` | Conjunt de cmdlets i adquisició en línia no validats. | Rebutjada. |
| 2004 | `19041` | No hi ha cap font primària de Microsoft que estableixi aquesta versió com a inici de `LanguagePackManagement`; el projecte no l'ha provada. | Candidata d'investigació, rebutjada ara. |
| 20H2 | `19042` | Mateixa base tècnica que 2004, fora de suport i sense prova real. | Candidata d'investigació, rebutjada ara. |
| 21H1 | `19043` | Mateixa base tècnica que 2004, fora de suport i sense prova real. | Candidata d'investigació, rebutjada ara. |
| 21H2 | `19044` | Enterprise LTSC 2021 encara té cicle de vida propi, però la ruta completa no s'ha validat en una VM 19044. | Millor candidata futura, rebutjada ara. |
| 22H2 | `19045` | `LanguagePackManagement` 1.0 comprovat, instal·lació real `ca-ES` correcta, estat posterior conforme i segona execució sense canvis. | Compatibilitat tècnica admesa per a ESU o gestió equivalent. |

La documentació oficial del mòdul no declara en quina versió concreta de
Windows 10 client es va introduir. Per això el projecte no converteix una
inferència basada en docsets o nuclis compartits en una promesa de suport.

Els casos amb més valor per a una ampliació futura són Enterprise LTSC 2021
`19044` i Enterprise LTSC 2019 `17763`. Cadascun exigeix una prova destructiva
completa en la seva pròpia VM abans de canviar el filtre d'execució.

## Català, llengua base i geografia

A Windows 10, Microsoft classifica `ca-ES` com a Language Interface Pack. La
taula oficial indica:

- Base principal: `es-ES`.
- Bases secundàries: `en-GB`, `en-US` i `fr-FR`.

Per tant, no s'instal·la ni es força el castellà si l'equip ja té una base
compatible. La prova real de 19045 va partir d'un Windows en `en-US` i va
instal·lar el català correctament.

La llengua tampoc implica país, fus horari o teclat físic. El perfil
`0403:0000040A` és el perfil d'entrada oficial de Microsoft per a català amb
teclat espanyol; s'afegeix a la llista, però només esdevé predeterminat amb
`-DefaultInputMethodTip`.

Windows 10 pot retornar el tag neutral `ca` per a valors d'usuari o sistema.
Les comprovacions tracten `ca` i `ca-ES` com a equivalents.

## Matriu de configuració admesa

| Configuració | Windows 10 22H2 | Windows 11 |
| --- | --- | --- |
| `Install-Language ca-ES` | Sí, amb `-CopyToSettings` quan cal instal·lar. | Sí. |
| Capacitats `Language.*~~~ca-ES~...` | Descobriment i instal·lació dinàmics. | Descobriment i instal·lació dinàmics. |
| Llista, interfície i cultura de l'usuari | Sí. | Sí. |
| Perfil d'entrada català | S'afegeix; el predeterminat es conserva si no es demana. | Igual. |
| Ubicació principal | Només amb un GeoID explícit. | Només amb un GeoID explícit. |
| Llengua preferida i configuració regional del sistema | Sí. | Sí. |
| Pantalla de benvinguda i usuaris nous | Valors de sistema documentats; no hi ha còpia completa. | `Copy-UserInternationalSettingsToSystem`. |

`Copy-UserInternationalSettingsToSystem` només està documentat per a Windows
11. A Windows 10 no es carrega `Default User`, no es modifica el registre i no
s'automatitza `intl.cpl`.

## Capacitats de llengua

El projecte consulta `Get-WindowsCapability -Online` i només considera, en
aquest ordre, Basic, OCR, Handwriting, TextToSpeech i Speech. Una família que
Microsoft no publica per a la compilació actual no és un error. No s'instal·len
Retail Demo ni tipus de lletra no relacionats.

## Validació de Windows 10 22H2

La validació x64 de la compilació 19045 va confirmar:

- El WIM de Windows 10 Pro conté `LanguagePackManagement` versió `1.0`.
- El mòdul exporta les ordres requerides i s'importa amb Windows PowerShell 5.1.
- `Install-Language ca-ES` funciona sobre una base `en-US`.
- Windows retorna `ca-ES` per al paquet instal·lat i pot normalitzar a `ca` la
  llista d'usuari i les llengües d'interfície.
- Després del reinici, tots els getters de Microsoft són conformes.
- La següent execució retorna `Changed = false`, `AlreadyCompliant = true`, codi
  `0` i no crea cap registre.

Les proves destructives no formen part de la CI:

```powershell
$env:CATALANITZADOR_DISPOSABLE_VM = '1'
powershell.exe -ExecutionPolicy RemoteSigned `
    -File .\build\Invoke-Tests.ps1 -Integration
```

## Referències

- [Windows Management Framework](https://learn.microsoft.com/powershell/scripting/windows-powershell/wmf-overview)
- [LanguagePackManagement](https://learn.microsoft.com/powershell/module/languagepackmanagement/)
- [Copy-UserInternationalSettingsToSystem](https://learn.microsoft.com/powershell/module/international/copy-userinternationalsettingstosystem)
- [Paquets de llengua disponibles a Windows 10](https://learn.microsoft.com/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-10)
- [Capacitats de llengua](https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-language-fod)
- [Informació de versions de Windows 10](https://learn.microsoft.com/windows/release-health/release-information)
- [Cicle de vida de Windows 10 Home i Pro](https://learn.microsoft.com/lifecycle/products/windows-10-home-and-pro)
- [Windows 10 Enterprise LTSC 2021](https://learn.microsoft.com/lifecycle/products/windows-10-enterprise-ltsc-2021)
- [Windows 10 Enterprise LTSC 2019](https://learn.microsoft.com/lifecycle/products/windows-10-enterprise-ltsc-2019)
