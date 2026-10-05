# Local data and privacy

Photo Views catalogs existing folders. It reads originals to extract metadata and generate previews; search, tags, palette and People inference operate on local derivatives. It does not move originals or write tags/edits into them. Opening an original in an external editor hands that file to another app, whose behavior is separate.

## What stays on the Mac

- Catalog: sources/bookmarks and paths, file identity, metadata, embeddings, tags, favorites, collections, saved views, job states and RAW/JPEG associations.
- People: anonymous group IDs, face descriptors, per-preview fingerprints, merges/exclusions and cropped avatars. These are sensitive biometric-derived records even without names.
- Caches: thumbnails/analysis images, model files and worker diagnostics. Paths/metadata/diagnostics may reveal private archive information.

Default locations:

| Data | Location |
| --- | --- |
| Catalog and worker log | `~/Library/Application Support/Photo Views/` |
| Image previews (2 GiB budget) | `~/Library/Caches/PhotoViews/previews/` |
| Python runtime / CLIP model | `~/Library/Caches/PhotoViews/m0/{venv,model}/` |
| Face models and cropped avatars | `~/Library/Caches/PhotoViews/m0/people/` |

`PHOTO_VIEWS_DATA_DIR` changes the catalog directory and isolates its preview cache. `PHOTO_VIEWS_PYTHON` and `PHOTO_VIEWS_MODEL` change inference paths. People model/avatar storage derives from the model directory's parent; use a separate model directory to isolate it as well. SQLite data and caches are not encrypted by the app; use macOS account/disk protections appropriate for your archive.

## Network behavior

Setup uses package registries and Hugging Face/OpenCV upstreams to download software/models. Baseline inference uses local assets; there is no image/query upload, analytics service, cloud sync or paid provider configured. Optional hosted ideas in the PRD are not implemented.

## Removing data

Quit Photo Views first. Remove its catalog directory to remove catalog decisions and face descriptors; remove preview caches and the People directory to remove cached images/avatars. Removing the People directory also removes its weights, so setup must be rerun before another scan. Keep originals outside these locations. Catalog deletion loses saved views, tags, favorites, collections and correction decisions; make a private backup if needed.

Disconnected-drive search uses retained local data. Cache eviction can remove offline images while leaving metadata and embeddings. Do not share catalogs, logs or private screenshots in issues; use synthetic fixtures.
