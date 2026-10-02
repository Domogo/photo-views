---
name: Photo Views
description: A minimal native photo workbench with clear, editable views.
spacing:
  control-gap: "8pt"
  content-inset: "20pt"
  section-gap: "24pt"
---

<!-- M1 source scan: 2026-10-02. Rendered M1 review passed with remaining verification limits recorded below; preserve the selected Photo Workbench direction. -->

# Design System: Photo Views

## Overview

**Creative North Star: "Photo Workbench"**

Selected by the user on 2026-10-02. The interface is minimal, bespoke, and intuitive: photographs dominate, familiar macOS controls explain actions, and the craft lives in precise hierarchy and context-preserving interactions.

Neutral surfaces support both system appearances. Controls are compact but readable; secondary information appears where it becomes useful. Bespoke patterns clarify the relationship between search, constraints, and saved views without replacing native affordances.

Motion explains a state change or preserves location. It never decorates waiting or animates an entire large archive. Reduced motion preserves every state with immediate transitions.

**Key Characteristics:**

- Photographs supply the dominant color and visual interest.
- Familiar native interaction with product-specific organization.
- Stable control placement and generous image area.
- Explicit selection, availability, coverage, and provenance.

The main workspace composition and signature view recipe are defined in `.impeccable/surfaces/main-workspace.md`. M1 implements the native catalog shell, source navigation, view recipe settings, saving sheet, and source inspector. Search is disabled, metadata filters explain their future availability, and the content area truthfully reports that no photos have been indexed. Photo grids, preview, retrieval, and tag workflows remain subsequent work.

**Rendered evidence:** `.impeccable/review/m1-source-fixed.png` and `.impeccable/review/m1-compact.png` show the repaired workspace with sidebar, recipe controls, and inspector visible. Reviewer disposition: **ship**, with no blocking findings for the M1 shell. `.impeccable/review/m1-dark.png` was captured and visually checked for readability. The earlier oversized-child rendering defect was fixed by using an explicit native `HSplitView`. Arrow-key sidebar selection is verified. Full Tab traversal, increased-contrast validation, reduced-motion checks, and manual resizing are not fully verified; these remain follow-up checks rather than claims of completed accessibility validation.

## Colors

Restrained neutral palette with one selection/action accent. Follow system appearance: a user searches at a desk under variable ambient light, so neither light nor dark is a mandatory brand treatment.

### Primary

Use the user's macOS accent for active selection and appropriate native primary actions. Focus must remain visible with all supported accent choices; validate rather than assume contrast.

### Neutral

Use appearance-aware neutral canvas and panel surfaces, primary text, secondary text, and separators. The chosen direction establishes light gray/white and graphite families, not implementation hex tokens. The M1 detail canvas uses `Color(nsColor: .textBackgroundColor)`; the inspector uses `Color(nsColor: .controlBackgroundColor)`. Primary text uses the system default and supporting text uses `.foregroundStyle(.secondary)`. Sidebar selection is rendered by native `List(selection:)` without custom row backgrounds; the empty-state Add Folder action uses `.borderedProminent`. Native separators use `Divider()`. These dynamic native roles have no fixed CSS/hex equivalents in this system. Light and dark captures were reviewed for M1 readability; increased contrast and all supported accent choices still need validation.

Status colors use native semantic roles where available and always include a text or icon cue. Suggested tags must not look like errors merely because they are unconfirmed.

**The Photograph Rule.** Keep decorative color out of the image canvas; actual photographs carry the palette.

**The State Rule.** Color supplements a meaningful state and never serves as its sole explanation.

## Typography

Use macOS system SF typography and standard native text styles. No decorative display face. Use tabular figures for counts and aligned numerical metadata; use ordinary text for names, queries, and tags.

Section titles and group headers have greater emphasis than metadata. Body and control labels remain readable; tertiary details do not become tiny labels. Use sentence case and normal tracking. M1 uses native `.title2.weight(.semibold)` for empty-state titles, `.title3.weight(.semibold)` for the saving sheet, `.headline` for inspector and filter headings, `.subheadline.weight(.semibold)` for the inspector recipe heading, `.body.weight(.medium)` for the source heading, and `.caption` for supporting information. Empty-state SF Symbols use `.system(size: 36, weight: .light)`. Remaining labels use native defaults. These adaptive system styles are not fixed font-size or line-height tokens; typography frontmatter is intentionally omitted. Tabular numerical treatment remains future guidance because photo counts are not implemented.

**The Label Rule.** Core actions have readable labels; icons support rather than replace meaning.

## Layout

A compact control rhythm and more generous content spacing distinguish operations from photographs. Align related controls and metadata rather than enclosing every item in a card. The implemented Workbench constants are `controlGap = 8pt`, `contentInset = 20pt`, and `sectionGap = 24pt`. The recipe and inspector use the 20pt inset; inspector sections use the 24pt gap. Other local spacings are source-defined (recipe rows and inspector subgroups 12pt, empty-state items 16pt, saving sheet 20pt with 24pt padding), rather than additional global tokens.

