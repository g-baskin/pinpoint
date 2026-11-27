# 0002 Rename from Zoomies to Pinpoint, with a one-time migration

Status: accepted (2026-11-27)

**Decision:** the app, targets and identifiers were renamed from Zoomies to Pinpoint: bundle id `app.pinpoint.Pinpoint`, Keychain service `app.pinpoint.apikeys`, library `~/Pictures/Pinpoint`. `LegacyMigration` (`Sources/PinpointCore/LegacyMigration.swift`) runs at launch, before `AppDelegate` is created, and carries over existing installs. It moves the old library without overwriting anything, and copies old settings and Keychain items, leaving the originals as a backup.

**Why:** one name everywhere, without losing users' captures, settings or saved keys.

**Consequences:** the remaining `zoomies` strings in `LegacyMigration.swift` and `scripts/build-app.sh` must stay. Changing the bundle id, Keychain service or library root again needs another migration step. A bundle id change also resets macOS Screen Recording permission, and the id is repeated in the ad-hoc `codesign -r` line of `build-app.sh`.
