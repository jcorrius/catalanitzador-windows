---
applyTo: "README.md,SECURITY.md,CONTRIBUTING.md,docs/**/*.md"
---

# Documentation

- Keep the primary user documentation in Catalan and
  `docs/usage.en.md` in English.
- Prefer official Microsoft, GitHub, PowerShell, Pester, and lifecycle sources.
- Distinguish verified support, experimental compatibility, and unsupported
  systems precisely.
- Never recommend mutable branches, `latest`, TLS bypasses, or permanent
  execution-policy changes. The sole pipe-to-execution exception is the
  bootstrap asset of an exact immutable GitHub release, with the fixed-hash
  download documented as the safer option.
- Make clear that language does not imply country, keyboard, home location, or
  time zone.
