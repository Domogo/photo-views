---
name: Still
description: A quiet photographic Mac workspace in Graphite, with Atelier navigation.
colors:
  graphite-canvas: "#1D201F"
  graphite-pane: "#242826"
  jade-dark: "#9EB9A8"
  secondary-dark: "#B7BDB8"
  secondary-light: "#5A605B"
  light-canvas: "color(srgb 0.969 0.965 0.949)"
  light-pane: "color(srgb 0.941 0.937 0.918)"
  jade-light: "color(srgb 0.20 0.37 0.33)"
  photo-actions-background: "color(srgb 0.08 0.09 0.085 / 0.94)"
  photo-actions-foreground: "color(srgb 0.96 0.96 0.96)"
typography:
  navigation:
    fontFamily: "system-ui"
    fontSize: "13pt"
    fontWeight: 400
  navigation-active:
    fontFamily: "system-ui"
    fontSize: "13pt"
    fontWeight: 600
rounded:
  search: "6pt"
  view-menu: "5pt"
  gallery-actions: "5pt"
spacing:
  control-gap: "8pt"
  content-inset: "20pt"
  section-gap: "24pt"
  gallery-gutter: "8pt"
  gallery-inset: "12pt"
  header-inset: "16pt"
  navigation-gap: "18pt"
  gallery-actions: "4pt"
components:
  workspace-header:
    backgroundColor: "{colors.graphite-pane}"
    height: "52pt"
  search-field:
    backgroundColor: "{colors.graphite-canvas}"
    rounded: "{rounded.search}"
    padding: "8pt 10pt"
  navigation-active:
    textColor: "{colors.jade-dark}"
    typography: "{typography.navigation-active}"
  gallery-action-toolbar:
    backgroundColor: "{colors.photo-actions-background}"
    textColor: "{colors.photo-actions-foreground}"
    rounded: "{rounded.gallery-actions}"
    padding: "{spacing.gallery-actions}"
  gallery-action:
    textColor: "{colors.photo-actions-foreground}"
    size: "26pt"
---

# Design System: Still

## Overview

**Creative North Star: "Atelier in Graphite"**

Still is a quiet photographic workspace: understated, minimal, modern and bespoke. The user approved Graphite color, Atelier top navigation, and the Open Frame identity. Photographs supply the visual richness; precise geometry and sparse controls supply the craft. The approved composition is `.impeccable/mocks/comp-3.png`; the selected filled opposing-corner logo supersedes that concept's older outlined mark.

This is an extracted native SwiftUI/AppKit design system. Brand.swift owns appearance colors and vector identity; WorkspaceView.swift owns navigation and controls, PhotoInspector.swift owns selected-photo actions, and NativePhotoGallery.swift owns recycled gallery interaction. The user authorized subtle interaction animation within this established world. Motion supports local reveals and state changes while the archive remains stable.

Latest release build, code-signature verification, CatalogChecks and `scripts/check_workspace.py` passed. The icon asset and native wide workspace captures were opened and validated. Fresh reviewer disposition is **ship for icon hardening only**: no material icon geometry or code issue was found, packaging and runtime icon installation are resolved in implementation, and actual Dock appearance remains unverified. This does not verify editor handoff or grant full-surface acceptance.

Earlier wide native interaction captures cover the action-first inspector in Graphite/Light, expanded Metadata, similarity return, a selected person, Light filters and corrected Collections controls in both appearances. Native accessibility actions verified favorite toggle/revert, installed editor presence, metadata disclosures, Collections opening its native menu, and an 80-photo person gallery returning to avatars and All photos (13,181 logical photos). That review returned **ship for three scored fixes only**: Collections contrast in Light/Graphite including Light → Graphite, cache invalidation, and resuming canceled browse queries. No visible regression was found at that correction scope. Compact layout, pointer-only hover, measured motion/Reduce Motion timing and transient pagination feedback lack current capture evidence; full accessibility, high contrast, System appearance transitions and actual window dragging remain unverified.

Direct Photomator handoff remains unresolved: correct RAW/JPEG original paths and successful macOS file-opening requests were verified, but Photomator stayed in its photo browser. Double-clicking the paired JPEG in Photomator’s own browser opened it in the editor, with its document URL verified; no edits or saves were made. Finder’s Open With option confirms Photomator registration, while entering the editor through Finder is still unverified. Lightroom was absent and unverified. Historical canvas and earlier Still review do not supply current acceptance. See the workspace brief for the bounded evidence record.

