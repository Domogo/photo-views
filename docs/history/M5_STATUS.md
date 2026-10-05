# M5 — Tags, subject groups, and minimal organization

Implemented on the development Mac, 2026-10-02. M6–M8 remain separate milestones; this is a bounded developer increment.

## Delivered

- User-approved vocabulary: people, animals, cars, buildings, food, mountains, water, vegetation. The pinned local image/text model scores three prompts per subject against cached image embeddings. Independent per-tag cosine cutoffs and a maximum of three suggestions replace probability claims. Uniform, missing or corrupt cached previews produce no suggestions; rebuilding a preview clears its tag checkpoint for retry.
- Suggested and Confirmed sidebar sections, explicit accept/reject/edit, custom manual tags and removal. Suggested rows record model/vocabulary versions, score and cutoff. Rejected rows remain durable tombstones. Changes/reindexing clear only unconfirmed suggestions and checkpoints, preserving accepted/rejected/manual decisions, favorites and collection membership.
- Filename/keyword search includes current unconfirmed suggestions; exact confirmed-tag constraints require every listed tag and exclude suggestions and rejected manual tags. Comma-separated input applies explicitly through Apply Tags or Return.
- One-level Primary subject groups use the strongest supported curated subject, prefer a confirmed subject over a suggestion, label suggested buckets, and otherwise show Unknown subject. Each loaded asset belongs to exactly one group. Custom tags remain searchable/filterable but do not expand the curated primary-subject vocabulary.
- Favorites and manual collections with explicit membership. Collections are separate sidebar destinations from Saved Views; naming explains manual membership. Recipes can combine collection/favorite scopes with search and exact filters; saved recipes remain live.
- Schema 3 migration adds score/cutoff/vocabulary and tag-run checkpoints while preserving prior catalog and saved-view records. The app bundles the vocabulary alongside its local worker; no runtime downloads, hosted inference, paid services, Actions, CI/CD or hosting were introduced.

## Local verification

- CatalogChecks passes: prior catalog/grouping/live-recipe checks plus normalized manual tags, editing/removal, durable rejection, favorites, idempotent collection membership and reopen persistence.
- Fifteen worker tests pass: exact constraints and retrieval, selected identity, model/ranking compatibility, confirmed-versus-suggested retrieval, rejected-manual exclusion, primary-subject precedence/current-version handling, favorite/collection intersections, tag checkpoints, uniform-preview suppression and preservation across vocabulary changes.
- IndexChecks passes: native orientation/metadata/original integrity, failure isolation, pause/reopen/resume, unchanged reuse, stable moves, changed-file reindex, worker termination/recovery, missing/disconnected semantics, cache quota and M1 → current migration. Changed-file checks preserve manual decisions, favorites and collection membership on the stable asset ID.
- Actual native QA clone migrated a schema-2 archive copy to schema 3, retained two saved views, and prepared all 5,085 existing embeddings without regenerating those embeddings. Real DSC_1513.JPG: accept cars → confirmed bucket; Favorite → one-member Favorites; create Japan picks → initially empty; add explicit membership → one-member collection; travel → edit japan creates accepted manual japan and rejected travel; exact cars + japan constraints keep that member. A separate app relaunch retains the collection/filter recipe, tags and favorite. QA report: `~/Library/Caches/PhotoViews/m5-ui-001/organization-summary.json`.
- The completed QA archive copy had 1,119 unconfirmed suggestion rows on 1,081 of 5,085 embedded assets after one accepted suggestion: roughly 21% asset coverage. This is coverage, not a precision estimate, and some missing/uniform cached previews intentionally produce none.
- Final normal release build passes and the normal app was relaunched with M5. Its schema-3 catalog retains both saved views and completed 5,085 tag checkpoints. All QA writes and calibration outputs are outside source folders; originals remain read-only. QA bookmark Access needed is an isolated-bundle limitation, not proof of physical-drive disconnect.

Reproduce local checks:

```sh
swift run CatalogChecks
swift run IndexChecks
"$PHOTO_VIEWS_PYTHON" scripts/search/checks.py
python3 scripts/build_app.py --release
```

## Calibration evidence and limits

The local tool `scripts/search/calibrate_tags.py` prepares review contact sheets and evaluates cutoffs. The agent inspected 64 score-enriched photographs with visible-subject labels; RAW/JPEG stems were deduplicated and each subject’s selected sample was limited per folder. Whole source-folder groups were split deterministically into 31 tuning and 33 held-out photographs. Cutoffs were selected only on tuning data. These folders are approximate event boundaries, not proven independent events. The sample is small and biased toward high model scores; human labels/acceptance and representative release evaluation remain open.

Runtime evaluation includes the preview-quality gate and maximum-three cap. On the 33 held-out photos, 27 of 30 suggested labels were correct (90% aggregate precision), and 25 of 33 photos received suggestions (75.8% photo coverage). The cap did not change this sample’s totals. Aggregate precision does not establish 90% per-subject precision or accuracy on the full archive.

