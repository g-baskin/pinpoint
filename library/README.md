# Pinpoint library

Project documentation for Pinpoint, a macOS screenshot and markup app with a built-in AI agent. Layout follows Library Schema v2. This repository is public, and so is everything in this folder, including `knowledge/private/`. "Private" here means "written for contributors", not "secret".

## Where things live

| Folder | What goes here |
|---|---|
| [`knowledge/private/glossary/glossary.md`](knowledge/private/glossary/glossary.md) | One name per concept (capture, markup item, auto-redact, handoff, provider, agent). Read this first. |
| [`knowledge/private/architecture/`](knowledge/private/architecture/README.md) | Decision records `ADR-<n>-<slug>.md`. The README there is the index. |
| [`knowledge/private/standards/`](knowledge/private/standards/) | Project rules. Start with the [Definition of Done](knowledge/private/standards/definition-of-done.md). |
| `knowledge/private/wiki/` | Contributor wiki pages (being written now). |
| `knowledge/private/code-graph/` | Map of modules, types and how they call each other (being written now). |
| `knowledge/private/<domain>/` | Deeper notes on one area, for example capture, redaction or AI providers (being written now). |
| [`knowledge/public/`](knowledge/public/) | Pages written for people who use Pinpoint rather than work on it. Empty so far. |
| [`requirements/`](requirements/) | Product requirements (PRDs). The folder a PRD sits in is its state: `backlog/`, `in-work/` or `completed/`. |
| `requirements/reports/` | Routine scan reports that are not tied to one PRD. |
| `requirements/plans/` | Build plans: PRD maps, wave plans, handoff packets. |
| [`issues/`](issues/) | Issue requirements (IRDs), using the same `backlog/` and `completed/` folders. An IRD number is always the matching GitHub issue number. |
| `notes/` | Reserved for the owner's own notes. Agents never create or edit files there. |

## Current requirements

- [PRD-001: Pinpoint v0.1](requirements/completed/prd-001-pinpoint-v0-1/prd-001-pinpoint-v0-1-index.md), written after the fact from the source code. It describes what the app does today.

## Rules for adding documents

- New PRDs take the next free number across `backlog/`, `in-work/` and `completed/`. Move the whole PRD folder when its state changes.
- Add a new ADR instead of rewriting an old one.
- Cite source files (`Sources/...`) for every claim about behaviour.
- Use the name Pinpoint only. `NameGuardTests` fails `swift test` if the app's former name appears in any tracked or untracked file that git would pick up, including files in this folder.
