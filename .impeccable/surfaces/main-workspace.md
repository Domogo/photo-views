# Main workspace — Still, Atelier in Graphite

Status: user approved Graphite + Atelier navigation + the selected Open Frame filled-corner mark and sharp wordmark, and authorized planning/implementation. Latest release builds and local CatalogChecks passed. Fresh native reviewer disposition is ship for the scored View contrast fix only; earlier titlebar and heading fixes are resolved. This is not full-surface acceptance.
Primary targets: Sources/PhotoViewsApp/WorkspaceView.swift, Brand.swift, PhotoViewsApp.swift
Related targets: PhotoGrid.swift, NativePhotoGallery.swift, Sources/PhotoViewsCore/GalleryGeometry.swift

## Scope and mode

Native macOS photographic workspace. PRODUCT.md and prd.md govern product truth; DESIGN.md owns extracted visual tokens. Local processing, read-only originals, saved views, exact constraints, keyboard behavior and RAW+JPEG integrity remain binding. Approved composition: `.impeccable/mocks/comp-3.png`. The selected solid opposing-corner logo overrides the older outlined mark in that composition.

## Direction contract

**THESIS:** A quiet photographic atelier gives the archive the window. The Graphite surround and crisp top navigation recede; photographs lead.

**OWN-WORLD:** Dark Graphite default, Light/System selectable in View, subdued jade active states, flat tonal panes and native SF functional text. The Open Frame mark is two filled opposing 90° corners; the custom lowercase wordmark has square i dot, chamfered s, squared t and straight double l. Preserve vector geometry rather than substitute a font or rounded logo.

**FIRST VIEWPORT:** One 52pt top header integrates into the native titlebar, with an 80pt traffic-light reserve plus 16pt normal inset. Native window controls remain; source-backed background dragging is unverified. It holds identity, All photos/Favorites/People and compact tools. At ≥1180pt search/Filters/zoom/View share this header; below it search forms a second row. No permanent rail. Folders, saved views and collections are behind the folder toggle; contextual details open from selection. A compact results/indexing row leads the continuous image-only masonry archive.

**SIGNATURE:** Find a moment → inspect images → refine as needed. Search has an inset 6pt radius field and visible focus outline. Active destination has a 2pt jade underline. Folders/Saved Views/Collections headings use explicit appearance-aware secondary colors. View has an explicit primary label/chevron in a borderless native Menu; source padding is 8×4pt with 5pt radius/6% primary background, while native rendering supplies final treatment. Filters opens a bounded scrollable drawer; exact constraints stay individually removable. View owns search mode, appearance, grouping/sorting, saving and pairing. Saved definitions update explicitly.

**MOTION:** No entrance animation or archive-wide animation. Preserve stable photo identity and scroll context when regrouping, zooming or indexing. Native controls own interaction feedback.

**CONTINUITY:** Display Still and output `.build/app/Still.app`; keep `com.domogo.photoviews` and existing Photo Views catalog/cache paths. Counts must distinguish logical photos from files indexed; RAW+JPEG collapse affects photo counts, not per-file coverage.

## Gallery and supporting panes

- Full image proportions in recycled AppKit collection-view masonry cells; no cropping, filename, format or persistent overlay. Shortest-column placement packs space while preserving the ranking sequence used for placement.
- Orientation-aware proportions from recorded dimensions. Missing dimensions use a square placeholder until metadata is available.
- Narrow gutters and adaptive columns. Portraits receive their full height rather than letterboxing inside landscape cells.
- Sidebar is reachable from the native toolbar and remembers visibility. A photo selection opens the inspector; the toolbar can close it. Unselected source details are optional rather than permanent competition for image space.
- RAW+JPEG member switching retains the logical gallery highlight; metadata and organization remain per file. Space opens a larger preview; arrows navigate spatially across masonry cells. Focus and selection remain distinct.

## Search and palette

- Natural language is primary; filename/keyword mode remains in View. The interpreter supports its documented finite grammar and does not claim arbitrary metadata understanding.
- Overall palette first, explicitly separate from colored objects. “Mostly blue” or “predominantly blue” sets a blue palette condition; “blue car” stays a visual description.
- Analyze existing orientation-corrected sRGB derivatives locally in bounded background batches. Store versioned area histograms; unchanged cached palettes survive preview eviction and drive absence. Changed files invalidate palette data.
- Selected family must be the largest histogram family and meet the chosen minimum area (default 25%). It does not mean a majority of pixels or detected objects. Expose named swatches and the area control inside Filters.
- Palette coverage is visible when partial; unprepared/failed palettes do not silently match. Retry analysis is explicit after restoring previews. Exact metadata and per-file membership constrain candidates before combined ranking and pair collapse.
- Color names include neutrals. This first deterministic classifier is a coarse preview palette, not a calibrated perceptual or object model; broad archive quality requires measurement.

## Status and states

Keep result and indexing counts on one small row. Expand indexing controls/failures only on demand. Incomplete palette coverage remains visible during palette search. Sources report disconnection; originals report their own availability in the inspector. No-match states retain exact constraints. Queries awaiting approval or correction say Search not run; rejected queries never imply an empty executed search. Catalog/worker errors remain actionable. No information is removed merely to make a successful screenshot quieter.

## Verification

