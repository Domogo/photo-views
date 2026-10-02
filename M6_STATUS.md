# M6 — Complete metadata filters and editable query interpretation

Implemented on the development Mac, 2026-10-02, with bounded local evidence. M7–M8 remain separate milestones. The six user-approved plan examples pass; broader held-out agreement remains M8.

## Delivered

- Exact lens/format choices from catalog metadata and inclusive minimum/maximum ISO, aperture (f-number), shutter seconds, original width and original height. Blank means unconstrained; missing or nonnumeric values do not satisfy active numeric limits. Positive finite limits are validated; reversed ranges produce an explicit correction error. All constraints intersect before ranking/top-k and never broaden silently. Existing camera/folder/camera-calendar-date/confirmed-tag semantics remain.
- Additional metadata fields live behind More metadata inside the scrollable Filters area. Native localized number fields commit on Return or focus change. Applied constraints stay visible after closing the panel; saved and workspace recipes persist the new optional fields compatibly with older recipes.
- Typed, Codable `QueryPlan` version explicit-v1: original input, editable visual intent, exact filters, optional grouping, ambiguity/unsupported notices, reference day and timezone. Interpretation runs locally without an LLM, SQL generation, external calls or inference. It starts from current filters and overlays recognized directives; unchanged existing constraints remain visible in the review.
- Interpret opens a review before Apply Plan changes exact constraints. Visual intent is editable there; applying reveals the normal editable Filters controls. Editing the original query or switching mode invalidates the preview. Unknown/ambiguous values, conflicting dates/ranges and unsupported directives block application. Unrecognized plain prose stays visual, with no promise of exact interpretation. Ordinary typing still retrieves by visual similarity until a plan is explicitly applied.
- Review actions remain fixed outside the scrollable content; longer warnings cannot hide Apply Plan. Filter-panel height adapts to available window height, with native scrolling and an explicit Done action.

## Supported grammar

| Clause | Behavior |
| --- | --- |
| `camera:"NIKON Z f"`, `lens:"NIKKOR Z 28mm f/2.8"`, `format:NEF` | Case-insensitive catalog resolution; unique substring accepted, multiple candidates request a full quoted name, unknown values request a catalog choice. |
| `shot with "Sony A7"` | Supported camera phrase with catalog validation. |
| `folder:Japan`, `in folder "Japan trip"` | Exact folder-contains constraint, not geolocation. |
| `tag:animals` | Confirmed tag required; repeated different tags intersect. |
| `on:2025-11-06`, `from:2025-11-01 through:2025-11-30` | Valid camera-calendar day or inclusive range. |
| `today`, `yesterday` | Resolve using explicit reference instant and this Mac’s timezone; camera wall-clock dates are filtered as calendar days. |
| `iso>=400`, `aperture<=2.8`, `shutter<=1/500`, `width>=4000`, `height=4000` | Positive numeric inclusive bounds; shutter fraction converts to seconds. `=` sets both bounds. |
| `group by month`, `grouped by camera`, `group:subject` | One supported grouping: none/folder/month/camera/subject. |

Quote multiword catalog values. The grammar uses English directives and dot-decimal query numbers; manual numeric fields follow macOS locale and use decimal seconds (for example 0.002 for 1/500). Strict `>`/`<`, unknown `key:value` clauses, malformed numeric directives, arbitrary grouping names and relative week/month/year phrases remain visible as unsupported. It does not implement arbitrary natural-language intent, location/GPS, nested groups, semantic confidence or a full date-language parser. Remaining prose, including unsupported free-form wording without a directive, remains visual text.

## Local verification

