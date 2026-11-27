# Pinpoint

## Name

The app is called Pinpoint. Its former name is retired: don't use it anywhere, including code, identifiers, file and folder names, docs, commit messages, PR titles and replies. `NameGuardTests` fails `swift test` if it shows up in a tracked file.

## Branches: only `main` and `dev`

This overrides the feature-branch workflow in parent AGENTS.md files for this repository.

- The repository has exactly two branches: `main` (public releases) and `dev` (day-to-day work).
- Commit directly to `dev`. Never create feature, patch or any other branches or worktrees, locally or on GitHub.
- Run the tests and lint before committing. Ask before each commit and push to `dev`.
- Merge `dev` into `main` only when the user explicitly says so.

## Drone routing

Docs live in `library/` (Library Schema v2). Send each kind of work to its Wasp drone (`~/.gg/agents/<name>.md`, which loads its Stinger skill):

- `library/` structure, PRDs, IRDs, standards: `library-wasp-drone`
- Domain guides in `library/knowledge/private/<domain>/` and diagrams in `code-graph/`: `knowledge-wasp-drone`
- Entity pages in `library/knowledge/private/wiki/`: `wiki-wasp-drone`
- Decision records in `library/knowledge/private/architecture/`: `adr-writing-wasp-drone`
- `README.md`: `readme-writing-wasp-drone`; `CHANGELOG.md`: `changelog-release-notes-wasp-drone`
- Code review: `code-review-pr-wasp-drone`; security review: `security-wasp-drone`

After a code change, update the wiki pages, code-graph diagrams and domain guide for the files it touched, and add a CHANGELOG entry under Unreleased. Don't use `feature-workflow-wasp-drone` here: it creates feature branches.

<!-- gg:init:start -->
Pinpoint: a macOS screenshot and markup app with a built-in AI agent (Swift Package Manager, macOS 14+).

- This is Swift, not Python: the parent AGENTS.md `pytest`/`src/` notes don't apply. Tests: `swift test`. Lint: `shellcheck scripts/*.sh`. App bundle: `scripts/build-app.sh` (`--install` copies it to ~/Applications).
- Put logic in `PinpointCore`; the `Pinpoint` app target has no tests.
- Changing the bundle id, `Keychain.service` or `LibraryStore.defaultRoot` orphans users' saved keys, settings and captures; it needs a launch-time migration (see `library/knowledge/private/architecture/ADR-2-stored-data-identifiers.md`).
- `CFBundleIdentifier` in `Resources/Info.plist` is repeated in the ad-hoc `codesign -r` line of `scripts/build-app.sh`; change both, or Screen Recording permission resets on every rebuild.
- GitHub push protection rejects secret-shaped literals, even fake test fixtures; build them by concatenation (see `SensitiveTests` in `Tests/PinpointCoreTests/CoreTests.swift`).
<!-- gg:init:end -->