**Key Characteristics:**

- Graphite by default, with Light and System choices.
- Sharp vector identity and native functional typography.
- Top navigation and supporting tools on demand.
- Full-proportion photographs with clear constraints, coverage and availability.

## Colors

The palette is a subdued graphite with a slight green cast, warm light neutrals and restrained jade. The exact source sRGB values are normative in the frontmatter; they follow StillBrand's appearance providers.

### Primary

Jade supplies active navigation text and its 2pt underline, native tint and the gallery's 2pt selection outline. Use `jade-dark` in dark appearance and `jade-light` in light appearance. Color supports named state, selected traits and focus; it never supplies the sole explanation.

### Neutral

Canvas recedes behind photographs; pane separates navigation, folders and details tonally. Dark uses graphite-canvas/graphite-pane; light uses light-canvas/light-pane. Folder, Saved Views and Collections headings use secondary-dark/secondary-light. Other primary/secondary text, dividers, focus and menus retain native semantic rendering. The small gallery action toolbar retains a dark photo-actions-background with photo-actions-foreground symbols in both appearances so it stays readable over images. Palette-search swatches express named search families, not calibrated photograph colors.

**The Photograph Rule.** Keep decorative color out of the image canvas.

## Typography

Functional text uses macOS system SF and native styles. Navigation is 13pt regular, with semibold active destination. Inspector headings use headline; recipe headings use subheadline semibold; source headings use body medium; metadata and coverage use caption. Sheet and empty titles use native title3/title2 semibold. Use monospaced digits for counts where implemented; do not invent fixed SF metrics.

The lowercase **still** wordmark is custom vector artwork, not a font: a chamfered squared s, squared t, square i dot and straight paired l stems. The signature places a 22pt mark beside a 48 × 20pt wordmark with 9pt gap, grouped under the accessibility label Still. Functional UI remains real text. StillWindowChrome retains native controls and sets background dragging in source; actual dragging has not been verified.

**The Label Rule.** Core actions remain understandable through text, menus, tooltips and accessible names.

## Layout

A 52pt top header places the signature, All photos/Favorites/People tabs, and compact tools above the archive. It integrates into the native titlebar through StillWindowChrome and ignores the top container safe area. An 80pt leading reserve keeps identity clear of native traffic lights, in addition to the normal 16pt horizontal inset; header groups are separated by 20pt and tabs by 18pt. At available width ≥1180pt, browsing photos uses one unified navigation/search header. Below 1180pt search occupies the second row. People browsing keeps its own controls. This is a native window threshold, not a browser breakpoint.

Folders, saved views and collections are an optional pane behind the folder icon; there is no permanent navigation rail. Its widths are 180/220/260pt minimum/ideal/maximum. Contextual inspector widths are 220/260/340pt; central minimum is 360pt. Window minimum is 780 × 520pt and default is 1180 × 760pt. Appearance and folder visibility persist. Search uses 8pt gaps and 10pt horizontal/8pt vertical internal padding. Filters remain bounded and scrollable; controls and chips appear as needed.

The recycled NSCollectionView gallery uses shortest-column masonry, 8pt gutters and 12pt insets. Full orientation-aware photo proportions remain intact; missing dimensions use a square fallback. Grouping changes order without headings or section gaps. Grid zoom changes density while preserving context. Do not put persistent filenames, captions or format labels on photographs. Background ImageIO decoding and bounded caching remain implementation constraints, not visual decorations.

## Elevation & Depth

Flat tonal surfaces and separators establish hierarchy. Native menus, sheets and previews own transient elevation. Do not add shadows to individual photographs or decorative glass/glow. The gallery action toolbar uses its source-defined dark translucent fill rather than a shadow. No archive-wide entrance animation; preserve selection and visible context when organization changes.

Local filter and pane reveals, plus Metadata and RAW+JPEG disclosures, use 180ms ease-out. Gallery quick actions use a 120ms AppKit alpha fade. Reduce Motion removes these transitions. These values describe source behavior; measured timing and pointer-only hover remain unverified.

## Shapes

