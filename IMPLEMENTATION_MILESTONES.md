# Photo Views — Implementation Milestones

Status: proposed implementation backlog, 2026-10-02. M0 implementation/evidence is tracked in [M0_STATUS.md](M0_STATUS.md); remaining milestones are not implemented.

Authority: [prd.md](prd.md) for requirements, [PRODUCT.md](PRODUCT.md) for durable context, [DESIGN.md](DESIGN.md) for the selected Photo Workbench direction, and [.impeccable/surfaces/main-workspace.md](.impeccable/surfaces/main-workspace.md) for workspace behavior.

Milestones describe working increments, not calendar commitments. Hackathon duration, team, hardware, and fixtures remain unknown; the PRD's two-to-three-day assumption is not an estimate for this whole backlog. Checks run locally; no custom GitHub Actions or paid automation is introduced.

## M0 — Resolve feasibility and demo scope

**Outcome:** evidence that the agreed RAW archive can be decoded and searched locally, with a reproducible implementation path.

- Confirm camera models/RAW variants, representative files, demo hardware, minimum macOS, event/team constraints, and distribution goal.
- Create an external, untracked fixture set containing supported image formats, orientations, missing metadata, RAW+JPEG candidates, and unsupported/corrupt examples. Record baseline original hashes.
- Spike original-file metadata, embedded previews, color/orientation handling, and decoder fallback only where required by the fixtures.
- Review the exact embedding checkpoint's licensing and intended use; compare the feasible local inference options described by the PRD.
- Demonstrate text-to-image and image-to-image retrieval against a small human-labeled sample. Prepare an event/session-separated tuning and held-out benchmark.
- Record backend, tokenizer, preview pipeline, versioning, cache approach, and reproducible model download/setup. Measure enough throughput/latency to identify blocking risks.

**Done when:** required camera fixtures have usable previews and metadata, or an explicit unresolved compatibility decision; the chosen local model produces meaningful retrieval; original hashes match; setup is reproducible on the named Mac. Unsupported formats must not be advertised as supported. Unresolved required-camera support blocks the claim that RAW scope is complete.

**Depends on:** actual fixtures and hardware decisions. App shell work can begin while fixtures arrive; decoder and model decisions cannot be validated without them.

## M1 — Native workspace and catalog foundation

**Outcome:** a running native Mac app with the Photo Workbench structure and persistent source/catalog identity.

- Create the SwiftUI app with AppKit integration only where needed, following the selected macOS target.
- Implement the source/saved-view/collection sidebar, central workspace, collapsible inspector, search/filter region, labeled Group by/Sort, and empty-state Add Folder action.
- Define source, asset, optional photo association, metadata, embedding, tag assignment, collection, saved view, and indexing-job records with schema migration/version handling.
- Define a typed view recipe and stable identifiers for selection, results, and asset members.
- Select folders with the native picker; persist access where applicable, track volume/source identity and relative paths, and store catalog/cache locally.
- Resolve initial native semantic colors, text styles, spacing, and window/pane behavior. Validate the initial workspace in both appearances and with keyboard focus.

**Done when:** folders can be added and restored after relaunch; source identities and records persist; panes and core controls work; the empty workspace follows DESIGN.md. Illustrative fixtures are clearly distinguished from real indexed results.

**Depends on:** M0's platform decision. This is the first native visual checkpoint; exact tokens become grounded in code rather than guesses.

## M2 — Resumable indexing and real-photo browsing

**Outcome:** users browse their actual photos while indexing continues.

- Enumerate selected folders recursively; metadata and preview stages precede embeddings.
- Implement the validated RAW/standard-image preview pipeline and metadata extraction from originals; retain pipeline/version provenance.
- Persist per-stage jobs, bounded concurrency, pause/resume, restart recovery, incremental file-change detection, and individual failure reporting. Checkpoint completed expensive stages so interrupted scans reuse them; detect moved files without treating a disconnected drive as deletion.
- Generate local thumbnails and analysis derivatives; apply cache limits without tying originals to cache lifetimes.
- Connect a lazy photo grid and inspector to catalog results; support keyboard selection, Space preview, and Reveal in Finder.
- Establish disconnected-source semantics now: an unavailable volume is not deletion. Full reconnect reconciliation follows in M7.

**Done when:** an actual mixed-format folder produces correctly oriented browseable previews; metadata is inspectable; corrupt files do not stop the job; pause/relaunch/resume works; changed files reindex appropriately; originals remain unchanged. Include quit/relaunch during scanning, moved files, unchanged-file reuse, and disconnected-drive fixtures in local checks.

