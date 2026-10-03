# Main workspace — Quiet photo canvas

Status: revised direction approved by the user, 2026-10-02; native implementation and capture checks completed; the reviewer scored both requested corrections resolved, with ship at the fix-list scope.
Primary target: Sources/PhotoViewsApp/WorkspaceView.swift
Related targets: Sources/PhotoViewsApp/PhotoGrid.swift, Sources/PhotoViewsApp/NativePhotoGallery.swift, Sources/PhotoViewsCore/GalleryGeometry.swift

## Scope and mode

Native macOS main workspace. Operate mode with photographs leading exploration. PRODUCT.md and prd.md retain product truth; this approved revision changes presentation and adds overall-palette search. Native controls, local processing, read-only originals, saved views, exact constraints, keyboard navigation and RAW+JPEG integrity remain binding.

## Direction contract

**THESIS:** A quiet photo canvas gives photographs the available window. One natural-language input leads retrieval; supporting controls appear when useful.

**OWN-WORLD:** Appearance-aware neutral canvas, SF typography, compact labeled native controls, flat panes and quiet separators. The first user reference (CAP's dark flowing gallery) is the composition authority: image scale, full proportions, narrow gutters and receding controls. The second reference contributes contextual details and organization, placed in optional panes rather than an always-open assistant. Neither reference supplies branding, claims or imagery for this product.

**FIRST VIEWPORT:** Navigation and inspector begin hidden. One horizontal search row contains Describe a photo…, Filters and View. One small result/indexing status row precedes a broad image-only masonry gallery. No permanent example, syntax instructions, live-view explanation, cards or caption row. Existing saved grouping affects order only; photos share one continuous masonry layout with no headings or section gaps.

**SIGNATURE:** Describe → inspect images → refine only as needed. Filters expands a bounded scrollable drawer. Each active exact constraint is individually removable; the palette constraint states its color and minimum area. Valid supported mixed queries apply on Return; ambiguous/unsupported clauses block execution for correction. Plain visual descriptions retain debounced retrieval. View contains filename/keyword mode, grouping, sorting, saving and pairing controls. Saved definitions update explicitly.

**MOTION:** No entrance animation or whole-gallery animation. Stable result identity and scroll anchor preserve context during regrouping. Optional panes and filters remain understandable with immediate transitions and reduced motion.

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

Review actual native wide and compact windows in both appearances, default gallery, expanded filters, active palette, selection/paired inspector and blocked query states. Local checks must cover schema migration, old/new recipe decoding, palette persistence and invalidation, missing previews, offline originals, exact constraints and collapsed-pair selection. No web detector or proxy capture applies to SwiftUI/AppKit. Full accessibility and measured retrieval/performance remain separately scoped evidence.

Native evidence 2026-10-02: wide/light and compact/dark captures in `.impeccable/review/canvas-*.png`; palette, filters, blocked query and paired inspector covered. Repeated deep scroll reaches the end of 3,416 logical photos and native AX remains responsive. Main-thread SwiftUI lazy-layout freeze replaced with deterministic geometry and off-main thumbnail decoding (512px, four workers, 64MiB/256-image cache). 20,000-photo geometry invariants pass at three widths; this is not a frame-rate benchmark. Space preview, spatial Down selection and JPEG/NEF member switching checked.

## People extension — 2026-10-03

People is an ordinary extension of the quiet photo canvas. Reveal the sidebar and choose People to browse anonymous circular face avatars with logical-photo counts. Selecting one opens its currently detected matches in the existing full-proportion gallery, with People return and Restore Excluded Photos actions above the search row. No names or identity-aware natural-language clauses are shipped.

The avatar browser replaces the search/status rows with its own compact People heading, checked-preview coverage and native controls. First visit starts pending recognition; four-preview batches run in a dedicated local YuNet/SFace worker. Pause stops further batches after the current work; Find People or Scan New Photos resumes pending previews, and Retry Failed explicitly retries failures. Counts and membership remain partial while scanning. Empty and worker-error states retain explanatory text. Right-click an avatar for Merge with Another Person…; its native sheet presents other anonymous avatars. Right-click a person-gallery photo for Not This Person; Restore Excluded Photos reverses that person's exclusions. Merge aliases and per-person exclusions persist in the local catalog through reindexing and changed detection order. Originals remain untouched; photos, face crops, weights and generated reports remain outside Git.

Reported local verification: release build and 22 Python checks passed, including merge redirects and exclusion persistence across changed detection order, reindexing and restore. A real recognition probe checked 64 previews, producing 25 groups with zero scan failures; one avatar and two source photos were checked as the same person. This is bounded evidence, not broad recognition-quality acceptance. Small, profile or occluded faces may be missed; identities may split or be confused.

After the Mac unlocked, native final-release checks verified People entry automatically starts scanning, Pause, avatar selection opening 11 photos, Not This Person changing 11 to 10, Restore returning 10 to 11, and merge chooser/cancel. Captures in `.impeccable/review/` cover `people-browser-wide.png`, `people-browser-compact.png` (natively resized), `people-person-wide.png` and `people-merge.png`; the avatar circle-fill correction was checked. Fresh visual review is pending; no review ship verdict is claimed. Native QA remains incomplete for dark appearance, high contrast, full keyboard/accessibility behavior and empty/failure/finished-scan states. Resume/retry, gallery return and executing a merge also require native verification. Broad recognition accuracy remains unverified. Earlier canvas approval does not sign off this extension. Keep the incumbent design tokens and sidecar unchanged; build and check locally with no CI or paid services.
