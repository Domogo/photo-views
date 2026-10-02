# Quiet photo canvas — implementation checkpoint

Approved 2026-10-02: full-proportion flowing gallery, image-first workspace, natural-language search with expandable filters, overall-palette search first. Implementation is built locally. Native wide/light and compact/dark checks are complete; the reviewer scored both requested corrections resolved (ship at the fix-list scope). The updated normal app has been opened. This is not M8 benchmarking completion.

## Implemented

- Optional initial navigation/details panes; photo selection opens Details. Native toolbar exposes navigation/details and Command-F focuses search.
- One compact search row, Filters drawer and View menu. No permanent example/syntax/live-view explanatory rows. One result/indexing disclosure; active exact constraints and palette are individually removable.
- Recycled AppKit collection-view shortest-column masonry with full orientation-aware proportions, 8pt gutters and 12pt insets. Image-only cells; spatial keyboard navigation, Space preview, grouping scroll anchor and paired-file logical selection retained.
- Supported mixed-query clauses apply on Return or Search; ambiguous/unsupported clauses block execution for correction. Plain visual descriptions retain debounced retrieval. The finite M6 grammar remains the interpreter's scope.
- Overall-palette swatches and area slider; “mostly blue” / “predominantly blue” apply a blue palette constraint. Colored-object prose remains visual intent.
- Versioned `srgb-hsv-area-v1` histograms from orientation-corrected sRGB derivatives, 64×64 area sampling, twelve named color families. A selected family must be the largest family and meet minimum coverage (25% default; editable 5–100%). Coarse classification is not a majority-pixel promise, calibrated perceptual matching, or object detection.
- Bounded local palette batches, durable cache/fingerprint validation, explicit missing-preview retry and full eligible-catalog coverage. Palette-only search requires the configured Python/Pillow runtime but no visual model inference or downloads.
- Exact constraints and per-file organization apply before ranking/pair collapsing; palette ranking cannot reintroduce assets excluded by keyword or reference-image eligibility. Saved recipes persist color, coverage and palette version. Schema 4→5 adds only the palette cache; old recipes remain compatible.

## Verified locally

- Optimized native build and ad-hoc developer app packaging pass.
- CatalogChecks pass, including old/new recipe decoding and palette language, all six human-approved M6 cases and 24 additional interpretation cases.
- IndexChecks pass, including M1→5 migration, M7 disconnect/restart/recovery, pair separation/restoration, changed files, corrupt isolation, original integrity and cache pressure. The reconstructed M1 fixture now also drops the new palette table before testing migration.
- Eighteen worker checks pass. Palette checks cover pixel-area and neutral/brown families, bounded reuse, no visual model loading, source/format/keyword constraints, offline cached results, eviction, changed fingerprint, missing previews/retry, invalid coverage and future-version refusal.
- Isolated copy of the real catalog: 19,877 eligible files, 5,085 cached previews analyzed in 29.549 seconds, no palette failures. One palette-only query took 0.1037 seconds; this is a single local sample, not a P95 benchmark. Dominant-blue query yields 355 qualifying logical candidates and returns the nearest 100; exact NEF constraints pass. Setting catalog availability to offline preserves the ranking without reading originals; this is a catalog-state check, not a new physical disconnect test.
- Two representative user-original SHA256 hashes still match the M7 baselines. All palette processing reads derivatives and writes only local catalog data.
- Source-derived DESIGN.md and sidecar refreshed by the Impeccable documenter. Native revision captures now exist; full accessibility, retrieval quality and frame-rate signoff remain unmeasured. M1/M7 captures are not revision evidence.

Evidence outside Git: `~/Library/Caches/PhotoViews/design-v2/{palette-proof.json,palette-integration.json,catalog.sqlite}`. Models, previews, original photos and generated reports remain outside Git. GitHub remains private code storage only; no Actions, hosting, CI/CD or paid service was added.

## Deep-scroll correction and native verification

A two-second process sample of the hung gallery showed the main thread spending nearly all samples in SwiftUI/AttributeGraph nested lazy-stack placement and per-cell geometry updates; CPU remained at 100%. The process used about 108MiB, so this was a layout feedback problem rather than memory exhaustion.

The gallery now uses reusable NSCollectionView cells and deterministic orientation-aware masonry frames, without per-image geometry preferences. ImageIO decodes 512px cached thumbnails off the main thread, with four concurrent operations, cancelled work on reuse, and a 64MiB/256-image cache budget. The total app memory is not limited to this cache.

Repeated large native scrolls loaded all 3,416 logical photos and reached the bottom of the updated normal app. Native accessibility queries remained responsive; the QA process returned to 0% idle CPU with about 258MiB RSS after the stress pass. This establishes correction on this Mac/catalog, not sustained 60fps or a general performance guarantee. Pure geometry for 20,000 photos at three widths passed proportions/bounds/determinism/nonoverlap checks in about 7ms including repeated calculations.

Wide/light and compact/dark captures cover gallery, expanded filters, active palette, paired inspector and blocked query. Return applied `mostly green format:ARW`; chip removal restored browsing, Down changed selection, Space opened preview, and JPEG/NEF switching retained logical selection. The independent reviewer found composition matches the approved direction and requested truthful blocked-search status plus updated system documentation; the reviewer scored both corrections resolved. The ship disposition applies to this fix list, not broad accessibility or performance signoff. Earlier transient reload imagery was absent in settled recaptures.

The normal catalog was backed up outside Git before reopening: schema4→5 retained 19,877 files and two saved views. Original preview indexing remains paused. No originals were edited. Broad palette quality, full accessibility and M8 benchmarking remain separately scoped.
