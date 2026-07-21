# Política de seguretat

## Versions compatibles

Només la versió estable publicada més recent rep correccions de seguretat.
Les branques de desenvolupament i els artefactes de CI no són versions
admeses.

## Notificació de vulnerabilitats

No publiqueu vulnerabilitats en una incidència pública. Utilitzeu **Security > Advisories > Report a vulnerability** al repositori de GitHub.

Incloeu:

- La versió afectada.
- Els passos mínims per reproduir el problema.
- L'impacte esperat.
- Qualsevol mitigació coneguda.

No adjunteu credencials, certificats, fitxers PFX ni registres que continguen dades personals.

## Model de confiança

Les versions oficials es distribueixen com a artefactes versionats amb sumes
SHA-256, certificacions de procedència de GitHub i releases immutables. La ruta
recomanada verifica abans d'executar. Com a opció de conveniència, només s'admet
`Invoke-Expression` amb l'instal·lador d'una versió exacta publicat dins la
mateixa release immutable; mai amb `main`, `latest`, una branca raw, una
URL escurçada o un domini de tercers. El bootstrap només accepta la redirecció
oficial cap a l'host d'assets de GitHub i verifica la suma fixada del ZIP.

Verifiqueu tant la suma com la procedència abans d'extreure o desbloquejar el
ZIP. Consulteu [docs/security-model.md](docs/security-model.md).
