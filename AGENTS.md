# Pinpoint

## Name

The app is called Pinpoint. Its former name is retired: don't use it anywhere, including code, identifiers, file and folder names, docs, commit messages, PR titles and replies. `NameGuardTests` fails `swift test` if it shows up in a tracked file.

## Branches: only `main` and `dev`

This overrides the feature-branch workflow in parent AGENTS.md files for this repository.

- The repository has exactly two branches: `main` (public releases) and `dev` (day-to-day work).
- Commit directly to `dev`. Never create feature, patch or any other branches or worktrees, locally or on GitHub.
- Run the tests and lint before committing. Ask before each commit and push to `dev`.
- Merge `dev` into `main` only when the user explicitly says so.

## Releases and the changelog

Every update that reaches users ships as a GitHub release and is recorded in `CHANGELOG.md`.

- **With each change:** add an entry under `## [Unreleased]` in `CHANGELOG.md` (Keep a Changelog sections, plain words) in the same commit as the code.
- **After committing user-facing changes to `dev`:** ask whether to release now. Merging into `main` still needs the user's explicit yes.
- **Whenever `dev` is merged into `main`, cut a release in the same step.** Never leave `main` ahead of the latest release. Follow README → Releasing:
  1. Pick the version by semver from the Unreleased entries: a fix only is a patch bump, an added feature is a minor bump. Set `CFBundleShortVersionString` and increase `CFBundleVersion` in `Resources/Info.plist`. Edit the two values in place; PlistBuddy reformats the whole file.
  2. Move the Unreleased entries under `## [x.y.z] - YYYY-MM-DD` with a one-paragraph summary, leave `## [Unreleased]` empty, and update the compare links at the bottom.
  3. Run `scripts/check.sh`, commit to `dev`, push, fast-forward `main` to `dev` and push `main`.
  4. On `main`, run `scripts/release.sh`, then `gh release create vx.y.z dist/Pinpoint-x.y.z.zip dist/Pinpoint-x.y.z.zip.sha256 --target main --title "Pinpoint x.y.z" --notes-file <that version's CHANGELOG section>`.
  5. Verify the release is Latest with both files attached, switch back to `dev` and confirm it's level with `origin/dev`.

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

- This is Swift, not Python: the parent AGENTS.md `pytest`/`src/` notes don't apply. All checks: `scripts/check.sh` (warnings are errors; its swift-format count is a report, not a gate, until the code is reformatted). Tests alone: `swift test`. App bundle: `scripts/build-app.sh` (`--install` copies it to ~/Applications).
- Put logic in `PinpointCore`; the `Pinpoint` app target has no tests.
- Changing the bundle id, `Keychain.service` or `LibraryStore.defaultRoot` orphans users' saved keys, settings and captures; it needs a launch-time migration (see `library/knowledge/private/architecture/ADR-2-stored-data-identifiers.md`).
- Downloads from `scripts/release.sh` are ad-hoc signed and not notarized; its designated requirement (bundle id read from `Resources/Info.plist`) is what keeps Screen Recording permission across updates, so don't switch it to the per-build hash.
- GitHub push protection rejects secret-shaped literals, even fake test fixtures; build them by concatenation (see `SensitiveTests` in `Tests/PinpointCoreTests/CoreTests.swift`).
<!-- gg:init:end -->
