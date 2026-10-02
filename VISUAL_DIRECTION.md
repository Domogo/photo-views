# Photo Views — Visual Direction Proposal

Status: Photo Workbench selected by the user on 2026-10-02. DESIGN.md and .impeccable/surfaces/main-workspace.md are the current direction authority. Alternatives below are exploration history; no UI implementation exists. Based on prd.md, PRODUCT.md, UX_PLAN.md, and the user's direction: **minimal, bespoke, intuitive**.

## Shared commitments

Native macOS, photo-led three-pane workspace, restrained neutrals, system typography, familiar controls, and visible search state. Minimal means fewer competing signals, not hidden controls or tiny text. Bespoke means product-specific organization and interactions, not custom replacements for familiar macOS controls.

Use system appearance as the default. The physical scene is a Mac user retrieving photos at a desk under variable ambient light; both light and dark appearances must be usable without making either an identity prerequisite. Keep viewing surfaces neutral so surrounding UI does not visibly tint photographs.

No aesthetic reference overrides local search, offline behavior, explicit constraints, RAW access, or original integrity.

## Direction A: Archive Index

A structured photographic archive: clear section headings, aligned counts, restrained dividers, and repeatable photo cells. Sources and saved views live in the left pane; the center organizes photos into visibly named buckets; metadata forms a concise record in the right pane.

**First viewport:** native titlebar; wide search field; an editable constraint row; a compact results row with unique count, Group by, and Sort; thumbnail sections headed by month or camera. The optional inspector aligns metadata labels and values.

**Signature interaction:** switching Group by changes the section structure while keeping the query, count, selected photo, and inspector stable. Maintain a selected-photo anchor where possible; explain when filters remove selection.

**Visual language:** neutral white/light gray or charcoal surfaces; graphite primary text; secondary gray labels; a single semantic selection accent using the macOS accent. SF system type, tabular figures for counts and metadata, little ornament, native control shapes. Grid rhythm and strong alignment supply the identity.

**Reach:** this grammar extends to indexing reports, source management, saved-view editing, and dense metadata without inventing another visual language.

**Risk:** overly rigid alignment can make a personal archive feel administrative. Keep photo area generous and collapse secondary record detail.

Disciplines retained from the evaluated reference systems:

- Character catalog: every cell remains identifiable and selectable despite mixed subjects and aspect ratios; no mascot styling or popularity fiction.
- Boarding pass/gate board: preserve identity as groups and membership change; surface changed or unavailable state persistently, without flashing alerts.
- Labanotation: give each visual channel one meaning; selection, availability, and tag provenance must remain distinguishable.
- Centre-rail reference setting: keep primary photographs and secondary annotations hierarchically separate; metadata never intrudes into imagery.
- Data-sublime field: accommodate large archives through consistent density and legible counts, with no decorative data, inversion, or strobing.

## Direction B: Photo Workbench — recommended

A quiet photo workspace with generous image area and a compact, editable view recipe. The three panes remain familiar; the distinctive craft lives in the search-to-view workflow and how gracefully the interface changes organization.

**First viewport:** sidebar with Sources, Saved Views, and Collections; broad central search; clearly labeled exact constraints directly beneath it; image grid with compact group headers; optional inspector. Indexing coverage sits near the results it qualifies, and source availability sits next to the affected source.

**Signature interaction:** the view recipe reads in task order—search, filters, grouping, sorting—and each part is directly editable. Saving captures that complete recipe. Show a plain edited-state indicator when a saved view changes. Do not turn the recipe into a single opaque text string or an unfamiliar query language.

**Visual language:** the same restrained, appearance-aware neutral family, with softer spacing and less table-like segmentation than Archive Index. SF system type and SF Symbols keep native affordances familiar. A clear selection outline/tint and keyboard focus treatment identify the active photo without covering it.

**Reach:** source setup, empty states, similarity search, saved views, and inspectors reuse the same content-first hierarchy and control placement.

**Risk:** the pane structure is familiar to photo apps and can feel generic. Distinction must come from the view recipe, stable regrouping, precise status placement, and exceptionally consistent spacing rather than decorative styling.