**Depends on:** M0 decoder decision and M1 catalog/source foundation.

## M3 — Local retrieval and exact constraints

**Outcome:** the first end-to-end retrieval slice: folder → catalog → thumbnails → visual search.

- Index versioned image embeddings from validated derivatives, using the M0 backend and a versioned structured worker protocol if Python is chosen.
- Embed text queries locally and return ranked results. Begin with exact vector comparison as the PRD proposes.
- Add filename/imported-keyword text retrieval; make the retrieval layer ready for confirmed/suggested tags added in M5.
- Implement camera/date/folder hard filters first, applied before final top-k selection.
- Evaluate a fusion method for text and visual retrieval instead of adding incompatible raw scores.
- Expose indexing coverage near results, preserve exact constraints on empty results, and ignore stale asynchronous results when the recipe changes.
- Add Find Similar with a visible reference photo and a clear exit action, retaining applicable constraints.

**Done when:** supported RAW and standard images participate in text-to-image and image-to-image searches; camera/date/folder constraints are never violated; partial coverage and no-match states are explicit; cached retrieval works with the source disconnected.

**Depends on:** M2 derivatives/catalog and M0 model decision. Measure baseline relevance and latency here, not only at release.

## M4 — Dynamic grouping and saved live views

**Outcome:** the signature Photo Workbench interaction works on real results.

- Implement one-level grouping by folder, month, and camera, with Unknown buckets and deterministic sorting; primary-subject grouping follows tags in M5.
- Keep membership and ranking separate from grouping; switching groups does not trigger image inference.
- Connect the editable view recipe: sources, search, filters, grouping, sorting. Preserve selected-photo identity and scroll context where possible.
- Persist named saved views with model/ranking settings; make changed definitions visibly unsaved and update only through an explicit action.
- Refresh membership when matching assets become indexed. Make model-version changes and explicit refresh behavior understandable.

**Done when:** a filtered result set can switch month → camera with the same unique membership; selection remains stable when present; saved views survive relaunch and include newly indexed matching photos without recreation.

**Depends on:** M3 result/constraint model. This is the core product demo checkpoint, not the complete MVP.

## M5 — Tags, subject groups, and minimal organization

**Outcome:** users correct machine suggestions and organize results without touching originals.

- Define the curated tag vocabulary, tune per-tag thresholds on tuning data, and store provenance/model versions.
- Implement distinct Suggested and Confirmed inspector sections with accept/reject/edit actions; preserve corrections and rejections through reindexing.
- Add tag retrieval and confirmed-tag constraints; define primary subject from a best supported tag or Unknown.
- Add primary-subject grouping and correct unique/membership counts for any exposed multi-label grouping.
- Implement favorites and manual collections with explicit membership, visibly distinct from saved live views.

**Done when:** suggestions are clearly unconfirmed; corrections survive restart/reindex; subject groups do not invent labels; favorites/collections persist; suggested-tag precision and coverage are reported against the agreed vocabulary.

**Depends on:** M3 embeddings/text retrieval and M4 grouping/view infrastructure.

## M6 — Complete filters and editable query interpretation

**Outcome:** all required metadata constraints are available and mixed queries become understandable plans.

- Add lens, ISO, aperture, shutter speed, dimensions, and format constraints with appropriate missing-value handling.
- Define a validated search-plan schema containing visual intent, exact filters, supported grouping, ambiguity, and unsupported phrases.
- Implement a baseline interpreter for the explicitly supported query forms, catalog vocabulary, and reference date/timezone; document its coverage. Do not silently claim arbitrary-language interpretation.
- Show interpreted constraints as editable controls before/alongside execution. Ambiguities request correction or clarification; unsupported phrases remain visible.
- Build parameterized queries from validated fields; do not accept model-supplied SQL or file operations.

**Done when:** required filters work on available metadata; hard constraints remain exact; supported mixed-query examples produce editable plans; ambiguous/unsupported input is handled honestly; plan agreement is measured against human labels.

**Depends on:** M3 filter model and M4 recipe UI; M5 supplies confirmed-tag semantics. DSPy optimization is optional later, but the baseline editable-plan behavior is required.

## M7 — Offline recovery and RAW+JPEG integrity

**Outcome:** the complete workflow withstands disconnects, source changes, and paired assets.

