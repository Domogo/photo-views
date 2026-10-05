# Public demo images

`gallery.png`, `filters.png` and `palette.png` are unedited native app screenshots captured on 5 October 2026 from an isolated catalog of 24 original generated landscape illustrations. They contain no real people, private photos, GPS or personal archive paths. The screenshots/artwork are covered by the repository MIT license; macOS controls belong to the running native app.

These images illustrate the UI and deterministic palette behavior, not photographic retrieval quality, face accuracy or RAW support. The 24/24 indexed count applies only to this synthetic demo catalog.

To regenerate the source artwork outside the checkout:

```sh
"$HOME/Library/Caches/PhotoViews/m0/venv/bin/python" scripts/generate_demo_artwork.py --output /tmp/photo-views-demo-artwork
```

Launch with an isolated `PHOTO_VIEWS_DATA_DIR` and add that folder through the native picker. Use a separate model directory to isolate People storage too. Capture only the generated-artwork catalog. Do not add generated fixtures, catalogs or private review screenshots to Git.