| Subject | Correct / suggested | Precision | Recall | Photo coverage |
| --- | --- | --- | --- | --- |
| people | 2 / 3 | 66.7% | 66.7% | 9.1% |
| animals | 4 / 4 | 100% | 100% | 12.1% |
| cars | 5 / 6 | 83.3% | 100% | 18.2% |
| buildings | 4 / 4 | 100% | 33.3% | 12.1% |
| food | 0 / 0 | Not measurable | 0% (one positive) | 0% |
| mountains | 0 / 0 | Not measurable | Not measurable (no positives) | 0% |
| water | 3 / 4 | 75% | 100% | 12.1% |
| vegetation | 9 / 9 | 100% | 75% | 27.3% |

False suggestions and missed labels are retained in the external report, not silently discarded or used to retune held-out cutoffs. Artifacts: `~/Library/Caches/PhotoViews/m5-calibration-001/{sample.json,labels.json,label-provenance.json,calibration.json,contact-*.jpg}`. None are pushed to GitHub. Uniform black frames prompted the preview-quality rule; this exploratory evaluation is not an untouched preregistered release benchmark. M8 must use a new fixed human-labeled holdout.

Minimal collections support creation and membership toggling, not a full rename/delete manager. Organization is asset-level; RAW/JPEG association remains M7. Preview preparation is still partial (5,085 embedded of 19,877 discovered); universal RAW support, full-archive precision, performance targets, distributable runtime and full accessibility/appearance matrix remain unclaimed.

## Scoped native design review

This is an ordinary extension of the incumbent Photo Workbench, not a new visual system. Documentation compared `WorkspaceView.swift`, `WorkspaceModel.swift` and `ResultGrouping.swift` with PRODUCT.md, DESIGN.md and `.impeccable/surfaces/main-workspace.md`, and opened all four required native CUA captures:

- `.impeccable/review/m5-wide-suggested.png`: 1180 × 760pt light workspace, real selected car photograph, separate Confirmed/Suggested sections, direct Accept/Reject/Edit controls and a Cars (suggested) subject bucket.
- `.impeccable/review/m5-collection-confirmed.png`: same wide light workspace, manual Japan picks destination, Favorite state and confirmed cars + japan on the selected photograph.
- `.impeccable/review/m5-confirmed-filters.png`: same wide workspace with the filter area intentionally scrolled to the exact confirmed-tag constraint, its all-tags explanation and applied cars · japan summary.
- `.impeccable/review/m5-compact-dark.png`: 780 × 520pt content plus native toolbar in dark appearance; selection, active constraints and collection context remain visible. The inspector is intentionally scrolled to the tag sections, rather than claiming its preview is visible at that scroll position.

The extension retains SF system text styles, appearance-aware native canvas/inspector surfaces, primary/secondary text roles, native buttons, menus, fields, sheets and separators. The existing 8/20/24pt Workbench rhythm and adjustable three-pane hierarchy remain the basis; photographs supply color, the gallery stays image-only, and confirmation is communicated through headings, text and actions rather than color alone. Subject grouping distinguishes suggested buckets and supplies Unknown subject without moving originals. Collections remain explicit membership destinations, distinct from live Saved Views. No new global tokens or shipping raster assets were introduced.

The fresh review validated all four captures and identified one material issue: activating the New Collection accessibility row did not open its sheet. The sidebar selection route now opens it; external `~/Library/Caches/PhotoViews/m5-ui-001/new-collection-ax.txt` verifies the actual native sheet, focused Collection name field, Cancel and initially disabled Create Collection. Final reviewer disposition: **ship**, from a verdict pass scoring that single activation fix **resolved**. Geometry was unchanged, so the reviewer required no visual recapture. This verdict certifies the listed fix; it is not a new whole-surface approval or a complete accessibility audit.

Historical M1 DESIGN.md and `.impeccable/design.json` are preserved. Their M1-only implementation/evidence narrative still describes search, grids, photo inspection and tag workflows as pending; their recipe layout describes standalone Group by/Sort pickers and ViewThatFits adaptation, while the incumbent implementation uses the native View menu and scrollable inline filters. PRODUCT.md and the surface brief also retain historical pre-implementation passages. This is pre-existing documentation drift, recorded here without refreshing the canonical system or sidecar before M8.

No HTML/CSS detector ran: it has no native SwiftUI/AppKit verdict. The skill ships no applicable macOS platform reference; iOS guidance was not substituted. QA used an isolated copy of a real cached archive. Its Access needed bookmark state, including the inspector's unavailable-original wording, does not prove physical-drive unplug behavior. Light/dark captures and the specific AX activation evidence do not establish full keyboard traversal, all accent/contrast settings, increased contrast, reduced motion, a full resize matrix, release inference quality or M6–M8 completion. Local test/build outcomes and calibration limitations above remain the bounded evidence.
