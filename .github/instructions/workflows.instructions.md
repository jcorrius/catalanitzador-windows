---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml"
---

# GitHub Actions

- Pin every action to a full 40-character commit SHA and annotate its release
  tag in a comment.
- Keep top-level `contents: read`; grant additional permissions only to the
  smallest job that requires them.
- Use `persist-credentials: false`, bounded timeouts, and Harden-Runner.
- Never use `pull_request_target`, privileged `workflow_run` chains, untrusted
  artifact execution, or direct `${{ github.event.* }}` interpolation in shell.
- Release only exact `vX.Y.Z` tags after rerunning validation and package tests.
