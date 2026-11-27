# ADR-2 Fixed identifiers for stored data

Status: accepted (2026-11-27)

**Decision:** these identifiers name where users' data lives and stay fixed: bundle id `app.pinpoint.Pinpoint` (settings and Screen Recording permission), Keychain service `app.pinpoint.apikeys` (`Keychain.service`, saved keys and ChatGPT sign-in) and library root `~/Pictures/Pinpoint` (`LibraryStore.defaultRoot`).

**Why:** changing any of them makes existing captures, settings or keys invisible to the app.

**Consequences:** a change needs a migration that moves or copies the old data at launch, before `AppDelegate` creates the library. A bundle id change also resets Screen Recording permission, and the id is repeated in the ad-hoc `codesign -r` line of `scripts/build-app.sh`.