- Reconcile disconnect/reconnect and mount-path changes using source identity; rescan on reconnect and conservatively distinguish changes/moves from deletion.
- Provide reauthorization for lost access; keep cached metadata/thumbnails/embeddings usable while originals are absent.
- Complete availability indicators and reconnection feedback for previews/original-file actions.
- Add conservative reversible RAW+JPEG associations; ambiguous pairs stay separate. Expose each member's original, metadata, and availability.
- Define photo-level retrieval/selection behavior for collapsed pairs without confusing logical photos with individual assets; retain each asset's indexing/failure state.
- Exercise restart during indexing, corrupt files, changed assets, cache pressure, tag corrections, and saved-view membership updates together.

**Done when:** the HDD can be disconnected, the app relaunched, cached results searched, and the source reconnected without losing catalog records; RAW+JPEG access is correct and unpairing is reversible; original hashes still match.

**Depends on:** M2's foundational offline semantics plus M3–M6 for full integration. Reliability is implemented throughout; this milestone closes the cross-feature cases.

## M8 — Verification and demo handoff

**Outcome:** a measured, reproducible MVP demo with explicit limitations.

- Run the fixed held-out benchmark for retrieval, constraints, interpretation, and tags; report misses as well as successes.
- Check the PRD's proposed targets: relevant top-10 result for at least 80% of answerable queries, at least 90% agreement on supported filter/group fields, at least 90% suggested-tag precision with coverage reported, and P95 search under one second on named hardware. Record actuals; targets are not promises.
- Measure cold/warm latency, indexing throughput, memory, model/cache footprint, UI responsiveness, and fixture compatibility.
- Complete a bounded visual review of both appearances and relevant window sizes, keyboard/accessible labels, increased contrast, and reduced motion. Fix the observed defects and confirm once.
- Run the full demo: RAW-inclusive search → camera/date constraints → month/camera regrouping → similar photos → save view → new matching photo → disconnected HDD browsing.
- Update DESIGN.md from implemented tokens/components and the corresponding Impeccable sidecar rather than preserving the pre-implementation seed as an extracted spec.
- Document setup, model downloads, supported camera matrix, measured results, known limits, and reproducible local checks. If delivering a developer build, say so; signing/notarization is only included if the distribution goal requires it.

**Done when:** all required capabilities and integrity/resilience gates have evidence, results are documented, and another teammate can reproduce the demo. Any missed target or blocked fixture is an explicit scope/release decision, never silently counted as passed.

**Depends on:** M0–M7. Do not wait until this milestone to begin benchmarking or integrity checks.

## Optional experiments after the baseline

- **DSPy:** optimize supported query interpretation against the same held-out evaluation; retain it only for a measured improvement without losing the baseline schema/validation behavior.
- **Jev:** compare bounded choices or evidence reranking only with approved data payloads and explicit cost limits. Hosted use remains off by default.
- **Face presence/count:** add only if the core MVP is complete and time remains. Named-person identity stays follow-up.
- **Production follow-up:** revisit Core ML conversion if needed, distribution packaging, nested groups, and similarity clustering as separate decisions.

These experiments do not replace missing required RAW/search/grouping/organization/offline capabilities.

## Dependencies and useful parallel work

Critical sequence: **M0 → M1 → M2 → M3 → M4 → M5/M6 → M7 → M8**.

M1's shell can progress alongside the M0 decoder/model spikes after the macOS target is set. M5 tagging and M6 metadata/interpreter work can progress independently against agreed schema boundaries, then integrate confirmed-tag semantics. Fixture labeling, benchmark tooling, and integrity checks run throughout. Isolate schema migrations and shared recipe changes to avoid conflicting mutations. This is a coordination plan, not a request to spawn agents.

## Scope checkpoints

| Checkpoint | Demonstrable outcome | Remaining required scope |
| --- | --- | --- |
| After M2 | Real RAW-inclusive native browsing | Retrieval, views, tags/organization, full filters, recovery integration |
| After M3 | Baseline local search and similarity | Grouping/views, tags/organization, full filters/query plans, recovery integration |
| After M4 | Signature search/filter/regroup/save demo | Tags/organization, remaining metadata/query plans, pairing/recovery, final evidence |
| After M7 | Feature-complete MVP candidate | Verification, documented results, packaging/demo handoff |
| After M8 | Verified demo with measured limitations | Only explicitly optional/follow-up work |

If the event cannot accommodate the required backlog, re-scope explicitly after M0. Reduce optional experiments, distribution polish, or fixture breadth by agreement; do not silently remove RAW support or label a partial product as the full PRD MVP.