## Direction C: Graphite Console — alternate

A darker, denser photo work surface with persistent panes, hairline separators, compact metadata, and status accents reserved for meaningful state. Native labeled controls replace command syntax.

**First viewport:** charcoal grid workspace, permanent sidebar, concise search/filter band, and dense inspector. Selection uses a single accent; failures and offline originals remain explicit.

**Reach:** strong for extensive metadata and indexing diagnostics.

**Risk:** dark-first density identifies more strongly with developer tools than personal photo retrieval and weakens the system-appearance premise. It is an alternate, not the current recommendation.

## Provisional design rules for the selected direction

These are proposed implementation rules; exact tokens follow approval and native rendering.

| Element | Intended treatment |
| --- | --- |
| Canvas | Neutral, appearance-aware background; images provide the dominant color. |
| Typography | System SF typography, normal sentence case, clear title/body/caption hierarchy; no decorative display face. |
| Spacing | Consistent compact rhythm for controls, more space around groups and image content. Start with a 4-point rhythm and verify in native layouts. |
| Thumbnail grid | Stable cell geometry, aspect-preserving thumbnails, and a larger preview for composition. If fill-cropping is offered, make it an explicit viewing choice. |
| Grid labels | Avoid filename/metadata clutter on every thumbnail; selection and inspector expose detail. Required availability and pairing indicators remain discoverable. |
| Group headers | Name plus count; separate unique result count from membership totals. Unknown is explicit. |
| Search | Visible input, native focus behavior, editable interpreted constraints; unsupported phrases remain visible. |
| Group and Sort | Labeled controls in a stable location, not buried in an icon-only overflow menu. |
| Inspector | Concise preview and actions first; aligned metadata and tag provenance below. |
| Tags | Separate Confirmed and Suggested sections; acceptance/rejection/editing are direct actions. |
| RAW+JPEG | One collapsed photo with access to original members; no duplicate claim. |
| Offline/indexing | Text plus icon/status; color is supplementary. Keep failures available without a blocking global overlay. |
| Motion | Brief functional transitions that preserve context; no flourish or whole-grid animation for large sets. Reduced motion uses immediate transitions. |
| Empty states | One useful explanation and next action, with no decorative illustration required. |

Avoid cards around every photograph, gradients, glass effects over the grid, branded color washes, oversized search marketing copy, permanently exposed advanced controls, icon-only core actions, and uncertainty disguised as confidence.

## Native behavior and acceptance

Use native split panes, picker, menus, focus, keyboard navigation, and Space preview. Do not import browser breakpoints or iOS interaction conventions. Exact availability of controls and visual materials is checked against the chosen macOS target before implementation.

A direction succeeds when users can identify the current sources, query, constraints, grouping, selection, and indexing limitations at a glance; change organization without losing their place; and reach original files or correct tags without hunting through menus.

## Direction exploration record

The grounded systems considered were: (1) photographer's editing workbench, (2) contact-sheet selection, (3) reference-library catalog, (4) camera information display, (5) archive finding aid, (6) slide sorting table, and (7) map layer/filter legend. These span photographic workflows, archival information systems, and instrument/display systems. The concept seed selected the archive finding aid for presentation; the photo workbench is the independent recommendation.

The evaluated challengers were character catalog (declined), graphite developer console (competitive on product clarity), gate board (declined), Labanotation (declined), centre-rail reference setting (declined), and data-sublime field (declined). None beat Archive Index on both audience identification and product clarity. Their retained disciplines are listed above. All remain adoptable on request, subject to the native macOS and minimal/intuitive commitments.

The quiet conventional alternative is a standard native photo browser with customary sidebar, grid, and inspector, executed with consistent craft. A fresh direction round can also be requested, with safer or bolder steering.

## Next decision

Photo Workbench is selected. Use DESIGN.md and .impeccable/surfaces/main-workspace.md for subsequent work. These are written plans, not rendered mockups. Exact tokens remain to be validated in native implementation. The existing buildPath preference remains unset.
