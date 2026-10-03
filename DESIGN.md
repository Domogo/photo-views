---
name: Photo Views
description: A quiet native photo canvas with clear, editable views.
spacing:
  control-gap: "8pt"
  content-inset: "20pt"
  section-gap: "24pt"
  gallery-gutter: "8pt"
  gallery-inset: "12pt"
---

# Design System: Photo Views

## Overview

**Creative North Star: "Photo Workbench"**

Selected by the user on 2026-10-02, refreshed with the approved quiet photo canvas revision. The interface is minimal, bespoke, and intuitive: photographs dominate, familiar macOS controls explain actions, and precise hierarchy and context-preserving interactions provide the craft. Supporting panes remain available while the initial workspace gives images the window.

Neutral surfaces follow system appearance. One natural-language search row leads exploration; exact constraints remain readable and individually removable. Full image proportions and narrow masonry gutters create the flowing gallery. Motion never decorates waiting or animates an entire archive.

**Key Characteristics:**

- Photograph-led neutral surroundings and full image proportions.
- Familiar native interaction with optional supporting panes.
- One search row with refinement on demand.
- Explicit selection, availability, coverage, and provenance.

The workspace contract is `.impeccable/surfaces/main-workspace.md`. This document records the implemented SwiftUI/AppKit source, not a web or iOS translation. Source compilation and local catalog/search checks passed, including deterministic geometry checks for 20,000 items at three widths (approximately 7ms for that check). Revised native wide/light and compact/dark rendered QA is complete. Captures in `.impeccable/review/` cover `canvas-wide-gallery.png`, `canvas-wide-filters.png`, `canvas-wide-palette.png`, `canvas-wide-blocked-query.png`, `canvas-wide-pair.png`, `canvas-compact-dark-gallery.png` and `canvas-compact-dark-filters.png`. Reviewer disposition is **ship at the two-fix-list scope**: both material fixes (blocked-query status and stale documentation) are resolved, with no remaining findings in that follow-up. Source and corrected native state say “Search not run” and “Search needs correction”. This disposition does not constitute whole-surface, general performance or accessibility signoff. The normal app was reopened with the final build and natively verified; schema-5 catalog state retained 19,877 files, two saved views and 5,085 palettes. Earlier M1/M7 screenshots do not verify this revision. Full accessibility, broad retrieval quality and frame-rate benchmarking remain unverified. No web detector or HTML/iOS proxy applies to this native app.

## Colors

Appearance-aware neutrals and the user's macOS accent keep the photographs visually dominant. Light or dark appearance is a user setting, not a fixed brand palette.

### Primary

Use `NSColor.controlAccentColor` for the 2pt gallery selection outline. AppKit owns collection focus behavior. Native actions and sidebar selection follow the system accent. Validate all supported accent choices and increased contrast rather than assume readability.

### Neutral

The workspace canvas uses `Color(nsColor: .textBackgroundColor)`; inspector and unfilled photo cells use `.controlBackgroundColor`. Primary text uses native defaults, supporting text `.foregroundStyle(.secondary)`, separators `Divider()`, and sidebar selection native `List(selection:)`. These dynamic roles have no fixed CSS or hex equivalents. Palette swatches are named native colors with text labels and a selected checkmark; they indicate a search family, not calibrated photograph color values.

**The Photograph Rule.** Keep decorative color out of the image canvas; actual photographs carry the palette.

**The State Rule.** Color supplements meaningful state and never serves as its sole explanation.

## Typography

Use macOS system SF typography and native text styles, sentence case and normal tracking. No decorative display face or fixed SF font metrics. Inspector headings use `.headline`; section labels and similar-photo state use `.subheadline`; recipe/tag headings use `.subheadline.weight(.semibold)`; filenames/source headings use `.body.weight(.medium)`. Supporting metadata and coverage use `.caption`. Empty-state titles use `.title2.weight(.semibold)` and sheet titles `.title3.weight(.semibold)`; their SF Symbols use 36pt light. The unsaved-state symbol is 5pt and has an accessibility label. Counts and the palette percentage use `.monospacedDigit()` where implemented.

**The Label Rule.** Core actions have readable labels; icons support meaning. The image-only gallery retains filenames and availability in accessibility labels and the inspector.

## Layout

The initial sidebar and inspector are hidden. Sidebar visibility persists in `gallerySidebarVisible`; selecting a photograph opens its inspector, and toolbar controls toggle both panes. `HSplitView` retains source-defined widths: sidebar 180/220/300pt minimum/ideal/maximum, inspector 220/260/340pt, central minimum 360pt. The window retains a 780 × 520pt minimum content frame and 1180 × 760pt default size.

