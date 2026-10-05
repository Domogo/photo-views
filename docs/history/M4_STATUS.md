# M4 — Dynamic grouping and saved live views

Implemented on the development Mac, 2026-10-02. This is the signature grouping/save-view increment; M5–M8 remain separate milestones.

## Delivered

- One-level folder, camera and camera-calendar-month groups. Missing/blank camera and absent/invalid capture dates have Unknown buckets. Folder identity includes source UUID, so equally named source folders stay distinct. Gregorian dates are validated, including leap days.
- Grouping is presentation only: it preserves each loaded asset exactly once, within-group retrieval order and the ranked group's strongest-member order. Browse groups sort deterministically; Unknown groups follow known browse groups. Changing grouping does not call the retrieval worker or image inference, reset pagination, or alter filters.
- Selected-photo identity and inspector survive regrouping. The grid anchors the selected photo, or the first visible photo when nothing is selected, where loaded. Retrieval also returns a matching selected photo outside the loaded page; filters removing it clear selection rather than choosing an unrelated photo.
- Named saved recipes include sources, search mode/text/reference, exact filters, group/sort choices, model and ranking versions. Active saved-view identity and an independently persisted draft survive relaunch. Definitions change only through Save View or explicit Update View; Unsaved changes is visible. Revert Changes restores the saved definition.
- Saved views remain live: indexing events and the active app's 15-second availability refresh re-query current catalog membership. View → Refresh Results explicitly re-runs retrieval without rescanning originals or rebuilding embeddings. Saving creates a recipe rather than a snapshot of IDs.
- Saved semantic model/ranking mismatches are refused before inference. Use Current Search Model changes the draft explicitly, warns that results may change, and leaves Update View as the separate action that stores that decision. Old recipes without version fields use the current runtime; new saves record its versions.
- The image-only gallery, native controls and inspectable metadata remain intact.

## Local verification

- CatalogChecks: grouping membership/uniqueness, same-name source separation, rank ordering, Unknown buckets, invalid dates/leap days, selected-view persistence, saved definition versus unsaved draft, explicit update and existing catalog checks.
- Eleven search-worker tests: existing exact constraints/retrieval plus presentation invariance, selected identity outside pagination/removal by filters, live ready-photo membership after reopening, and explicit model/ranking mismatch rejection.
- IndexChecks: existing orientation, integrity, indexing recovery, moves, cache limits and migration checks pass.
- End-to-end local `scripts/search/live_views.py`: two synthetic JPEG originals processed by the actual native ImageIO/index coordinator, actual local model embeddings and persisted Catalog recipes. Filename membership changes 1 → 2 after the new matching preview finishes; reference similarity changes 0 → 1 only after the new embedding finishes. Definitions stay byte-equivalent as decoded, membership survives a worker restart, the first vector remains byte-identical and the first original's SHA-256 remains unchanged. Report outside Git: `~/Library/Caches/PhotoViews/m4-live-001/summary.json`.
- Real archive UI: month → camera preserves the selected DSC_1658.JPG and 100 ranked results. Cars at night saved view and an unsaved month draft survive app relaunch; Revert Changes restores its camera grouping. SQLite verification confirms the saved definition stayed camera while the draft was month.
- Actual cached archive check: all 100 Nikon Z f/Japan results are unique and satisfy the exact camera/folder constraints; month and camera grouping retain identical membership and rank order. Explicit migration of the previous-model draft leaves its saved fixture definition unchanged. Report outside Git: `~/Library/Caches/PhotoViews/m4-ui-001/regroup-summary.json`.

Reproduce locally:

```sh
swift run CatalogChecks
swift run IndexChecks
"$PHOTO_VIEWS_PYTHON" scripts/search/checks.py
"$PHOTO_VIEWS_PYTHON" scripts/search/live_views.py --index-checks /absolute/path/to/IndexChecks --output /absolute/fresh/output --model /absolute/local/model
python3 scripts/build_app.py --release
```

## Limits

- Membership remains assets, including separate RAW/JPEG members; conservative pairing is M7. Group counts describe loaded assets, not whole-archive counts per bucket. Semantic results remain the nearest 100; new matching photos can replace older neighbors.
- Scroll retention is best effort for loaded photos. Exact pixel-offset restoration across relaunch is not promised. A selected member outside pagination can stay in the inspector without appearing in the currently loaded grid.
- The archive still has 5,085 visually indexed assets out of 19,877 discovered, with preview preparation paused. This milestone does not claim full-archive coverage, universal RAW support, held-out relevance or a standalone distributable runtime.
- Full accessibility/contrast/appearance matrix and cross-feature release checks remain M8. No GitHub Actions, hosting or paid automation were added; GitHub stores code only.

## Scoped native design review

Fresh M4 finish review disposition: **SHIP** for the grouping, live-view and selected-context increment, with no material visual fixes required. The review checked all five direction-contract sections against actual native CUA captures, source-defined geometry and system roles. The photograph-led grid, visible Japan constraint, selected DSC_1658.JPG, month grouping and Unsaved changes remain legible together; native menus expose explicit saving, updating, reverting and refreshing actions.

- `.impeccable/review/m4-wide-draft.png`: light appearance, 1180 × 760pt window, selected photo, Japan filter and unsaved month draft.
- `.impeccable/review/m4-view-menu.png`: light appearance, explicit Group by, Sort, Save View, Update View, Revert Changes and Refresh Results actions.
- `.impeccable/review/m4-model-change.png`: light appearance, isolated previous-model recipe and explicit Use Current Search Model warning/action.
- `.impeccable/review/m4-compact-dark.png`: dark appearance, 780 × 520pt content area, the same selected photo, filter and draft; recipe controls wrap and the inspector scrolls.
- `.impeccable/review/m4-save-sheet.png`: final native naming sheet, prefilled Cars at night, enabled Save View and effective Similarity sort in the saved-recipe summary.

The final wide, menu and sheet captures follow extraction of the naming sheet into a binding-backed view. The earlier compact and model-warning captures remain valid because that extraction changed only sheet state ownership. Canvas and inspector use appearance-aware `textBackgroundColor` and `controlBackgroundColor`; SF text, native controls and separators retain macOS roles. Photo selection uses the system accent with a 2pt outline. No new raster assets ship.

The final normal release build passed after a selected-photo request guard was added. A bounded source recheck retained the SHIP disposition: retrieval re-queries when selection changes during an outstanding request and falls outside its returned page, and accepts a returned selected asset only when its ID matches the current selection. This correction changes no visual presentation and required no new captures; the race itself was not separately exercised live.

The QA clone used a separate bundle and catalog with real cached archive photographs. Its Access needed state came from isolated bookmark access, so these captures do not prove a physically disconnected-drive test. The previous-model definition is a QA fixture. The scoped review does not establish the full accessibility/appearance matrix or broaden the coverage, RAW, relevance and runtime claims above.

`DESIGN.md` and `.impeccable/design.json` remain the historical M1 record, preserved without repair. Their disabled-search, empty-catalog and pending-photo-grid descriptions now lag the M4 implementation; the surface brief also retains its pre-implementation status. This review records the delivered extension in M4_STATUS.md without refreshing the reusable design-system documentation or inventing fixed native color/type/radius tokens.
