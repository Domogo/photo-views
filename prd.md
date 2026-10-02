# Photo Views — Product Requirements Document

Status: Proposed hackathon MVP  
Updated: 2026-10-02  
Platform: Native macOS app  
Working name: Photo Views

## 1. Purpose

Build a native Mac app that helps users find and organize photos in existing folders and external drives using natural-language visual search, keywords, camera metadata, image similarity, and dynamic views.

Product promise: **Describe what you remember. Filter what you know. Group the results however you want.**

The initial use case is a large personal photo archive containing camera RAW files, JPEGs, and phone photos on an external HDD. The project is intended for a hackathon at work. Event duration, team size, demo hardware, and camera models are not yet confirmed.

## 2. Problem and audience

Users remember the subject, situation, person, or appearance of a photo more readily than its filename or folder. Collections span folders and drives; camera metadata is useful but difficult to combine with visual descriptions. Fixed folder structures offer only one organization perspective.

Primary audience: Mac users with personal or creative photo archives, including photographers with substantial RAW collections.

Success: users find relevant photos, understand the applied constraints, change how results are grouped, and save a live view without copying or reorganizing original files.

## 3. Market research

These are documented capabilities, not findings from hands-on comparison. Research was conducted on 2026-10-02. Verify current versions before competitive testing.