Layouts respond to available Mac window space. Optional supporting panes can collapse; essential actions remain reachable. Preserve useful photo size and readable labels instead of squeezing all three panes indefinitely. M1 sets a minimum content frame of 780 × 520pt and a default window size of 1180 × 760pt. The sidebar column has minimum/ideal/maximum widths of 180/220/300pt; the inspector uses 220/260/340pt. The recipe uses `ViewThatFits(in: .horizontal)` to move scope, grouping, and sorting from a row into stacked arrangements. Group by and Sort pickers have widths of 165pt and 185pt. `HSplitView` owns the native adjustable pane layout, with a 360pt minimum central area. Toolbar Sidebar and Inspector actions show or hide supporting panes. The saving sheet is 400pt wide and empty-state explanation text has a 380pt maximum width. The compact capture used a temporary fixed 780 × 520pt content frame, producing a 780 × 572pt window including its toolbar; normal minimum/default sizing was restored afterward. Compact control layout was reviewed. Manual divider/window resizing remains a verification follow-up. Grid sizing remains future work.

**The Stable Place Rule.** Keep primary controls in consistent locations and preserve meaningful selection through organization changes where possible.

## Elevation & Depth

Flat content surfaces, tonal separation, and native pane separators establish hierarchy. Use native elevation for transient menus, popovers, and previews when appropriate. Photographs do not sit in individually shadowed cards. Avoid decorative depth, glass overlays on imagery, and extra panel layers that compete with content.

## Shapes

Native control geometry owns buttons, fields, menus, and focus treatment. Photo cells use consistent geometry and preserve aspect ratio by default; composition can be inspected in the larger preview. If cropped thumbnails become an option, make the viewing choice explicit.

Use restrained image clipping and a clear selection outline or native tint that does not obscure image content. M1 delegates geometry to native button styles, pickers, sidebar rows, the `.roundedBorder` name field, popover, and sheet. No custom radius tokens are defined. Photo clipping and selection outlines remain future work and need native rendering verification. Avoid turning every metadata fact into a rounded badge.

## Components

### Native workspace and navigation

Native `HSplitView` with a `.sidebar` `List(selection:)` presents All photos, Sources, Saved Views, and an explicit Collections placeholder. Source rows show readable availability and offer Restore Access and Check Availability context actions. Native List selection owns the appearance and handles mouse and arrow-key navigation; custom row backgrounds are absent. A local-catalog footer reinforces storage on this Mac. Native focus and hover rendering remain owned by macOS. Arrow selection is verified; full Tab traversal remains a follow-up check.

### View recipe

A plain search field has the accessibility label Photo search and is disabled until indexing exists. Scope and Filters sit beside labeled native Group by and Sort pickers; Filters opens an explanatory popover. Edited text identifies unsaved changes, and Update View appears only for an edited saved view. Save View is unavailable without sources or a ready catalog. This is an implemented settings shell, not a working search/filter experience.

### Empty and failure states

An SF Symbol, semibold native title, centered explanation, and direct actions present no sources, folder added, or catalog failure. The first Add Folder action is `.borderedProminent` and supports Command-O. Folder added explicitly states that photos have not been indexed. The catalog failure includes the selectable catalog path and reassures users that originals have not changed.

### Source inspector

A native ScrollView places source identity, availability, not-indexed status, selectable path, and Reveal in Finder before the recipe summary. Restore Access appears when access is needed. `LabeledContent` aligns metadata; native dividers separate source information from recipe information. Photo metadata, preview, and confirmed/suggested tags remain pending.

### Saving sheet and native controls

The sheet uses a rounded-border name field, a readable sources/group/sort summary, Cancel, and Save View. Cancel and default-action keyboard shortcuts are defined; blank names disable saving. Toolbar Add Folder is disabled when the catalog is unavailable, and the Inspector action toggles the supporting pane. Menus, sheets, popovers, buttons, picker appearance, focus rings, and native radii are delegated to SwiftUI/AppKit. No production HTML components or CSS equivalents are implied by this native implementation. Sidebar and Inspector toolbar actions explicitly toggle pane visibility.

## Do's and Don'ts

### Do:

- **Do** give photographs the greatest visual area and keep their surroundings neutral.
- **Do** use native macOS controls, focus behavior, SF typography, and system appearance.
- **Do** make current constraints and important states understandable through readable text.
- **Do** distinguish selection, keyboard focus, availability, and tag provenance.
- **Do** preserve user context through regrouping, source changes, and indexing updates where possible.

### Don't:

- **Don't** substitute custom gestures or icon-only core actions for familiar labeled controls.
- **Don't** add decorative gradients, glow, color washes, or glass over the image grid.
- **Don't** surround every photograph or metadata field with its own card.
- **Don't** hide uncertainty, offline availability, or incomplete search coverage to make the screen quieter.
- **Don't** invent hex values, native radii, or fixed SF type metrics, or claim visual verification from incomplete native captures.