The selected Open Frame mark consists of two filled opposing 90° corners with square edges, one top-left and one bottom-right. Preserve Brand.swift's exact normalized polygons and negative space; do not redraw as open stroked frames or round the corners. Resources/Brand/mark.svg and the generated Still.icns are identity assets. scripts/build_brand.swift regenerates the native icon, whose rounded container is separate from the angular mark. Icon hardening preserves this approved asset and geometry: scripts/build_app.py packages the unchanged Still.icns under the content-derived resource name Still-dcbef2ca25bb, sets bundle version 2, and retains com.domogo.photoviews. At launch, StillApplicationDelegate loads the exact resource named by CFBundleIconFile into NSApplication.applicationIconImage. The asset raster is verified; the running Dock appearance still requires direct capture.

The search container has a source-defined 6pt radius and 1pt outline: primary text color at 12% opacity at rest, jade while focused. The compact gallery action toolbar has a 5pt radius. Native controls own their own radii and focus states. Photographs remain rectangular; People avatars remain circular.

## Components

### Signature and top navigation

Use the compact filled vector signature once in the header. All photos, Favorites and People are plain native buttons; active state uses jade, semibold weight, 2pt underline and the selected accessibility trait. Folder, Add Folder and Inspector tools have accessible names, tooltips and native interaction. Keep navigation stable while refining a query.

### Search and View

The inset plain native field says “Find a moment…” in visual mode and “Search filenames or folders…” in keyword mode. In a unified header it uses canvas against pane; in the split search row it uses pane against canvas. Focus receives jade outline. Clear search has an accessible label. Filters, zoom and View remain adjacent. View uses a borderless native Menu with the default indicator hidden, an explicit primary-text label and 8pt semibold chevron, 6pt gap, 8pt horizontal/4pt vertical padding, 5pt radius and 6% primary-color source background. Native rendering supplies its final menu treatment. View includes appearance choices Dark/Light/System, search mode, grouping, sorting, saving, pairing and refresh. Graphite dark is the initial default.

Plain visual descriptions use debounced retrieval. Supported mixed queries apply on Return; unsupported or ambiguous clauses remain visible for correction. Blocked plans say Search not run/Search needs correction; never imply an executed zero-result search. Constraints remain individually removable and saved definitions update explicitly. In Similar photos, the x action is labeled Clear similarity search and keeps current filters and membership scope. The separate Back to all photos action clears search, reference, source, favorite, collection and person membership scope, exact/palette constraints and saved-view selection; grouping, sorting and pair-collapse presentation persist.

### Exact and palette chips

Small native buttons name every active exact constraint and remove it individually. The palette chip names its dominant color and minimum area; removing it clears only palette. Icon removal affordances have accessibility labels. No silent constraint relaxation is permitted.

### Expanded filters and overall palette

A bounded scrollable drawer starts with Minimum match score for visual mode (0–1 in 0.01 steps, text default 0.20/reference default 0.75; cosine similarity, not probability), followed by named swatches, minimum-area slider, camera, folder, date and confirmed-tag controls, with additional metadata in a disclosure. The slider spans 5–100% in 5% steps; default minimum is 25%. The selected family must be the largest family in a coarse versioned local HSV-area histogram (`srgb-hsv-area-v1`) and meet that minimum. This means dominant family, not a majority of pixels or detection of colored objects. “Mostly blue” can request palette; “blue car” remains visual intent. Partial coverage stays visible, missing/failed palettes do not silently match, and retries are explicit. Cached palette data is versioned and invalidated with changed files.

### Image-only masonry gallery

Recycled AppKit collection items preserve full orientation-aware proportions without captions or decorative cards. Hover uses a 1pt secondary outline; selection uses a 2pt jade outline and opens details. Hover or selection reveals Favorite and an installed-editor action at the top right, inset 8pt, with 26pt buttons and 4pt padding/gap. A single editor opens directly; multiple editors use a native menu. Original availability disables editor actions. Symbols, tooltips and accessible labels reflect favorite state. Action closures rebind to every configured asset even when a reused cell retains the same preview image key; reuse clears old actions and images.

