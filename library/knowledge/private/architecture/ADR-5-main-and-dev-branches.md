# ADR-5 Only main and dev branches

Status: accepted (2026-11-27)

**Decision:** the public repository has exactly two branches: `main` for releases and `dev` for day-to-day work. Work is committed directly to `dev`, and `dev` is merged into `main` only when the owner says so. This overrides the feature-branch workflow used in the owner's other projects (see `AGENTS.md`).

**Why:** the owner wants a simple, tidy public repository.

**Consequences:** there are no feature-branch pull requests to review. Outside contributors open pull requests against the repository, and the owner brings their changes into `dev`.