The search row contains the plain search field, Filters and View with 8pt gaps, 12pt horizontal and 10pt vertical padding. Active chips use a horizontal scroll row with 6pt gaps. Filters expands a scrollable drawer bounded to `max(120, min(280, availableHeight - 250))` pt. Query-plan review is 180pt high; optional syntax help is 70pt. Result and indexing counts share a compact disclosure row with 12pt horizontal and 6pt vertical padding; detailed progress and retries expand only on demand.

The gallery uses recycled `NSCollectionView` cells with deterministic shortest-column masonry geometry, 8pt gutters and 12pt outer insets. Column count is `max(1, Int((availableWidth - 24 + 8) / 208))`; this is the source's 208pt column sizing target, with final widths distributed across the available space. Each next result is placed in the shortest column. Orientation values 5–8 swap recorded width/height for aspect calculations; missing dimensions use a square. Full photo height follows the resulting aspect ratio. One continuous layout spans all results with no group headings or section gaps; grouping affects order only; no filenames, format captions or permanent photo overlays occupy the gallery. Visible cells are recycled; incremental loading extends results near the scroll end. Selected identity or a visible scroll anchor is restored on regrouping. ImageIO decodes gallery thumbnails in background operations to a maximum 512px dimension, with at most four concurrent operations, cancellation on reuse, and a cache limited to 64MiB/256 images. This replaces the SwiftUI lazy masonry implementation after a deep-scroll hang.

The Workbench constants remain control gap 8pt, inspector content inset 20pt and section gap 24pt. Saving/collection sheets use 24pt padding and a 400pt width; empty explanation text has a 380pt maximum width. These are native point values, not browser breakpoints.

**The Stable Place Rule.** Keep primary controls consistent and preserve meaningful selection through organization changes where possible.

## Elevation & Depth

Flat content surfaces, tonal separation and native pane separators establish hierarchy. Native menus, sheets and previews supply their own transient elevation. Photographs do not sit in individually shadowed cards. No decorative glow, glass or whole-gallery entrance animation is introduced.

## Shapes

Native controls own radii, focus and hover rendering. Photo cells are rectangular, show full proportions through `NSImageView.scaleProportionallyUpOrDown`, and use a 2pt accent selection outline without obscuring content. AppKit collection focus and photo selection remain separate concepts. Palette dots are 10pt circles with a 0.5pt secondary outline. There is no custom radius scale; native rounded-border fields remain native.

## Components

### Search and View

The plain field says “Describe a photo…” in natural-language mode; filename/keyword mode is selected in View. Plain visual descriptions use debounced retrieval. Supported mixed queries apply on Return; an editable bounded plan exposes exact constraints, palette, grouping, ambiguous and unsupported clauses. Invalid plans disable Apply Plan and report “Search not run” / “Search needs correction” rather than a false zero-result or no-match claim. Native checks confirmed “mostly green format:ARW” applies exact chips on Return and an invalid location clause blocks execution. Help appears on demand. View contains search mode, grouping, sorting, saving/updating/reverting, RAW+JPEG collapse/restore and refresh. Ranked results disable manual sort. Saved definition changes remain explicit.

### Exact and palette chips

Small native buttons name every active exact constraint and remove it individually. The palette chip names its dominant color and minimum area; removing it clears only palette. Icon removal affordances have accessibility labels. No silent constraint relaxation is permitted.

### Expanded filters and overall palette

A bounded scrollable drawer starts with Minimum match score for visual mode (0–1 in 0.01 steps, text default 0.20/reference default 0.75; cosine similarity, not probability), followed by named swatches, minimum-area slider, camera, folder, date and confirmed-tag controls, with additional metadata in a disclosure. The slider spans 5–100% in 5% steps; default minimum is 25%. The selected family must be the largest family in a coarse versioned local HSV-area histogram (`srgb-hsv-area-v1`) and meet that minimum. This means dominant family, not a majority of pixels or detection of colored objects. “Mostly blue” can request palette; “blue car” remains visual intent. Partial coverage stays visible, missing/failed palettes do not silently match, and retries are explicit. Cached palette data is versioned and invalidated with changed files.

### Image-only masonry gallery

Recycled AppKit collection items preserve full orientation-aware proportions without captions or decorative cards. Selection opens details; double-click or Space opens preview. Arrow keys use spatial masonry navigation. Accessibility labels include filename and preview/original availability. Context actions provide Preview, Find Similar and Reveal Original in Finder. RAW+JPEG member switching preserves the logical gallery highlight while per-file metadata and organization remain distinct. Native checks confirmed Down changes selection, Space opens preview and JPEG/NEF pair-member switching works. A 3,416-item logical gallery reached the bottom and remained responsive; an idle observation showed 0% CPU and approximately 258MiB RSS. These are bounded session observations, not a frame-rate benchmark or broad performance guarantee.

### Status, empty and failure states

One disclosure row combines result count and indexed coverage. Expanded details expose preview, visual-search and palette progress, pause/resume/retry controls and individual failures. No-source, indexing, no-match and catalog failure states use SF Symbols, readable native titles, explanatory text and actions. Active constraints remain present when no results match. Offline original availability is explicit in details; cached previews and metadata remain useful.

