# Photo Views

Native macOS photo search and organization for existing folders and external drives.

Describe what you remember. Filter what you know. Group the results however you want.

## Project state

M0 probes demonstrate native preview generation and local retrieval on this Mac; acceptance limitations are tracked in [M0_STATUS.md](M0_STATUS.md). M1–M7 connect indexing, local retrieval, live views, organization, metadata constraints and drive recovery. The approved quiet photo canvas revision adds a flowing gallery and local overall-palette search.
Target development/demo machine: Apple Silicon MacBook Pro (M5 Max, 48 GB).
Broad RAW support is the goal; support claims require camera/variant fixtures, not extension lists.

## Planning

- [Requirements](prd.md)
- [Product context](PRODUCT.md)
- [Design system](DESIGN.md)
- [Workspace brief](.impeccable/surfaces/main-workspace.md)
- [UX plan](UX_PLAN.md)
- [Implementation milestones](IMPLEMENTATION_MILESTONES.md)

Original files are never modified. Baseline search stays local; hosted experiments are optional and off by default. Checks run locally without custom GitHub Actions.

## Local developer build

Requires Apple Silicon macOS and the Swift command-line tools. The package declares macOS 14 as its implementation floor; runtime validation so far is on this Mac’s macOS 26.6.2.

```sh
swift run CatalogChecks
swift run IndexChecks
python3 scripts/build_app.py --open
```

Use `--release` for an optimized build. The script creates an ad-hoc signed developer app in `.build/app/Photo Views.app`. No GitHub builds or hosting are involved.

The catalog is stored in `~/Library/Application Support/Photo Views/catalog.sqlite`. `PHOTO_VIEWS_DATA_DIR` overrides its directory for isolated local checks. Previews are stored in `~/Library/Caches/PhotoViews/previews` with a 2 GiB disk budget; an isolated data-directory override also isolates its preview cache. Sources stay in their existing folders. App builds, catalogs, photos, previews, model weights, and probe output are excluded from Git.

[M1 status](M1_STATUS.md), [M2 status](M2_STATUS.md), [M3 status](M3_STATUS.md), [M4 status](M4_STATUS.md), [M5 status](M5_STATUS.md), and [M6 status](M6_STATUS.md) record implemented behavior and validation. [Prism learnings](REFERENCE_LEARNINGS.md) connects reference observations to upcoming milestones.

## Search on this Mac

Type a description such as “cars at night” in **Describe a photo…**. Use Command-F to focus search. **View → Search → Filename or keyword** searches filenames, folder paths or tags, including unconfirmed suggestions. **Filters** expands camera, folder and inclusive capture-date constraints; the applied constraints remain visible after closing it. **View** contains grouping, sorting and saved-view actions. Select a photo and choose **Find Similar**; **Exit Similar** returns to browsing while retaining filters.

The small result/indexing status disclosure shows which photos have visual embeddings and exposes separate preview/visual indexing controls. Visual searches return candidates meeting the adjustable similarity cutoff, with incremental loading; scores are not guarantees or confidence percentages. Exact filters are never broadened. Filename search also works for indexed photos without visual embeddings.

This remains a local developer build, not a self-contained distributable. It reuses the externally stored M0 environment and pinned model under `~/Library/Caches/PhotoViews/m0/{venv,model}`. `PHOTO_VIEWS_PYTHON` and `PHOTO_VIEWS_MODEL` override those locations. Reproduce the environment with [M0 setup](spikes/m0/README.md); inference uses only local files with offline flags and never downloads from the app. The app bundles the versioned JSON-line worker script, while Python/packages/weights remain outside Git. Worker diagnostics stay beside the local catalog.

Run retrieval invariants using the configured Python environment:

```sh
"$PHOTO_VIEWS_PYTHON" scripts/search/checks.py
```

The local default on this development Mac is `~/Library/Caches/PhotoViews/m0/venv/bin/python`. Real-fixture probe arguments and the evidence/limitations are recorded in [M3 status](M3_STATUS.md).

M4 adds live saved views: use **View → Group by** to regroup the current results, then **Save View…**. A small changed-state indicator marks edits; **Update View** stores them and **Revert Changes** restores the saved recipe. **Refresh Results** checks current membership. Saved views include new matching indexed photos automatically and survive relaunch, including any unsaved draft.

M5 adds **View → Group by → Primary subject**, with suggested groups labeled explicitly and an Unknown subject bucket. In the details sidebar, accept/reject/edit suggestions or add custom confirmed tags. **Filters → Confirmed tags → Apply Tags** requires every listed tag to be confirmed; separate names with commas. **Favorite** adds the selected asset to Favorites. Create a manual collection in the sidebar, then use the selected photo’s **Collections** menu to toggle membership. Collections store explicit choices; saved views store live recipes. Decisions stay in the catalog and survive restart/reindexing, without writing metadata to originals. The starter vocabulary is people, animals, cars, buildings, food, mountains, water, and vegetation. Local calibration evidence and remaining accuracy limits are in [M5 status](M5_STATUS.md).

M6 expands **Filters → More metadata** with lens, format, ISO, f-number, shutter seconds and original dimensions. In natural-language mode, press Return to apply supported clauses such as `cars at night camera:"NIKON Z f" folder:Japan iso<=200 group by month`. Recognized constraints become removable chips; expand Filters to edit their values. Unknown/ambiguous and unsupported directives show a correction panel and block execution; Syntax Help explains the bounded grammar. Full syntax and acceptance limits are in [M6 status](M6_STATUS.md).

