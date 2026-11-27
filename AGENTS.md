# Pinpoint

Stack: Swift (macOS app, Swift Package Manager)
Tests: `swift test`
Lint: `shellcheck scripts/*.sh`
Build app: `scripts/build-app.sh`

## Branches: only `main` and `dev`

This overrides the feature-branch workflow in parent AGENTS.md files for this repository.

- The repository has exactly two branches: `main` (public releases) and `dev` (day-to-day work).
- Commit directly to `dev`. Never create feature, patch or any other branches or worktrees, locally or on GitHub.
- Run the tests and lint before committing. Ask before each commit and push to `dev`.
- Merge `dev` into `main` only when the user explicitly says so.