Latest release builds passed. Earlier CatalogChecks passed 20,000-item geometry at three widths, finite-query and persistence checks; inference behavior did not change. Fresh native wide captures cover Graphite gallery/folders, Light, blocked query, palette and corrected View menus in both appearances. `still-final-native-zoom.png` is a native wide capture, not compact evidence. Native accessibility actions verified ⌘2 Favorites, ⌘1 All photos and ⌘F search focus; “cars location:Paris” blocks with Search not run, while “mostly blue” applies the 25% palette filter and expands its drawer. The existing 19,877 catalog files and two saved views remain present.

Reviewer disposition is **ship for the scored View contrast fix only**: the label/chevron are readable in corrected wide Light/Graphite captures, with no regression at that fix scope. Earlier titlebar and folder-heading fixes were also scored resolved. This is not full-surface acceptance. Compact/780pt capture was blocked by `CUA returned noWindowsAvailable` during edge resizing; full accessibility, high contrast, System appearance transitions and actual window dragging remain unverified. Image-generated concepts are design references, not native QA. The web build-phase remains a spec with unsuitable font/raster gates; it has not passed for this native application.

Captures: `.impeccable/review/still-final-wide.png`, `still-final-folders.png`, `still-final-native-zoom.png`, `still-final-light.png`, `still-final-blocked-light.png`, `still-final-palette-light.png`, `still-menu-fixed-light.png` and `still-menu-fixed-dark.png`.

### Historical verification contract

Review actual native wide and compact windows in both appearances, default gallery, expanded filters, active palette, selection/paired inspector and blocked query states. Local checks must cover schema migration, old/new recipe decoding, palette persistence and invalidation, missing previews, offline originals, exact constraints and collapsed-pair selection. No web detector or proxy capture applies to SwiftUI/AppKit. Full accessibility and measured retrieval/performance remain separately scoped evidence.

Historical native evidence 2026-10-02 (previous canvas, not the Still redesign): wide/light and compact/dark captures in `.impeccable/review/canvas-*.png`; palette, filters, blocked query and paired inspector covered. Repeated deep scroll reaches the end of 3,416 logical photos and native AX remains responsive. Main-thread SwiftUI lazy-layout freeze replaced with deterministic geometry and off-main thumbnail decoding (512px, four workers, 64MiB/256-image cache). 20,000-photo geometry invariants pass at three widths; this is not a frame-rate benchmark. Space preview, spatial Down selection and JPEG/NEF member switching checked.

## People extension — 2026-10-03

People is an ordinary extension of the quiet photo canvas. Reveal the sidebar and choose People to browse anonymous circular face avatars with logical-photo counts. Selecting one opens its currently detected matches in the existing full-proportion gallery, with People return and Restore Excluded Photos actions above the search row. No names or identity-aware natural-language clauses are shipped.

The avatar browser replaces the search/status rows with its own compact People heading, checked-preview coverage and native controls. First visit starts pending recognition; four-preview batches run in a dedicated local YuNet/SFace worker. Pause stops further batches after the current work; Find People or Scan New Photos resumes pending previews, and Retry Failed explicitly retries failures. Counts and membership remain partial while scanning. Empty and worker-error states retain explanatory text. Right-click an avatar for Merge with Another Person…; its native sheet presents other anonymous avatars. Right-click a person-gallery photo for Not This Person; Restore Excluded Photos reverses that person's exclusions. Merge aliases and per-person exclusions persist in the local catalog through reindexing and changed detection order. Originals remain untouched; photos, face crops, weights and generated reports remain outside Git.

Reported local verification: release build and 22 Python checks passed, including merge redirects and exclusion persistence across changed detection order, reindexing and restore. A real recognition probe checked 64 previews, producing 25 groups with zero scan failures; one avatar and two source photos were checked as the same person. This is bounded evidence, not broad recognition-quality acceptance. Small, profile or occluded faces may be missed; identities may split or be confused.

After the Mac unlocked, native final-release checks verified People entry automatically starts scanning, Pause, avatar selection opening 11 photos, Not This Person changing 11 to 10, Restore returning 10 to 11, and merge chooser/cancel. Captures in `.impeccable/review/` cover `people-browser-wide.png`, `people-browser-compact.png` (natively resized), `people-person-wide.png` and `people-merge.png`; the avatar circle-fill correction was checked. Fresh visual review is pending; no review ship verdict is claimed. Native QA remains incomplete for dark appearance, high contrast, full keyboard/accessibility behavior and empty/failure/finished-scan states. Resume/retry, gallery return and executing a merge also require native verification. Broad recognition accuracy remains unverified. Earlier canvas approval does not sign off this extension. Build and check locally with no CI or paid services. The approved Still identity supersedes the former palette/navigation guidance; this extension does not receive new QA by inheritance.

People refinement: existing neutral avatar layout now offers Refine Groups beside Scan New Photos when idle. It consolidates strongly supported groups; future matching uses group face averages instead of one initial representative. Co-occurring faces/exclusions block automatic consolidation, RAW/JPEG pairs supply one unit of evidence, and complete-link checks prevent merge chains. The confirmed screenshot pair received an explicit correction. Native refinement action verified; broader identity accuracy is unmeasured. This supersedes the initial single-representative matching description.
