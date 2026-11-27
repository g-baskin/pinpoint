# Definition of Done

> **Revision:** 1
> **Status:** Draft, waiting for the owner to approve
> **Applies to:** every change to Pinpoint (code, scripts and docs)
> **Sources:** `AGENTS.md`, `README.md` (Contributing), `Package.swift`, `Tests/PinpointCoreTests/`, [ADR-2](../architecture/ADR-2-stored-data-identifiers.md), [ADR-5](../architecture/ADR-5-main-and-dev-branches.md)

A change is done only when every item below that applies to it is true. A PRD may add stricter items; it may not drop any.

## 1. Tests pass

- [ ] `swift test` passes on macOS 14 or later with Swift 5.10 or later (`Package.swift` declares `swift-tools-version:5.10` and `.macOS(.v14)`).
- [ ] That run includes `NameGuardTests` (`Tests/PinpointCoreTests/NameGuardTests.swift`). It scans every file git tracks or would add, and fails if the app's former name appears in a path or in file text. Use only the name Pinpoint.
- [ ] No test was skipped, deleted or weakened to make the run pass.

## 2. Scripts are lint-clean

- [ ] `shellcheck scripts/*.sh` reports nothing.

## 3. Logic lives in PinpointCore, with tests

- [ ] New or changed behaviour that can run without AppKit windows goes in `Sources/PinpointCore`. The `Pinpoint` app target (`Sources/Pinpoint`) has no test target, so logic placed there is untested.
- [ ] Each new or changed `PinpointCore` behaviour has a test in `Tests/PinpointCoreTests`.
- [ ] New agent tool: a `ToolSpec` in `AgentToolbox.tools`, a case in `AgentToolbox.execute` (`Sources/PinpointCore/Agent.swift`) and a test.
- [ ] New markup kind: a case in `AnnotationKind` (`Sources/PinpointCore/Annotation.swift`), drawing in `Renderer.draw` (`Sources/PinpointCore/Renderer.swift`) and a `Tool` case in `Sources/Pinpoint/EditorModel.swift`.
- [ ] Test fixtures that look like secrets (API keys, tokens) are built by string concatenation, as in `SensitiveTests` (`Tests/PinpointCoreTests/CoreTests.swift`). GitHub push protection rejects secret-shaped literals even when they are fake.

## 4. Stored data and signing stay intact

- [ ] The bundle id (`CFBundleIdentifier` in `Resources/Info.plist`), `Keychain.service` (`Sources/PinpointCore/Assistants.swift`) and `LibraryStore.defaultRoot` (`Sources/PinpointCore/Library.swift`) are unchanged, or the change ships with a launch-time migration ([ADR-2](../architecture/ADR-2-stored-data-identifiers.md)).
- [ ] If `CFBundleIdentifier` changes, a launch-time data migration exists (ADR-2). The build scripts read the id from `Resources/Info.plist`, so the signature follows automatically.
- [ ] `scripts/build-app.sh` still builds `build/Pinpoint.app` when the change touches the app target, resources or build script.

## 5. Docs are updated

- [ ] `README.md` matches any change to features, shortcuts, providers, settings or install steps.
- [ ] The [glossary](../glossary/glossary.md) has any new concept, with its code name.
- [ ] A choice that is hard to undo gets a new ADR in [`../architecture/`](../architecture/README.md) and a line in its index.
- [ ] The PRD or IRD for the work, if there is one, is moved to the folder that matches its state.

## 6. Commit and release only with the owner's say-so

- [ ] Work is committed directly to `dev`. No feature, patch or other branches or worktrees, locally or on GitHub ([ADR-5](../architecture/ADR-5-main-and-dev-branches.md)).
- [ ] The owner approved this commit and this push to `dev` after seeing the change and the check results. Approval of a plan or a passing test run is not approval to commit.
- [ ] `dev` is merged into `main` only when the owner explicitly says so.

## PRD-level checklist

Copy this into a PRD's "Definition of Done checklist" section:

- Inherits Definition of Done revision 1: link it as `../../../knowledge/private/standards/definition-of-done.md` from any file in a PRD folder.
- `swift test` passes, including `NameGuardTests`.
- `shellcheck scripts/*.sh` is clean.
- Logic is in `PinpointCore` with tests.
- README, glossary and ADRs are updated where affected.
- Committed to `dev` after owner approval; `dev` to `main` only on the owner's word.