| Product | Relevant documented capabilities | Research focus |
| --- | --- | --- |
| [Excire Foto](https://excire.com/en/excire-foto/) | Local natural-language search, automatic keywords, people search, metadata, similarity and organization | Closest competitor: relevance, combined filters, grouping and indexing UX |
| [Immich](https://docs.immich.app/features/searching/) | Contextual CLIP search and metadata filters; [external libraries](https://docs.immich.app/features/libraries/) | Retrieval design and indexing existing folders |
| [digiKam](https://www.digikam.org/about/features/) | Metadata, tags, faces, similarity and organization; [natural-language conversion into advanced filters](https://www.digikam.org/news/2026-08-20-advanced_search_improvements_with_llm/) | Query interpretation and organization workflows |
| [Mylio Photos](https://support.mylio.com/find-photos-fast) | Dynamic Search, QuickFilters and AI SmartTags | Facet discovery and combinations |
| [ON1 Photo Keyword AI](https://www.on1.com/products/photo-keyword-ai/) | Automatic keywords, metadata search and XMP interoperability | Keyword quality and portability |
| [Apple Photos](https://support.apple.com/en-gb/guide/mac-help/mchl35c53342/26/mac/26) | Natural-language search on supported configurations and [Smart Albums](https://support.apple.com/guide/photos/create-smart-albums-pht6d60ca71/mac) | Native interaction patterns and saved rules |

Differentiation hypothesis: a folder-oriented native Mac catalog combining semantic search, explicit filters, and reusable grouping. This is not a claim that competitors lack these features.

Compare the same representative collection and queries in two or three competitors. Record relevance, time to first useful result, RAW handling, grouping flexibility, offline/external-drive behavior, and correction workflows. Distinguish natural-language-to-filter interpretation from semantic matching against image contents.

## 4. MVP scope

| Capability | Required behavior | Priority |
| --- | --- | --- |
| Folder catalog | Recursive indexing of selected folders; progress, pause/resume and incremental updates | Required |
| RAW images | Metadata extraction, previews, visual indexing, search and similarity for validated camera formats | Required |
| Natural-language visual search | Ranked results for descriptions such as “a dog running on a beach” | Required |
| Keyword search | Search filenames, imported keywords, manual tags and suggested tags | Required |
| Automatic keywords | Curated vocabulary; distinguish AI suggestions from confirmed tags; accept/reject/edit | Required |
| Metadata filters | Capture date, camera, lens, ISO, aperture, shutter speed, dimensions, format and folder where available | Required; implement camera/date/folder first |
| Dynamic grouping | Group current results by folder, month, camera or primary subject | Required |
| Saved views | Store query, filters, grouping and sorting; refresh membership as indexing changes | Required |
| Image similarity | Select a photo and find images with similar content | Required |
| Organization | Manual collections, favorites and tag editing | Required, minimal implementation |
| Offline catalog | Cached thumbnails, metadata and search remain available while a drive is disconnected | Required |
| Faces | Detect face presence/count for filtering if schedule allows | Stretch within MVP |
| Person identities | Cluster faces, name people and merge/split clusters | Follow-up |

JPEG, PNG, HEIC and validated camera RAW formats are in the MVP. Video, OCR, map browsing, cloud sync, physical file organization, bulk metadata writing and photo editing are excluded.

## 5. RAW requirements

RAW is first-class MVP functionality, not a post-hackathon enhancement.

- Confirm the user's camera models, RAW extensions and RAW variants before implementation. Potential extensions include NEF, CR2, CR3, ARW, RAF, ORF, RW2 and DNG; this list is not a blanket compatibility promise.
- Validate representative actual files from each required camera, including available compressed/uncompressed variants and orientations.
- Prefer embedded JPEG previews for fast browsing and visual indexing when suitable. Fall back to a supported RAW decoder when a preview is absent, unusable, or too small for analysis.
- Preserve orientation and apply a consistent color-managed preview pipeline. Record the preview source, decoder and pipeline version.
- Read camera metadata from the original RAW file, not just its embedded preview.
- Generate local thumbnails and model-sized derivatives; never modify the RAW original.
- Treat RAW+JPEG pairing as a reversible, non-destructive catalog association. Use filename stem, folder, capture metadata and camera identifiers; ambiguous matches remain separate.
- Offer a collapsed photo view with access to both original files. Keep metadata and file availability per asset even when a pair is collapsed.
- Do not equate a RAW+JPEG pair with a byte-identical duplicate.
- Report unsupported or corrupt files individually and continue indexing; do not silently omit them.
- Test decoder support early. Evaluate ImageIO first and a LibRaw-based fallback if required by the user's cameras, including dependency and packaging implications.

Acceptance: every file in the agreed RAW fixture set either produces a correctly oriented usable preview and accurate available metadata, or an explicit actionable unsupported/corrupt status. Search must include supported RAW images. Original file hashes must remain unchanged.

## 6. Primary workflow and native UX

1. Select one or more existing folders using a native macOS picker.
2. Browse thumbnails and metadata while visual indexing continues.
3. Search using a description, keyword or metadata constraints.
4. Change Group by and sorting.
5. Inspect metadata, correct tags, find similar photos or reveal an original in Finder.
6. Save the complete view definition.

Use a three-pane layout: sources/saved views, central thumbnail grid, and an optional details inspector. Toolbar: search, filter chips, Group by and sorting. Space opens a larger preview. Preserve keyboard navigation and selection when changing views where possible.

Show indexing coverage and stages explicitly: metadata ready, visual indexing, paused, failed files, or drive disconnected. Partial results remain usable. Disconnected originals have a visible availability indicator; opening them requests reconnection.

## 7. Dynamic views and grouping

A view stores:

`Sources + Search + Filters + Grouping + Sorting`

Example: search “dogs outdoors”; filter capture year 2022; group by month; sort within groups by relevance. Switching grouping to camera reorganizes the same results without new image inference.

Rules:

- Filters change membership; grouping changes presentation.
- Single-valued fields such as camera create mutually exclusive buckets.
- Missing metadata belongs to an explicit Unknown bucket.
- Multi-label keyword groups may contain the same photo more than once. Show unique result counts separately from membership counts.
- MVP primary-subject grouping uses a selected best supported tag or Unknown, not an invented description.
- Start with one grouping level. Nested year → month or camera → lens is follow-up.
- Similarity clustering is a separate computational feature, not ordinary SQL grouping; it is follow-up to query-by-example similarity.
- Saved semantic views store the query, model version, ranking configuration and relevant settings. Allow refresh after model changes and make changed results understandable.
- A saved view updates as matching assets are indexed; a manual collection stores explicit membership.
- “Group by” never moves files.

## 8. Recommended architecture

Native SwiftUI app with AppKit where needed, SQLite catalog and local inference. Target Apple Silicon for the initial prototype; minimum macOS version is an implementation decision.

### Catalog and file access

Use native folder selection and [security-scoped bookmarks](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) to persist access in a sandboxed app. Track source volume identity and relative paths, not only absolute mount paths. Store the catalog and derived caches locally on the Mac.

Use [ImageIO](https://developer.apple.com/documentation/imageio/cgimagesource) for supported image decoding, thumbnails and metadata; assess RAW fallback support against actual fixtures. Index metadata first, then embeddings and optional face detection. Persist per-stage job status and bound concurrency to avoid overwhelming an HDD or the UI.

Use source identity, available file identifiers, size and modification time to detect changes. Filesystem IDs are not equally reliable across external filesystems. Reconcile moves conservatively using hashes when needed; do not treat a disconnected drive as deletion. Rescan on reconnect; file watching alone is insufficient.

### Models and inference

Use paired image/text embeddings for semantic retrieval. An initial evaluation candidate is [OpenCLIP ViT-B/32 LAION](https://huggingface.co/laion/CLIP-ViT-B-32-laion2B-s34B-b79K), whose card lists MIT licensing and deployment/testing limitations. Review the exact checkpoint's license and intended-use documentation before selection. Do not use these whole-image embeddings for person identity recognition.

MobileCLIP has [official Core ML exports](https://huggingface.co/apple/coreml-mobileclip), but its [weights license](https://raw.githubusercontent.com/apple-aiml-research/ml-mobileclip/main/LICENSE_MODELS) explicitly excludes product development and commercial use. It is not the default for this work project without separate permission.

For the hackathon, a native Swift app may call a local Python worker over a versioned structured-message protocol. No browser UI or local HTTP server is required. This reduces model-conversion risk but increases packaging work. Prefer Core ML for suitable production inference after verifying conversion correctness, tokenizer behavior and performance. Model weights remain downloadable assets outside Git.

### Storage

Core entities: Source, Asset, Photo (optional RAW+JPEG association), Metadata, Embedding, TagAssignment, Collection, SavedView and IndexJob. Face observations and identities are separate entities if implemented.

Persist model and pipeline versions with embeddings and suggested tags. Preserve user edits during reindexing. SQLite handles metadata filtering, relationships and full-text indexing. Begin with exact vector comparison over the hackathon dataset; introduce approximate-nearest-neighbor indexing only if measured latency requires it.

For illustration, 100,000 512-dimensional Float32 embeddings occupy approximately 205 MB before index overhead. Thumbnails can dominate storage; set cache limits and measure actual footprint.

## 9. Search and tagging pipeline

Keep three mechanisms separate:

1. Exact constraints: capture date, camera, folder, confirmed tags and eventually confirmed person.
2. Text retrieval: filenames, keywords and notes.
3. Visual relevance: query/image embedding similarity.

Apply hard filters before final top-k selection. Fuse text and visual retrieval with an evaluated method such as reciprocal-rank fusion instead of adding incompatible raw scores. Similarity scores are not probabilities. Preserve “no exact matches” rather than silently relaxing filters.

Automatic tagging starts with a curated vocabulary. Compare image vectors with tag prompt vectors, tune thresholds per tag, and expose uncertain suggestions separately. Do not treat a softmax across unrelated tags as independent tag probabilities. Store provenance and user rejection so reindexing does not undo corrections.

Mixed natural-language queries produce an editable search plan, e.g. visual intent “outdoor dogs”, capture year 2022, camera Nikon, group month. Validate against an allowlisted schema. Code builds parameterized queries; the model never supplies arbitrary SQL or file operations. Ambiguous dates/cameras remain editable or request clarification. Unsupported phrases remain visible rather than being silently ignored.

## 10. DSPy and Jev strategy

### DSPy

Use [DSPy](https://dspy.ai/current/) in a development/evaluation pipeline to optimize supported query interpretation, decomposition and grouping selection. Define explicit input/output signatures; compare instructions and few-shot examples against labeled queries using [optimizers](https://dspy.ai/3.1.0/learn/optimization/optimizers/).

Primary task: Query + available catalog fields + reference date/timezone → validated search plan with visual text, exact filters, grouping and ambiguity flags.

DSPy does not automatically improve image embeddings, train a visual model, or make a Python program run in Swift. If exporting optimized instructions into a native implementation, preserve adapter behavior, output schema and validation, then rerun the same benchmark.

### Jev

The [linked TypeSafe announcement](https://typesafe.ai/blog/introducing-system-one-models-and-jev) describes typed probabilistic decisions rather than unrestricted text generation; it does not establish local image inference. Consider Jev for bounded choices such as query route, supported grouping, ambiguity or candidate evidence relevance. Typed correctness is not semantic correctness, and provider speed/calibration claims require testing on our tasks.

[DSPy documents experimental Jev integration](https://dspy.ai/current/tutorials/jev_decisions/): Noul, Choice, Score, optional TypeSafe backend and ReAnchor for fitting decision parameters. Pin experimental versions if used. These types can also run with supported generative language-model backends.

For caption/metadata-based reranking, retrieve candidates locally first and send only the permitted evidence. A textual judgment cannot recover visual facts missing from that evidence. Do not assume Jev supports image input or downloadable local weights without verifying a separate offering.

Keep hosted Jev optional and off by default. Baseline indexing and retrieval work offline after downloads. Do not send personal/work images, faces, GPS, captions, paths or queries to a provider without explicitly opting into that feature and defining its payload. Benchmark any hosted experiment on an approved demo collection with explicit cost limits.

Neither DSPy nor Jev fixes a candidate-retrieval failure by itself. Add them only after a baseline and held-out comparison show a useful gain.

## 11. Faces

[Vision face detection](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest?changes=latest_4) supplies face observations, not a complete person-recognition system. The first step is presence/count and face crops. Person grouping requires a separately licensed face-embedding model, clustering and correction UI.

Do not label identity from appearance alone. Names are user-assigned; uncertain groups remain unconfirmed. Merge/split corrections must survive reindexing. Use authorized demo photos. No demographic or emotion inference is required.

## 12. Evaluation and acceptance

Create a fixed, human-labeled benchmark using representative JPEG, HEIC and RAW photos. Include objects, colors, activities, relationships, metadata constraints, missing fields, ambiguous language, corrupt files and offline sources. Split by event/session to avoid near-duplicate leakage between tuning and held-out evaluation.

Targets below are proposed, not measured performance claims:

| Measure | Hackathon target |
| --- | --- |
| Visual retrieval | At least one labeled relevant result in top 10 for ≥80% of answerable held-out queries; also report nDCG@10 or precision@10 |
| Hard filters | No returned assets violating supported explicit constraints |
| Query interpretation | ≥90% exact agreement on supported filter/group fields |
| Suggested tags | ≥90% precision on the agreed vocabulary; report coverage/recall separately |
| RAW compatibility | Pass the agreed camera fixture matrix; explicit errors for unsupported cases |
| Local latency | P95 under one second for indexed demo collection on named demo hardware |
| Resilience | Resume after restart; reconnect drive without losing catalog or deleting offline records |
| Original integrity | No changes to original file hashes during indexing/search/grouping |
| Grouping | Correct known/Unknown groups and understandable multi-membership counts |
| Saved views | Matching newly indexed photos appear without recreating the view |

Measure cold/warm search, initial indexing throughput, memory, model/cache size and UI responsiveness. Do not promise an indexing duration before testing HDD and RAW throughput.

Compare separately: baseline embedding search; hybrid text/metadata retrieval; query interpretation; optional Jev reranking; DSPy-optimized interpretation. Report relevance, latency and cost on the same held-out queries. Keep only improvements justified by evidence. Human labels are primary; model judges are supporting signals.

## 13. Hackathon delivery plan

Planning assumption only: two-to-three-day event, experienced team, Apple Silicon demo Mac, 2,000–5,000 representative images. Re-scope when actual duration/team are known.

1. Technical spike: validate required RAW cameras, model license, decoding, embeddings and one retrieval benchmark.
2. Vertical slice: folder selection → resumable catalog → native thumbnails → visual search.
3. Product slice: metadata filters, dynamic grouping, saved views, tags and image similarity.
4. Reliability: offline sources, RAW+JPEG associations, error states and evaluation.
5. AI experiment: DSPy query interpretation and optional bounded Jev comparison. Face detection only if time remains; identity recognition follows later.

Protect the core RAW/search/grouping flow before adding model complexity. If packaging a Python worker is too expensive, demo a native development build with documented environment setup; do not describe it as a self-contained distributable.

Demo: search a collection containing RAW photos; constrain camera/date; switch month → camera grouping; find similar images; save a live view; index a new matching photo; disconnect the HDD and continue browsing cached results. Show measured baseline-versus-optimized results if the AI experiment produces a real gain.

## 14. Open decisions

- Hackathon date, duration, team size and skill mix.
- Camera makes/models, RAW variants and sample fixtures.
- Demo Mac, minimum macOS version and collection size.
- Exact visual checkpoint, tokenizer, inference backend and licensing review.
- Whether optional hosted calls are allowed and their budget/data policy.
- Required languages; begin with evaluated English queries unless otherwise requested.
- Whether “faces” means presence filtering for the demo or named person recognition.
- Distribution goal: developer build, signed/notarized app, or later App Store release.

## 15. Project constraints

The application is native macOS, not a browser application. Original photos stay in their existing folders. RAW support is mandatory for the agreed cameras. Baseline search is local with no paid API dependency. This PRD does not authorize publishing the work project or uploading its photo collection.

For personal repositories, do not add or enable custom GitHub Actions or paid GitHub automation without a specific request. Run checks locally. Store model weights, photo fixtures, catalogs, caches and credentials outside version control.
