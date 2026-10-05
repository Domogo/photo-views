# Still

<!-- impeccable:product-schema 1 -->

Source of truth: [prd.md](prd.md), updated 2026-10-02. This record summarizes confirmed product requirements; the PRD governs conflicts and detailed acceptance criteria.

## Platform

Native macOS. Impeccable 4.2.2's documented platform values do not include macOS; do not substitute `web`, `ios`, or `adaptive`. Follow macOS conventions and the PRD when tool platform routing is unavailable.

## Stack

Implemented prototype: SwiftUI/AppKit, SQLite, ImageIO and local Python/OpenCLIP/PyTorch inference on Apple Silicon. The package declares macOS 14; runtime evidence is on macOS 26.6.2. Delivery is an ad-hoc signed developer build with external runtime/weights. Core ML and standalone distribution remain follow-ups.

## Users

Mac users with personal or creative photo archives, including photographers with substantial RAW collections. The initial scenario is an existing archive of camera RAW, JPEG, and phone photos on an external HDD.

## Product Purpose

Help users find photos by remembered visual content and known metadata, regroup results, and save live views without copying, moving, or modifying originals.

Product promise: **Describe what you remember. Filter what you know. Group the results however you want.**

Success means finding relevant photos, understanding active constraints, changing grouping, and saving a reusable view.

## Positioning

A folder-oriented native Mac catalog combining semantic search, explicit filters, and reusable grouping. This is a differentiation hypothesis, not a verified exclusivity claim.

## Operating Context

Work hackathon prototype using existing folders and external drives. Catalog, metadata, thumbnails, and baseline retrieval stay local. Cached browsing and search continue while originals are disconnected. Metadata becomes available before visual indexing finishes; partial results remain usable.

Primary workflow: select folders → browse while indexing → search and filter → group and sort → inspect/correct tags/find similar/reveal in Finder → save view.

## Capabilities and Constraints

- Approved extension (2026-10-02): local overall-palette search, named colors and minimum image-area coverage; color-object detection remains outside this first version.
- Required: recursive resumable indexing, validated RAW support, visual and keyword search, suggested tag correction, metadata filters, single-level grouping, saved views, query-by-image similarity, minimal collections/favorites/tag editing, and offline catalog access.
- Implement camera/date/folder filters first; retain the PRD's remaining metadata requirements.
- Group by folder, month, camera, or primary supported subject. Filters change membership; grouping changes presentation and never moves files. Missing values use Unknown.
- Saved views store sources, query, filters, grouping, sorting, and relevant model/ranking settings. Collections store explicit membership.
- Suggested tags remain distinct from confirmed tags. Acceptance, edits, and rejection survive reindexing.
- RAW+JPEG pairing is reversible and non-destructive; availability and metadata remain per asset. Unsupported/corrupt files receive visible individual status.
- No silent constraint relaxation. Mixed queries expose an editable search plan and unsupported or ambiguous phrases.
- Baseline indexing/retrieval work offline after downloads with no paid API dependency. Optional hosted experiments stay off by default and require explicit data/cost authorization.
- Face presence/count is stretch; named identities are follow-up. No demographic or emotion inference.
- Excluded: video, OCR, maps, cloud sync, physical reorganization, bulk metadata writing, and editing photos.
- Keep weights, fixtures, catalogs, caches, and credentials outside Git. Do not add custom GitHub Actions or paid personal-repository automation without a specific request.

## Brand Commitments

Approved name: **Still**. The user selected Graphite color with Atelier top navigation and the Open Frame mark, then authorized implementation. The identity is quiet, photographic, understated, minimal, modern and bespoke. The mark comprises two filled opposing right-angle corners; the lowercase wordmark uses sharp custom geometry. Native macOS behavior, local processing, read-only originals, standard folder selection, keyboard navigation and Space preview remain binding.

Graphite is the default appearance; Light and System remain available in View. All photos, Favorites and People live in the top navigation; folders, saved views and collections appear on demand. Photographs retain full proportions in an image-only flowing gallery; filters and contextual details expand when useful. Functional text remains native system typography. DESIGN.md owns the implemented visual system; the main-workspace brief owns composition and state behavior. Fresh wide native review resolved the titlebar and heading fixes and returned ship for the scored View contrast fix only. Compact layout, full accessibility and System transitions remain unverified; earlier canvas approval is historical evidence only.

The displayed application and build artifact are Still / `.build/app/Still.app`. Preserve bundle identifier `com.domogo.photoviews` and existing Photo Views catalog/cache locations for continuity; the rename must not create an empty replacement catalog.

## Evidence on Hand

The repository contains the native app, local workers, synthetic checks, developer setup and original generated public demo captures. Milestone evidence is under `docs/history/`; SUMMARY.md distinguishes measured samples from unmet targets. Private fixtures/captures and models remain excluded. Do not present targets as achieved results or imply blanket RAW compatibility.

## Product Principles

1. Preserve originals and the user's existing folder organization.
2. Make search constraints, coverage, provenance, and availability understandable.
3. Keep retrieval, filtering, grouping, and collection membership conceptually distinct.
4. Keep partial and offline catalogs useful without hiding limitations.
5. Protect the core RAW/search/grouping workflow before optional model complexity.

## Accessibility & Inclusion

Preserve keyboard navigation and selection where possible, as required by the PRD. Additional recommended implementation criteria are recorded as proposals in docs/history/UX_PLAN.md rather than confirmed user requirements.

## Open Decisions

Hackathon timing/team; camera models and RAW variants/fixtures; demo hardware and collection size; minimum macOS; exact model/tokenizer/backend/license review; optional hosted-call policy/budget; required languages (English evaluation is the PRD's starting proposal); face scope; and distribution target.

People extension (2026-10-03): the user requested anonymous identity browsing. The top-navigation People destination displays cropped face avatars; selecting one opens all currently detected matches in the existing photo grid. Local YuNet/SFace indexing runs on cached previews, with progressive coverage, pause/resume, merge and per-photo exclusion/restore. No identity names are inferred. Detection and clustering are provisional and may miss faces or confuse/split people. Naming and identity-aware natural-language clauses are not shipped.
