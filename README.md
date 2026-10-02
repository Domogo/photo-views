# Photo Views

Native macOS photo search and organization for existing folders and external drives.

Describe what you remember. Filter what you know. Group the results however you want.

## Project state

M0 probes demonstrate native preview generation and local retrieval on this Mac; acceptance limitations are tracked in [M0_STATUS.md](M0_STATUS.md). M3 connects resumable indexing and real-photo browsing to local visual/filename search, exact camera/date/folder filters, and Find Similar.
Target development/demo machine: Apple Silicon MacBook Pro (M5 Max, 48 GB).
Broad RAW support is the goal; support claims require camera/variant fixtures, not extension lists.

## Planning

- [Requirements](prd.md)
- [Product context](PRODUCT.md)
- [Selected design seed](DESIGN.md)
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

Type a description such as “cars at night” in the **Visual** search field. Switch its mode to **Filename** for filenames, folder paths or tags, including unconfirmed model suggestions. **Filters** expands camera, folder and inclusive capture-date constraints; the applied constraints remain visible after closing it. **View** contains grouping, sorting and saved-view actions. Select a photo and choose **Find Similar**; **Exit Similar** returns to browsing while retaining filters.

The coverage disclosure shows which photos have visual embeddings and exposes separate preview/visual indexing controls. Visual searches return up to 100 nearest candidates, not guaranteed matches or confidence percentages. Exact filters are never broadened. Filename search also works for indexed photos without visual embeddings.

This remains a local developer build, not a self-contained distributable. It reuses the externally stored M0 environment and pinned model under `~/Library/Caches/PhotoViews/m0/{venv,model}`. `PHOTO_VIEWS_PYTHON` and `PHOTO_VIEWS_MODEL` override those locations. Reproduce the environment with [M0 setup](spikes/m0/README.md); inference uses only local files with offline flags and never downloads from the app. The app bundles the versioned JSON-line worker script, while Python/packages/weights remain outside Git. Worker diagnostics stay beside the local catalog.

Run retrieval invariants using the configured Python environment:

```sh
"$PHOTO_VIEWS_PYTHON" scripts/search/checks.py
```

The local default on this development Mac is `~/Library/Caches/PhotoViews/m0/venv/bin/python`. Real-fixture probe arguments and the evidence/limitations are recorded in [M3 status](M3_STATUS.md).

M4 adds live saved views: use **View → Group by** to regroup the current results, then **Save View…**. **Unsaved changes** marks edits; **Update View** stores them and **Revert Changes** restores the saved recipe. **Refresh Results** checks current membership. Saved views include new matching indexed photos automatically and survive relaunch, including any unsaved draft.

M5 adds **View → Group by → Primary subject**, with suggested groups labeled explicitly and an Unknown subject bucket. In the details sidebar, accept/reject/edit suggestions or add custom confirmed tags. **Filters → Confirmed tags → Apply Tags** requires every listed tag to be confirmed; separate names with commas. **Favorite** adds the selected asset to Favorites. Create a manual collection in the sidebar, then use the selected photo’s **Collections** menu to toggle membership. Collections store explicit choices; saved views store live recipes. Decisions stay in the catalog and survive restart/reindexing, without writing metadata to originals. The starter vocabulary is people, animals, cars, buildings, food, mountains, water, and vegetation. Local calibration evidence and remaining accuracy limits are in [M5 status](M5_STATUS.md).

M6 expands **Filters → More metadata** with lens, format, ISO, f-number, shutter seconds and original dimensions. In Visual mode, **Interpret** reviews supported clauses such as `cars at night camera:"NIKON Z f" folder:Japan iso<=200 group by month`. **Apply Plan** keeps the visual intent, applies exact constraints and opens their editable controls. Unknown/ambiguous and unsupported directives block application; Syntax Help explains the bounded grammar. Full syntax and acceptance limits are in [M6 status](M6_STATUS.md).

## Drive recovery and RAW+JPEG pairs

Search and cached previews stay usable when a photo drive is disconnected. Reconnection queues a safe rescan; mount-path changes are resolved by volume identity, and Restore Access remains available for lost permissions. Originals are read-only.

View → Collapse RAW + JPEG shows qualifying pairs once. Click a photo and choose either file in Details to inspect its own metadata, tags and availability. Separate Pair survives rescans; View → Restore Automatic Pairs reverses separation in the current source scope. Exact filters apply to each file before pairs collapse. Indexing coverage counts files; the collapsed gallery counts logical photos.

M7 implementation and measured limits: [M7_STATUS.md](M7_STATUS.md).
