# M3 — Local retrieval and exact constraints

Implemented and exercised on the development Apple Silicon Mac, macOS 26.6.2. This is the native developer-build retrieval slice; packaging and held-out relevance acceptance remain open.

## Delivered

- Persistent local Python worker with protocol-versioned JSON lines, response identity/shape checks, bounded responses and a 60-second request timeout. Work runs away from the UI. The native build bundles the script and uses the already validated external M0 Python environment and pinned OpenCLIP snapshot; no service, HTTP server or image/query upload is involved.
- Versioned normalized 512-dimensional Float32 image vectors from local ImageIO derivatives. Small 16-photo batches commit vectors and job outcomes individually, preserve completed work on pause/restart, isolate failures and reject inputs changed during inference. Cached analysis previews are preferred, with validated thumbnails as fallback. No originals are read by the inference worker.
- Exact cosine comparison over constrained candidates, text-to-image search and reference-image similarity. The reference asset itself is excluded. RAW/JPEG counterparts and near duplicates remain distinct until future pairing work.
- Filename/folder-path and existing imported/manual/accepted-keyword retrieval. Visual and lexical ranks use reciprocal-rank fusion with k=60; raw cosine and lexical scores are never added. Suggested unconfirmed tags are not presented as confirmed keywords.
- Source, camera, camera-wall-clock inclusive capture-day and folder-path constraints apply before top-k. The worker also honors existing lens/format/ISO/confirmed-tag recipe constraints. Unknown camera dates do not pass active date limits. No constraints are silently relaxed.
- Full-catalog candidate retrieval, independent of grid pagination. Visual searches expose up to 100 nearest candidates; filename/browse results load incrementally. Query generations discard stale asynchronous results.
- A simplified native header: functioning search with Visual/Filename mode, expandable inline Filters and a secondary View menu for grouping/sorting/saving. Visible applied constraints and reset actions; collapsed coverage with explicit preview/visual indexing controls and failure retry. Find Similar shows its reference and Exit Similar while retaining constraints.
- Basic folder/month/camera presentation remains separate from inference. Ranked groups appear in the order of their strongest member, preserving ranking within each group. Complete grouping continuity and saved-live-view acceptance belong to M4.

## Verification

`swift run CatalogChecks`, `swift run IndexChecks`, the release app build and `scripts/search/checks.py` with the M0 environment pass. Seven retrieval tests independently cover literal/keyword matching, injection-shaped strings, zero-match preservation, inclusive dates/unknown values, folder-only matching, filtering before top-k, reference exclusion, old model exclusion, RRF ordering, partial coverage/filename fallback, missing-cache failure isolation/retry and protocol rejection.

The real probe used the existing 60 M0 previews (20 Sony ARW, 20 Nikon NEF and 20 Nikon JPEG), never opening their originals. All vectors were finite, normalized and 512-dimensional; completed vectors were unchanged after reopening. Nine exploratory queries reused the M0 agent-authored labels: all had a labeled top-ten hit, with query P95 approximately 0.083 seconds and indexing including model load approximately 4.13 seconds. This small selected sample is execution evidence, not a human-held-out quality benchmark or whole-archive latency target.

An actual worker process was terminated after three durable vectors, then relaunched to finish all 60; the three checkpoint vectors remained byte-identical. Separate visual and filename protocol requests returned results under macOS `sandbox-exec` with `deny network*`. Original availability was false in the fixture catalog: cached retrieval did not depend on connected originals.

The live archive now has 5,085 visual embeddings for its 5,085 completed previews, among 19,877 discovered assets. Preview indexing is paused. Native checks exercised real “cars at night” results, exact camera filtering, an impossible folder yielding no matches, Clear Filters recovery, reference-photo similarity with a retained Japan folder constraint, and relaunch with completed embeddings reused. Light, compact dark, filters, strict-empty and similarity states were captured locally. Photo/model/catalog/report/capture data remain outside Git.

To repeat the real-fixture probe, use a fresh output directory:

```sh
"$PHOTO_VIEWS_PYTHON" scripts/search/probe.py --probe /absolute/m0/probe --queries /absolute/local/labels.json --model /absolute/local/model --output /absolute/fresh/output
```

## Remaining limits

- The model remains the M0 evaluation candidate. This build requires that documented local Python/model setup and is not a standalone shipping package. The minimum declared macOS 14 runtime is still untested.
- Baseline fusion and local latency are checked; human labels, event-separated held-out relevance, robust cold/warm full-archive measurements and production checkpoint suitability remain open. RRF is not claimed as a tuned optimal ranking method.
- Camera/RAW evidence remains limited to the actual fixtures. Visual retrieval returns nearest candidates even when none is semantically relevant; the UI labels similarity rather than certainty.
- Metadata availability precedes visual coverage. Photos without vectors remain eligible for filename browsing; progress remains partial until previews and embeddings finish.
- Date constraints use the camera's original calendar day, retaining the M2 unknown-timezone convention. Mixed natural-language constraint interpretation belongs to M6; users set exact constraints explicitly here.
- Physical SSD removal was not performed on the user's active drive. Offline inference and unavailable-original fixtures are verified; full physical reconnect reconciliation remains M7.
- Complete keyboard traversal, numerical contrast, increased contrast/accent variants and reduced-motion checks remain release verification work. Keyboard grid/Space behavior from M2 is retained.
- GitHub stores code only. No custom Actions, paid automation, builds or hosting were added.

## M3 UI verification

The final native review disposition is **ship for this M3 retrieval slice**. Local evidence in `.impeccable/review/m3-final-wide.png`, `m3-final-empty.png`, `m3-final-filters.png`, `m3-final-filters-bottom.png`, `m3-final-similar.png` and `m3-final-compact-dark.png` covers populated light appearance, strict empty results, the top and scrolled bottom of inline filters, similarity with the Japan folder constraint retained, and the minimum 780 × 520pt content frame in dark appearance. This is visual/interaction acceptance for the supplied slice, not held-out relevance acceptance or complete-MVP sign-off.

Source inspection confirms the incumbent Photo Workbench roles: appearance-aware native text/control backgrounds, system SF styles, secondary metadata, native controls and dividers, and a 2pt system-accent selection outline. The reusable spacing remains 8/20/24pt. Grid thumbnails preserve aspect ratio at 128pt height with adaptive 160pt minimum columns; the filter area scrolls within 260pt. Search mode, Filters, the secondary View menu, collapsed indexing disclosure, visible constraint summary/reset, and similarity reference/Exit Similar keep operations legible without a persistent control dashboard. No new shipping raster assets were introduced; displayed photographs remain excluded local cache derivatives.

`DESIGN.md` and `.impeccable/design.json` retain their historical M1 record; the workspace brief still describes its pre-implementation expression. Their disabled-search/filter-popover, fixed grouping/sorting-picker and pending-grid descriptions predate M3. This existing documentation drift is recorded here and left unchanged for this ordinary extension. Full keyboard traversal, numerical/increased contrast, accent variants and reduced motion remain unverified as listed above.

The user's subsequent image-only gallery refinement supersedes the earlier labeled tiles. `.impeccable/review/m3-image-only-wide.png` and `m3-image-only-compact-dark.png` verify the current light/wide and minimum-size dark gallery: no filenames, formats or status text appears beneath photos; selected-photo metadata remains in the inspector. Source inspection confirms aspect-preserving thumbnails, the selection outline, filename/availability accessibility labels, context actions, arrow navigation and Space preview remain present; live interaction checks retained those behaviors. The fresh gallery review disposition is **ship**, with no material fixes, within the same M3 acceptance limits above. Earlier captures remain historical evidence.