- CatalogChecks passes with the six user-approved examples and 24 agent-authored interpretation cases covering mixed supported constraints/grouping, catalog resolution, ambiguity/unsupported refusal, invalid dates and leap days, conflicting ranges/dates, fractions, timezone boundary and typed-plan round-trip. New range fields survive catalog/workspace/saved-recipe round-trip. The 24 agent-authored cases are rule-specification checks. The six user-approved examples separately measure agreement on the small acceptance set described below; neither establishes general held-out agreement.
- Sixteen worker tests pass. Full numeric-bound intersections, inclusive boundaries, missing/nonnumeric metadata, invalid/nonfinite/bool/string limits, reversed numeric ranges, calendar-invalid capture metadata, lens/format facets and injection-like values are checked alongside existing retrieval, tagging, live-view and selection invariants.
- IndexChecks passes existing native original-integrity/indexing/recovery/cache/migration checks.
- Real native QA copy: mixed cars-at-night query interprets to Nikon Z f + Japan + ISO ≤ 400 + f-number ≤ 2.8 + width ≥ 4000 + monthly groups; Apply Plan changes the query to visual intent and narrows coverage to 728 assets. Editing ISO to 200 narrows it to 407. Adding shutter ≤ 0.002 seconds narrows it to 154. Actual local model retrieval returns 100 unique ranked assets from those 154; every returned asset satisfies every exact constraint. External report: `~/Library/Caches/PhotoViews/m6-ui-001/constraints-summary.json`.
- Unknown camera Canon and location:Paris visibly block Apply Plan. Corrections are made through the original query or direct filters; no unknown camera becomes an invented exact value.
- Final normal release build passes and was relaunched on this Mac. The existing selected raw source, two saved views, 5,085 indexed photos and connected originals remain available. Compact dark QA overrides are absent from the handoff build. Photos, catalogs, model weights, QA captures and reports stay outside Git. Originals remain read-only; GitHub stores code only, without Actions, CI/CD, hosting, paid services or spending changes.

## Acceptance and limits

The user confirmed all six proposed interpretations on 2026-10-02. The dedicated local acceptance check matches all six expected fields/grouping/refusal behaviors: 6/6, or 100%, on this small human-approved set. These examples cover a mixed camera/folder/month plan, ISO/shutter limits, exact date/confirmed tag, yesterday in the supplied timezone, ambiguous Nikon selection and unsupported location refusal. They were proposed around the implemented grammar and are not a representative untouched holdout. This narrow result does not establish the PRD’s ≥90% agreement target broadly. M8 still requires a fixed representative human-labeled holdout and miss reporting. Retrieval relevance, full-archive coverage, broad RAW compatibility, physical-drive disconnect, performance targets and distributable runtime remain outside this milestone’s evidence.

The manual collection/source scope is preserved when a plan applies. Organization and retrieval remain asset-level; RAW/JPEG association is M7. No schema-number change was needed: new recipe fields are optional and old JSON recipes decode. The query plan preview itself is ephemeral; its applied intent, filters and grouping persist in the recipe.

## Scoped native design review

Reviewer disposition: **ship** for the M6 extension after its sole compact Filters allocation finding was resolved. This is the original scoped single-fix review, not a whole-app audit. The root `WindowGroup` now measures actual content height with `GeometryReader` and passes it to `WorkspaceView`; the native Filters `ScrollView` receives a bounded allocation (`max(100, min(260, availableHeight - 440))`). In the corrected compact state, Hide Filters and Done are visible while coverage, result count, group heading and a useful photo row remain on screen. Scrolling exposes the remaining filter controls.

All five valid native captures were reopened for the documentation handoff: `.impeccable/review/m6-wide-plan.png`, `m6-wide-metadata.png`, `m6-unsupported.png`, `m6-compact-dark.png`, and `m6-compact-filters.png`. Wide evidence uses 1180 × 760pt; compact dark evidence uses 780 × 520pt content with all three panes. The captures show editable visual intent and exact-plan summary, metadata ranges with applied constraints, explicit unknown-camera/unsupported-location notices with Apply Plan disabled, and readable compact dark controls. They document the native `.build/app/Photo Views.app` rather than an HTML proxy.

Compared with the incumbent Photo Workbench, the extension retains the image-only gallery, neutral appearance-aware native system roles, native controls and supporting inspector. Photographs continue to carry the color and visual interest; query review and metadata controls extend the existing recipe area. No new raster assets or global design tokens ship.

The reported local checks remain bounded evidence: 6/6 user-approved semantic examples on a small acceptance set, 24 agent-authored interpretation cases, sixteen worker checks, IndexChecks, and a successful normal release build. The six approvals do not establish the general ≥90% agreement target. Full native accessibility, increased contrast and reduced motion remain unverified. No HTML detector or native Mac reference was supplied. Historical M1 `DESIGN.md` and `.impeccable/design.json` drift is preserved until M8; their source-shell descriptions are not silently promoted to current M6 documentation.