Double-click or Space opens preview. Arrow keys use spatial masonry navigation. Accessibility labels include filename and original availability. Context actions provide Preview, Find Similar and Reveal Original in Finder. RAW+JPEG member switching preserves the logical gallery highlight while per-file metadata and organization remain distinct. Historical canvas checks confirmed Down selection, Space preview and JPEG/NEF member switching. A 3,416-item logical gallery reached the bottom and remained responsive; an idle observation showed 0% CPU and approximately 258MiB RSS. These are bounded session observations, not a frame-rate benchmark or broad performance guarantee.

### Status, empty and failure states

One disclosure row combines result count and indexed coverage. Expanded details expose preview, visual-search and palette progress, pause/resume/retry controls and individual failures. Loading another 500-photo page keeps displayed images and adds a small bottom spinner with Loading more photos…; failure keeps those images and offers Retry. No-source, indexing, no-match and catalog failure states use SF Symbols, readable native titles, explanatory text and actions. Active constraints remain present when no results match. Offline original availability is explicit in details; cached previews and metadata remain useful.

Return browsing may show up to six cached first pages, each bounded to 500 metadata records, while a worker refresh runs in the background. Keys preserve browse membership and sorting/pairing state; search, reference, palette and exact-filter results are never inferred from a broader cached page. Catalog/index changes, favorite/collection membership, pairing and availability changes invalidate browse pages. Person recognition/corrections invalidate person-scoped pages without flushing unrelated browsing. Entering People cancels pending photo search; returning to All resumes querying even after cancellation.

### Optional navigation and inspector

Top navigation provides All photos, Favorites and People. The optional native sidebar List provides Folders, Saved Views and Collections. Source rows retain availability and access actions. The selected-photo inspector starts with filename, Favorite and Preview, then Open in installed Photomator/Lightroom editors. Discovery uses Launch Services and Applications folders; absent editors are omitted and unavailable originals disable opening. This requests opening the selected original through macOS without changing catalog or file semantics. Direct Photomator opening remains unresolved in the latest native check.

The preview and original-availability message remain visible, followed by Find Similar, Collections and tags. Collections uses the same explicit primary label/chevron treatment as View. Metadata is a smaller caption-content disclosure, collapsed by default, containing per-file metadata, path and Reveal Original in Finder. RAW+JPEG and View settings also start collapsed. Pair member actions and tags apply to the selected file. Native ScrollView, LabeledContent, Divider, disclosures and small controls retain system behavior; supporting information becomes available when needed rather than permanently consuming gallery space.

### Sheets and native controls

Save View and New Collection use rounded-border name fields, native buttons, Cancel/default keyboard shortcuts and blank-name disabling. Saving summarizes the recipe including palette. SwiftUI/AppKit own button, picker, menu, focus and hover appearance. No HTML/CSS replicas or raster assets define this native system.

### People and continuity

People uses the top navigation and anonymous circular avatars, native scan/refine controls, explicit partial coverage and contextual person-gallery actions. Back to People returns a selected person gallery to avatars; All photos clears person membership scope. The existing recognition caveats, reversible merges/exclusions and local-only processing remain product behavior. Its earlier native probes are historical, not this refinement's visual acceptance.

Still.app keeps `com.domogo.photoviews` and existing Photo Views catalog/cache locations. Identity changes do not create a new catalog, change originals or promise new recognition capabilities.

## Do's and Don'ts

### Do:

- **Do** keep the approved Graphite/Atelier composition and selected filled-corner identity.
- **Do** use appearance-aware source colors, native SF text and keyboard/menu behavior.
- **Do** preserve full proportions, readable constraints and honest file/photo counts.
- **Do** make folders, filters and details available on demand.
- **Do** keep immediate photo actions visible and secondary Metadata, RAW+JPEG and View settings collapsed initially.
- **Do** bind quick actions to the current asset and retain images during pagination loading or failure.
- **Do** use the bounded interaction motion and remove it with Reduce Motion.
- **Do** validate the actual native implementation; wide Light/Graphite evidence does not cover compact layout.

### Don't:

- **Don't** restore a permanent navigation rail or replace the selected mark with the concept's outlined mark.
- **Don't** use custom logo lettering as the functional UI typeface.
- **Don't** add gallery captions, decorative cards, glass or archive-wide animation.
- **Don't** hide partial coverage, unavailable originals or blocked query clauses.
- **Don't** claim new-world QA passed from earlier captures.