### Optional navigation and inspector

Native sidebar List provides All photos, Favorites, Sources, Saved Views and Collections. Source rows retain availability and access actions. The inspector uses ScrollView, LabeledContent and Divider for selected photo/source information, preview, pair members, confirmed/suggested tags, favorite/collection actions, original availability and recipe summary. Supporting information becomes available when needed rather than permanently consuming gallery space.

### Sheets and native controls

Save View and New Collection use rounded-border name fields, native buttons, Cancel/default keyboard shortcuts and blank-name disabling. Saving summarizes the recipe including palette. SwiftUI/AppKit own button, picker, menu, focus and hover appearance. No HTML/CSS replicas or raster assets define this native system.

## Do's and Don'ts

### Do:

- **Do** give photographs the greatest visual area, full proportions and neutral surroundings.
- **Do** use native controls, focus behavior, SF typography and system appearance.
- **Do** keep exact constraints, coverage, availability and palette meaning readable.
- **Do** distinguish keyboard focus, selection, tag provenance and paired-file identity.
- **Do** preserve context through grouping, source changes and indexing.

### Don't:

- **Don't** add persistent captions, card frames or decorative overlays to the gallery.
- **Don't** hide incomplete coverage, offline availability or blocked query clauses.
- **Don't** equate a coarse dominant palette with object detection or calibrated color understanding.
- **Don't** invent fixed dynamic colors, native radii or SF font metrics.
- **Don't** claim revised visual/accessibility signoff from compilation or earlier milestone screenshots.

Ranked search no longer caps results at 100. It filters cosine similarity before fusion and logical-photo collapse, then exposes loaded/total qualifying counts and extends by 500 near the scroll end. Defaults are provisional rather than calibrated certainty. Native check: birds at 0.19 expanded from 500/694 to 694/694 on scrolling.

Visual and reference searches keep near-identical shots adjacent by default (View · Similar shots), while explicit month/camera/subject grouping remains available. Anchor-based grouping requires image cosine similarity ≥ 0.92 and a 64-bit preview difference-hash distance ≤ 20; low-contrast previews (grayscale standard deviation < 5) and missing hashes are excluded. These are provisional heuristics, not calibrated duplicate probabilities. Every photo remains individually selectable at its full proportions, groups receive no headings, and pagination extends a boundary to include the entire group. Native verification found DSC06059.ARW and DSC06060.ARW together and placed the two poster shots side by side. Background indexing refreshes avoid cancelling a pending query.

Grid zoom: compact minus/plus magnifier buttons beside View and View-menu commands support ⌘− / ⌘+; ⌘0 resets. Seven persisted size steps adjust column density while preserving full photo proportions and the first visible photo on zoom. Native button and keyboard verification confirmed larger images/fewer columns, zoom out and reset.

People extension (2026-10-03): the existing Photo Workbench system also supports anonymous face browsing. Source-defined circular cropped avatars (112pt), caption photo counts, adaptive columns (132–180pt), 24pt grid gaps and 20pt content padding sit on the same neutral canvas. Native labeled scan controls expose checked-preview coverage, failures, Pause, Scan New Photos and Retry Failed. First visit starts pending local recognition in four-preview background batches. Selecting an avatar returns to the existing full-proportion photo gallery; no identity names are inferred. Right-click an avatar to choose Merge with Another Person… in a native sheet; right-click a matching photo for Not This Person. Restore Excluded Photos reverses that person's exclusions. Anonymous merge redirects and exclusions persist locally through reindexing, including changed detection order. Groups remain provisional suggestions and may miss faces or split/confuse identities. This ordinary extension preserves the incumbent tokens and `.impeccable/design.json`.

People verification is separate from earlier canvas approval. Reported local evidence: release build passed; 22 Python checks passed, including merge redirect persistence and exclusion/reindex/restore behavior; recognition processed 64 previews into 25 groups with zero scan failures, and a real avatar and two source photos were checked as the same person. This small probe is not an accuracy benchmark. After the Mac unlocked, the final release was checked natively for first-entry automatic scanning, Pause, avatar selection opening 11 photos, Not This Person reducing that gallery to 10, Restore returning it to 11, and merge chooser/cancel. Wide and natively resized compact People browser, person gallery and merge captures are `.impeccable/review/people-browser-wide.png`, `people-browser-compact.png`, `people-person-wide.png` and `people-merge.png`; the avatar circle-fill correction was checked. Fresh visual review is pending; no review ship verdict is claimed. Dark appearance, high contrast, complete keyboard/accessibility coverage, empty/failure/finished-scan states and broad recognition accuracy remain unverified. Photos, face crops, weights and probe reports remain outside Git; originals remain read-only and checks run locally without CI or paid services.
