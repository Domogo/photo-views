# M2 — Resumable indexing and real-photo browsing

Implemented on the development Mac (Apple Silicon M5 Max, macOS 26.6.2). The package declares macOS 14; that oldest runtime has not been tested.

## Delivered

- Recursive source discovery with hidden files, AppleDouble entries, packages and symlink files excluded. Originals remain in place.
- Separate durable metadata and preview jobs, a single utility worker, cooperative pause, restart recovery and incremental refresh. Completed stages are reused. Unchanged files keep their cached derivatives; changed files invalidate their derived records. Conservative filesystem identity matching preserves moved-file identity, with a content-hash fallback when no stable filesystem identity is available.
- Original-file EXIF/TIFF metadata, orientation-aware native ImageIO previews, explicit 8-bit sRGB JPEG derivatives, maximum 512-pixel thumbnails and 1,600-pixel analysis previews. Decoder/version and embedded-preview versus generated-preview provenance are retained.
- Transactional catalog migration from schema 1 to 2, preserving sources and saved recipes.
- A lazy grid with incremental loading, native selection, arrow-key navigation, Space preview, Escape dismissal, metadata inspector and Reveal Original in Finder. Folder, month and camera provide basic browsing groups; full result grouping and retrieval follow in M3–M4.
- Visible indexing coverage, pause/resume, individual decode failures with retry, source availability and retained selection as indexing adds photos.
- A 2 GiB managed disk cache outside source folders. Analysis previews are evicted before thumbnails; metadata and originals survive eviction. Cached photos remain browseable when the source is unavailable.

## Local verification

`swift run CatalogChecks` and `swift run IndexChecks` pass. The indexing checks cover synthetic orientation and metadata, pause/checkpoint/reopen, actual child-process termination after a durable metadata checkpoint, unchanged-file reuse, moved files, changed files, corrupt-file isolation, missing-file handling, invalid-bookmark/disconnected-source preservation, zero-budget eviction and schema migration.

The real-fixture probe passed 60 files from the connected SSD: 20 Sony ILCE-6000 ARW, 20 Nikon Zf NEF and 20 Nikon Zf JPEG. All 60 original SHA-256 hashes were unchanged and all preview geometries matched the validated M0 outputs. Sony embedded previews can reflect the camera's 16:9 crop while sensor metadata remains 3:2; preview aspect is therefore compared against M0, not sensor dimensions. Synthetic fixtures independently verify EXIF orientation.

The running app discovered 19,877 photos in the user's archive and indexed 5,085 before pausing. Browsing partial results, inspecting metadata, arrow selection, Space/Escape, pause and automatic recovery after quitting during indexing were exercised in the native app. Light/default-width, cached-preview and compact dark-window captures were inspected locally. Reports and screenshots are excluded from Git.

## Limits and next steps

- These camera/format fixtures are evidence for those files, not a claim that every RAW camera or variant works. Unsupported or damaged files report individual failures.
- The real archive has not finished indexing. The current source is paused and can be resumed from the app.
- Preview geometry and sRGB output are checked; color has not received a calibrated human reference review.
- Unknown EXIF timezones retain the camera wall-clock text and are explicitly labelled. The sortable date axis uses a neutral UTC interpretation where the camera provided no offset.
- Disconnected-source checks use isolated invalid-bookmark fixtures. The user's physical SSD was not unplugged for testing. Full reconnect reconciliation and filesystem watching belong to M7; Refresh Folders performs an explicit incremental scan today.
- Embeddings, visual retrieval, exact search constraints and Find Similar belong to M3. Subject tags and subject groups belong to M5.
- All checks and builds run locally. GitHub stores code only; no custom Actions, hosting or paid automation were added.

## M2 UI verification

Final native captures `m2-final-wide.png`, `m2-final-preview.png`, `m2-final-compact-dark.png` and `m2-final-cache-cleared.png` under `.impeccable/review/` were checked against `WorkspaceView.swift`, `WorkspaceModel.swift`, `PhotoGrid.swift` and the incumbent Photo Workbench rules. Reviewer disposition is **ship for the four scored material fixes**; the verdict pass assessed that fix list, not a new full-surface audit. Loaded counts explicitly distinguish the displayed subset from browseable photos; exposure reads `1/125 s`; inspector preview/open/reveal actions precede metadata; cleared-cache preview presents a labeled Rebuild Preview action and preserves original access. Source inspection confirms missing derivative paths are cleared before presentation and rebuilding is unavailable during indexing or while the original is offline.

The extension retains the 8pt control gap, 20pt content inset, 24pt section gap, dynamic native canvas/panel colors, SF text styles, native pane/control geometry and flat photograph-led surfaces. The grid adds local 160pt minimum cells, 128pt thumbnail height and a 2pt accent selection outline; these are component geometry, not new global tokens. Compact dark evidence shows stacked Group by/Sort controls and readable photo actions. Static captures do not establish full Tab traversal, increased contrast/all accent choices, reduced motion or complete resizing coverage.

`DESIGN.md` and `.impeccable/design.json` remain unchanged for this ordinary extension. Their M1-only descriptions of pending grids/previews/counts, and the surface brief's pre-implementation status/open decisions, are historical documentation drift. The brief's filename-light grid intent also differs from M2's practical filename/format captions. M2 implementation and verification are recorded here without silently refreshing the established design authority. No new shipped raster assets were introduced: displayed photographs are local user-cache derivatives, and fixtures/captures remain excluded from Git.
