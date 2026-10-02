---
name: Photo Views
description: A minimal native photo workbench with clear, editable views.
---

<!-- SEED: established with the user before implementation; re-run $impeccable document once there's code to capture the actual tokens and components. -->

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

The main workspace composition and signature view recipe are defined in `.impeccable/surfaces/main-workspace.md`. This is approved direction, not evidence of an implemented or tested interface.

## Colors

Restrained neutral palette with one selection/action accent. Follow system appearance: a user searches at a desk under variable ambient light, so neither light nor dark is a mandatory brand treatment.

### Primary

Use the user's macOS accent for active selection and appropriate native primary actions. Focus must remain visible with all supported accent choices; validate rather than assume contrast.

### Neutral

Use appearance-aware neutral canvas and panel surfaces, primary text, secondary text, and separators. The chosen direction establishes light gray/white and graphite families, not implementation hex tokens. Resolve actual semantic colors during implementation and check them in both appearances and increased contrast.

Status colors use native semantic roles where available and always include a text or icon cue. Suggested tags must not look like errors merely because they are unconfirmed.

**The Photograph Rule.** Keep decorative color out of the image canvas; actual photographs carry the palette.

**The State Rule.** Color supplements a meaningful state and never serves as its sole explanation.

## Typography

Use macOS system SF typography and standard native text styles. No decorative display face. Use tabular figures for counts and aligned numerical metadata; use ordinary text for names, queries, and tags.

Section titles and group headers have greater emphasis than metadata. Body and control labels remain readable; tertiary details do not become tiny labels. Use sentence case and normal tracking. Exact sizes, weights, and line heights are to be resolved in the native implementation, including the supported accessibility settings.

**The Label Rule.** Core actions have readable labels; icons support rather than replace meaning.

## Layout

A compact control rhythm and more generous content spacing distinguish operations from photographs. Align related controls and metadata rather than enclosing every item in a card. A 4-point spacing rhythm is a starting proposal, not an extracted token scale.

Layouts respond to available Mac window space. Optional supporting panes can collapse; essential actions remain reachable. Preserve useful photo size and readable labels instead of squeezing all three panes indefinitely. Initial pane dimensions, minimum window size, and grid sizing remain implementation decisions.

**The Stable Place Rule.** Keep primary controls in consistent locations and preserve meaningful selection through organization changes where possible.

## Elevation & Depth

Flat content surfaces, tonal separation, and native pane separators establish hierarchy. Use native elevation for transient menus, popovers, and previews when appropriate. Photographs do not sit in individually shadowed cards. Avoid decorative depth, glass overlays on imagery, and extra panel layers that compete with content.

## Shapes

Native control geometry owns buttons, fields, menus, and focus treatment. Photo cells use consistent geometry and preserve aspect ratio by default; composition can be inspected in the larger preview. If cropped thumbnails become an option, make the viewing choice explicit.

Use restrained image clipping and a clear selection outline or native tint that does not obscure image content. Exact corner radii and outline treatment await native rendering. Avoid turning every metadata fact into a rounded badge.

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
- **Don't** invent exact tokens or claim visual verification before a native implementation exists.