## Drive recovery and RAW+JPEG pairs

Search and cached previews stay usable when a photo drive is disconnected. Reconnection queues a safe rescan; mount-path changes are resolved by volume identity, and Restore Access remains available for lost permissions. Originals are read-only.

View → Collapse RAW + JPEG shows qualifying pairs once. Click a photo and choose either file in Details to inspect its own metadata, tags and availability. Separate Pair survives rescans; View → Restore Automatic Pairs reverses separation in the current source scope. Exact filters apply to each file before pairs collapse. Indexing coverage counts files; the collapsed gallery counts logical photos.

M7 implementation and measured limits: [M7_STATUS.md](M7_STATUS.md).

## Image-first gallery and dominant colors

Navigation and the inspector start hidden; the toolbar exposes them, and selecting a photo opens Details. The gallery uses lazy flowing columns, full image proportions and narrow gutters. Filenames and metadata remain in Details. Filters expands only when requested; active exact constraints are individually removable.

Use **Filters → Overall palette** to select a named color and its minimum image area, or type `mostly blue` / `predominantly blue` and press Return. A family must be the image’s largest color family and meet the area threshold (default 25%). `Blue car` remains a visual description. Color constraints combine with descriptions and exact filters; saved views persist them.

Palette analysis uses existing sRGB previews in bounded local batches. It needs the configured Python runtime/Pillow but no model inference or downloads. Partial coverage remains visible during color search. Cached palettes work after preview eviction or drive disconnection; rebuilding a missing preview and retrying palette analysis repairs failures. This is a coarse histogram, not object detection or calibrated perceptual matching.

Revision evidence and remaining native handoff: [CANVAS_STATUS.md](CANVAS_STATUS.md).

Ranked search now keeps candidates meeting Minimum match score in Filters (text default 0.20, reference-image default 0.75), then loads 500 more as you approach the gallery end. The status shows loaded versus total qualifying logical photos. Scores are cosine similarity, not probabilities; defaults are provisional, not calibrated relevance guarantees. Palette-only search uses palette coverage instead. Saved recipes retain an explicit score threshold.

Right-click a photo to open its selected original in Photomator, Lightroom or Lightroom Classic. Only installed editors under Applications are listed; shortcuts are disabled when the original is unavailable. RAW+JPEG member selection is respected. Photo Views does not edit or copy the original as part of launching the editor.

Visual and reference searches keep near-identical shots adjacent by default (View · Similar shots), while explicit month/camera/subject grouping remains available. Anchor-based grouping requires image cosine similarity ≥ 0.92 and a 64-bit preview difference-hash distance ≤ 20; low-contrast previews (grayscale standard deviation < 5) and missing hashes are excluded. These are provisional heuristics, not calibrated duplicate probabilities. Every photo remains individually selectable at its full proportions, groups receive no headings, and pagination extends a boundary to include the entire group. Native verification found DSC06059.ARW and DSC06060.ARW together and placed the two poster shots side by side. Background indexing refreshes avoid cancelling a pending query.

Grid zoom: compact minus/plus magnifier buttons beside View and View-menu commands support ⌘− / ⌘+; ⌘0 resets. Seven persisted size steps adjust column density while preserving full photo proportions and the first visible photo on zoom. Native button and keyboard verification confirmed larger images/fewer columns, zoom out and reset.

## People (local face groups)

Open People in the sidebar to scan cached previews and browse anonymous face avatars. Selecting an avatar opens the matching photo grid. First entry starts scanning; Pause stops after the current small batch, and Scan New Photos resumes pending previews. Counts and photos are partial until the scan finishes. Right-click an avatar to merge two groups; right-click a photo inside a person’s gallery and choose Not This Person to exclude it. Restore Excluded Photos reverses that person’s exclusions. Matching can miss small/profile/occluded faces and can split or confuse identities; groups are suggestions, not verified names.

Run `python3 scripts/search/setup_people.py` once to install `opencv-python-headless==4.11.0.86` and download checksum-verified YuNet/SFace weights from OpenCV Zoo revision `47534e27c9851bb1128ccc0102f1145e27f23f98`. Model-directory licenses are Apache 2.0. Setup downloads only software/models; the app performs no network face inference. Weights and cropped avatars live under `~/Library/Caches/PhotoViews/m0/people`, outside Git. SQLite stores anonymous person IDs, face vectors, per-preview fingerprints and exclusions in additive people/faces/face_scans/person_aliases/person_exclusions tables. Originals remain untouched. Rebuilding the cache can change suggested groups; naming, identity-aware natural-language search, and a comprehensive split/recluster workflow remain follow-up work.

Detection uses cached previews, YuNet score ≥ 0.9 and faces ≥ 32 pixels. SFace uses normalized 128-dimensional descriptors and a provisional cosine threshold of 0.50 against a fixed representative; this avoids transitive automatic cluster chaining. Two distinct faces in one photo cannot join the same suggested group. Manual merges are persisted; the target representative remains the anchor for future automatic matches. A dedicated serialized worker with four-preview batches keeps face inference off the UI and search worker.

People verification: 22 local worker checks pass, including persisted merged-ID redirects and exclusions surviving face-order changes on reindex; native wide and compact light browser, selected-person gallery, merge chooser/cancel, pause, and exclusion/restore (11 → 10 → 11 photos) were checked. Dark/high contrast, comprehensive accessibility, executed user merges and broad recognition accuracy remain unmeasured.
