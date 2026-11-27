# ADR-1 Library stored as one folder per capture

Status: accepted (2026-11-27)

**Decision:** each capture lives in `~/Pictures/Pinpoint/<uuid>/` as `original.png`, `rendered.png`, `thumb.jpg` and `meta.json` (`CaptureMeta`, `Sources/PinpointCore/Library.swift`). There is no database.

**Why:** plain files are easy to back up, search and open outside the app, and one folder per capture means a broken capture cannot damage the others.

**Consequences:** `meta.json` is a stored format. Renaming fields in `CaptureMeta` or `Annotation`, or the raw values of `AnnotationKind`, breaks existing libraries unless decoding stays backward compatible. Moving the library root needs a migration step (see ADR-2).
