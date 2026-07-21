# Resolució de problemes

## El compte no és administrador

El compte que inicia el programa ha de pertànyer al grup local Administradors.
No es permet iniciar-lo com a usuari estàndard i introduir les credencials
d'una altra persona a UAC, perquè les ordres que copien configuració podrien
operar sobre el perfil equivocat.

Comproveu el testimoni actual:

```powershell
whoami /groups
```

## La identitat elevada no coincideix

El SID anterior i posterior a UAC ha de ser el mateix. Tanqueu la consola,
inicieu sessió amb el compte administrador que voleu configurar i torneu-ho a
provar. No forceu ni ometeu la comprovació.

## Edició o compilació no admesa

Comproveu:

```powershell
Get-ComputerInfo WindowsProductName, WindowsEditionId, OsBuildNumber, OsProductType
```

Cal la compilació `19045` o una compilació de Windows 11 `>= 22000`.
`SingleLanguage`, `CountrySpecific` i Windows Server no són compatibles.

La resta de versions de Windows 10 s'han investigat, però no s'executen: 1507 i
1511 no inclouen Windows PowerShell 5.1, i cap versió anterior a 22H2 no té una
ruta completa, documentada i validada per aquest projecte. Les excepcions LTSC
amb suport de Microsoft tampoc no s'accepten fins que una VM d'aquella
compilació demostri tots els cmdlets i l'adquisició en línia. Consulteu
[compatibility.md](compatibility.md).

## Windows Update o Features on Demand fallen

El programa no evita WSUS, Windows Update for Business, MDM, un servidor de
reparació ni una política que prohibeixi descarregar contingut opcional.

Comproveu l'estat publicat:

```powershell
Get-WindowsCapability -Online |
    Where-Object Name -Like 'Language.*~~~ca-ES~*' |
    Select-Object Name, State
```

Reviseu els errors de manteniment de Windows i les polítiques de la vostra
organització. No utilitzeu CAB, Appx o mitjans no oficials com a drecera. La
primera versió del projecte només admet adquisició en línia.

Referència:
[Language and region Features on Demand](https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-language-fod).

## Falta una ordre oficial

Executeu el programa amb el Windows PowerShell de 64 bits:

```powershell
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile
Get-Command Install-Language, Get-InstalledLanguage
Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue
```

`Copy-UserInternationalSettingsToSystem` només és obligatori a Windows 11.
Actualitzeu Windows amb els mecanismes normals de l'organització.

## Hi ha un reinici pendent

El programa no reinicia l'equip. Un resultat `3010` significa que els canvis
s'han aplicat i cal reiniciar. Si només demana tancar la sessió, el codi és `0`.

No repetiu indefinidament una instal·lació amb un reinici pendent. Reinicieu
quan sigui possible i torneu a executar el programa; la segona execució només
aplicarà allò que encara falti.

## L'equip ja està configurat

El missatge:

```text
Windows ja està configurat completament en català. No cal fer cap canvi.
```

és un èxit. En aquest camí no s'executa cap ordre de modificació, manteniment o
creació de registre.

Podeu inspeccionar l'estat manualment:

```powershell
Get-InstalledLanguage
Get-WinUserLanguageList
Get-WinUILanguageOverride
Get-Culture
Get-WinDefaultInputMethodOverride
Get-SystemPreferredUILanguage
Get-WinSystemLocale
Get-WinHomeLocation
```

## Una part de la interfície encara no és en català

Tanqueu la sessió per activar completament la llengua de l'usuari. Reinicieu si
el resultat ho demana. Algunes aplicacions tenen recursos o preferències de
llengua propis i poden no seguir immediatament la preferència de Windows.

## Windows 10 mostra `ca` en lloc de `ca-ES`

És una normalització documentada pel comportament real de Windows 10. El
Catalanitzador tracta `ca` i `ca-ES` com la mateixa llengua quan comprova els
valors d'usuari i de sistema; la instal·lació oficial continua identificada com
`ca-ES`.

## El teclat predeterminat no ha canviat

És el comportament previst. L'eina afegeix el perfil oficial català
`0403:0000040A`, però conserva el mètode d'entrada predeterminat existent per no
pressuposar el país ni el teclat físic. Utilitzeu
`-DefaultInputMethodTip 0403:0000040A` només si voleu seleccionar-lo.

## Windows 10 mostra un avís sobre usuaris nous

És esperat. Windows 10 no ofereix l'ordre documentada de Windows 11 que copia
tota la configuració internacional a la pantalla de benvinguda i als usuaris
nous. El projecte aplica només els valors de sistema documentats disponibles i
no modifica el perfil predeterminat ni el registre.

## Registres

Només una execució que intenta aplicar canvis crea un registre:

```text
%LOCALAPPDATA%\Catalanitzador.Windows\Logs
```

`-LogPath` permet triar-ne un altre. Els registres no es pugen. Reviseu-los
abans de compartir-los i elimineu qualsevol dada que considereu sensible.

## La suma o la certificació no són vàlides

No extraieu, no desbloquegeu i no executeu el paquet. Elimineu els fitxers i
torneu a descarregar exactament la mateixa versió des de la pàgina de versions
del repositori.

```powershell
Get-FileHash .\Catalanitzador.Windows-v0.1.0.zip -Algorithm SHA256
gh attestation verify .\Catalanitzador.Windows-v0.1.0.zip `
    --repo jcorrius/catalanitzador-windows
```

Si la discrepància persisteix, informeu-la de manera privada segons
[SECURITY.md](../SECURITY.md).
