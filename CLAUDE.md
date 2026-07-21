@AGENTS.md

# Claude Code

- Treat `.claude/settings.json` as the shared minimum safety policy. Do not
  weaken its permission rules.
- Keep personal approvals and machine-specific preferences in the ignored
  `.claude/settings.local.json` or `CLAUDE.local.md`.
- On Windows, use native Windows paths and run the repository validation through
  Windows PowerShell 5.1 exactly as documented in `AGENTS.md`.
