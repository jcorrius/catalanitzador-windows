# Model de seguretat

## Objectius

- Executar únicament codi d'una versió identificada i verificable.
- Reduir els permisos de CI i publicació.
- Evitar que dades no fiables d'una pull request arribin directament a una
  ordre de shell privilegiada.
- Preservar les polítiques de Windows Update, TLS i UAC.
- No convertir errors parcials en resultats d'èxit.

## Cadena de confiança d'una versió

1. Una etiqueta exacta `vX.Y.Z` activa el flux de publicació.
2. El flux torna a executar la sintaxi de Windows PowerShell 5.1,
   PSScriptAnalyzer, Pester i les proves del paquet.
3. El paquet ZIP es genera de manera determinista, sense compressió dependent
   de la implementació, amb marques temporals, atributs i una llista de fitxers
   fixos.
4. Es genera l'instal·lador curt amb la versió i la suma exacta del ZIP, i es
   publica `SHA256SUMS` per al ZIP i l'instal·lador.
5. `actions/attest` genera procedència SLSA signada amb una identitat OIDC
   efímera de GitHub per al ZIP, l'instal·lador i el fitxer de sumes.
6. Un treball separat, limitat a l'entorn `release`, publica exactament els
   artefactes verificats.

Les sumes SHA-256 detecten corrupció o substitució respecte del valor esperat.
No demostren per si soles qui ha creat el fitxer si la suma prové del mateix
canal compromès. La certificació de GitHub vincula el resum del fitxer amb el
flux i el repositori que l'han produït.

La signatura Authenticode és opcional i encara no està activada. El constructor
admet un certificat de signatura de codi per empremta digital, però cap PFX,
clau privada ni secret de llarga durada forma part del repositori.

## Descàrrega remota

El projecte no admet patrons mutables com:

```powershell
irm https://example/script.ps1 | iex
```

Aquest patró executa una resposta mutable abans que l'usuari pugui verificar-ne
el contingut. La ruta recomanada fixa una versió i la suma SHA-256 exacta del ZIP
dins la mateixa ordre. Descarrega a un directori temporal, comprova la suma,
verifica també la certificació si `gh` està disponible, extreu i només llavors
elimina Mark-of-the-Web i executa el fitxer local.

També es publica `Install-Catalanitzador.ps1` dins cada release immutable. Això
permet una ordre curta amb `iwr ... | iex`, però el bootstrap s'executa abans que
l'usuari en pugui comprovar la suma. La confiança inicial recau en TLS, el domini
oficial de GitHub, el repositori exacte, l'etiqueta exacta i la immutabilitat de
la release. El bootstrap verifica després la suma fixada del ZIP i, si `gh` és
disponible, la seva certificació. Aquesta opció no s'estén mai a `main`,
`latest`, branques raw, escurçadors d'URL ni dominis de tercers. El bootstrap
desactiva les redireccions automàtiques, valida explícitament l'única redirecció
cap a `release-assets.githubusercontent.com`, rebutja una segona redirecció,
limita la mida descarregada i exigeix la suma exacta abans d'executar el ZIP.

La guia detallada descarrega també `SHA256SUMS` i exigeix
`gh attestation verify`. La suma fixada a la documentació protegeix contra una
substitució del ZIP respecte de la versió revisada; la certificació aporta una
prova separada que l'artefacte l'ha produït el flux de GitHub d'aquest
repositori.

No s'utilitza `-ExecutionPolicy Bypass` ni es desactiva la validació de
certificats. El bootstrap habilita TLS 1.2 només dins el seu procés i restaura
el valor anterior després de la descàrrega; no modifica Windows ni cap política.
Les instruccions fan servir `-ExecutionPolicy RemoteSigned` només per al procés
que executa el paquet ja verificat i desbloquejat. Aquesta opció no persisteix i
no anul·la una política de grup.

## UAC i identitat

L'iniciador ha de pertànyer al grup local Administradors. La pertinença i
l'elevació són comprovacions separades perquè un testimoni UAC filtrat no activa
el rol d'administrador.

Els paràmetres es transmeten entre processos en un JSON codificat en Base64,
sense fitxer d'entrada temporal ni `Invoke-Expression`. El resultat elevat
torna per un fitxer aleatori creat exclusivament amb `CreateNew`, validat amb
un nonce i eliminat immediatament; mai no s'interpreta com a codi. Després de
l'elevació, el SID s'ha de mantenir. Si UAC utilitza unes altres credencials,
el programa s'atura abans d'importar el mòdul o modificar Windows.

## Límits locals

- UAC continua sent el límit de consentiment de Windows.
- Un administrador local que accepta l'elevació ja pot modificar el sistema;
  el projecte no intenta defensar-se d'aquest administrador.
- Els paquets i les capacitats provenen dels orígens de Windows Update que
  permet la política de l'organització.
- A Windows 11, un marcador mínim permet reprendre la còpia a la pantalla de
  benvinguda després d'una interrupció. Es crea abans del primer canvi afectat
  dins `ProgramData`, amb herència desactivada i accés complet exclusiu per a
  `SYSTEM` i Administradors; es rebutgen propietaris, permisos, continguts o
  punts de reanàlisi inesperats.
- Els registres són locals, no s'envien, i només es creen quan s'intenten
  aplicar canvis.
- No s'aboquen variables d'entorn, credencials ni una instantània completa de
  l'equip al registre.

## Seguretat de GitHub Actions

- Totes les accions estan fixades a SHA complets i Dependabot proposa
  actualitzacions.
- `contents: read` és el permís predeterminat.
- Només el treball final de publicació té `contents: write`.
- OIDC, certificacions i metadades d'artefactes només s'habiliten al treball que
  genera la procedència.
- No s'utilitzen `pull_request_target` ni cadenes `workflow_run` privilegiades.
- `persist-credentials: false` evita deixar credencials de Git al directori de
  treball.
- Dependency Review bloqueja vulnerabilitats noves d'alta gravetat.
- OpenSSF Scorecard i CodeQL analitzen la configuració de GitHub Actions.
  CodeQL no analitza el codi PowerShell d'aquest projecte.
- Harden-Runner registra l'egress de cada treball.

## Configuració recomanada del repositori

Després de crear el repositori públic:

- Establiu el `GITHUB_TOKEN` predeterminat com a només lectura.
- Impediu que GitHub Actions creï o aprovi pull requests.
- Protegiu `main` i les etiquetes `v*` contra eliminació i force-push.
- Exigiu CI, Dependency Review i CodeQL abans de fusionar.
- Exigiu revisió de CODEOWNERS per a `.github/workflows/**`.
- Protegiu l'entorn `release` amb aprovació.
- Activeu immutable releases, dependency graph, Dependabot alerts, secret
  scanning, push protection, private vulnerability reporting i security
  advisories quan estiguin disponibles.
- Apliqueu una política que exigeixi accions fixades a SHA complet.

Consulteu
[Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
i
[Artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations).
