# M1 — Native workspace and catalog foundation

Completed 2026-10-02 on the development Mac. This is a developer app foundation; indexing and retrieval are subsequent milestones.

## Implemented

- Native SwiftUI workspace with an explicit AppKit-backed split layout: source/saved-view/collection sidebar, recipe controls, empty-state content, and collapsible inspector.
- Native folder picker and read-only security-scoped bookmarks. Persistent source identity uses volume UUID and volume-relative path; duplicate registration reuses the source record.
- Access checks, stale bookmark refresh, restore-access action, and Reveal in Finder. Missing/disconnected sources remain in the catalog.
- SQLite schema version 1 with transactions, foreign keys, WAL, and refusal of unknown future schemas. Typed records cover sources, assets, photo associations, metadata, embeddings, tag decisions, collections, saved recipes, and per-stage index jobs.
- Saved view creation/update, typed recipe round trips, unsaved-change indication, and persisted workspace recipe. Active saved-view selection itself is currently transient; its recipe survives reopening.
- System colors/type styles and adaptive control stacking. Search is explicitly unavailable until indexing/retrieval exists; filters explain their later availability. Collections are a truthful placeholder.
- Local build script, ad-hoc signing, and local executable checks. No downloaded Swift package dependencies or GitHub automation.

## Validation

`swift run CatalogChecks` passes source/bookmark reopen, duplicate identity, recipe create/update/round trip, workspace persistence, blank-name rejection, and future-schema refusal without downgrade. `python3 scripts/build_app.py` builds and signs the app locally. Optimized compilation was also exercised.

The actual external-drive folder was added through the native picker. Source access and a saved recipe survived app relaunch. Clicking the saved view changes the active title; arrow keys navigate native sidebar selections. Light and dark appearances were inspected, including a 780-point-wide workspace with 520-point content height (572-point total window including toolbar). The finish review found no visual blocker in the repaired wide/compact captures.

The initial NavigationSplitView laid out content at 1,783 points tall inside a 760-point window, moving controls outside the visible region. The explicit HSplitView fixes the confirmed rendering defect. Diagnostic-only code and temporary fixed-size/dark overrides were removed.

## Limits

No photos have been indexed. The schema anticipates later features; their workers, grid, metadata filters, collections, and search are not implemented yet. macOS 14 is the declared implementation floor; runtime testing so far is on macOS 26.6.2. Increased contrast, full Tab focus progression, and manual live window resizing still need broader accessibility validation. The developer build is not a notarized distribution.
