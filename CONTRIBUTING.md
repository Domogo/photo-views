# Contributing

Photo Views is a native macOS research prototype. Read [README.md](README.md), [prd.md](prd.md), [PRODUCT.md](PRODUCT.md), [DESIGN.md](DESIGN.md) and [AGENTS.md](AGENTS.md) before changing behavior.

Discuss larger changes in an issue first. For a fix, describe the user-visible problem, change and local verification in the pull request. Keep changes focused. Contributions are made under the repository's MIT license.

## Local checks

```sh
swift run CatalogChecks
swift run IndexChecks
"$HOME/Library/Caches/PhotoViews/m0/venv/bin/python" scripts/search/checks.py
"$HOME/Library/Caches/PhotoViews/m0/venv/bin/python" scripts/check_setup.py
python3 scripts/build_app.py --release
```

Use the configured Python path if your setup root differs. Checks must use disposable fixtures/data; never mutate the normal catalog or originals to test recovery. For native UI changes, inspect the actual app at wide and compact sizes and relevant system appearances. Build success alone does not verify UI behavior.

Do not commit private photos, face crops/vectors, GPS, model weights, catalogs, caches, logs, credentials or generated probe reports. Public screenshots must use original generated artwork or cleared images. Use synthetic reproductions in issues instead of attaching a personal catalog.

Checks and builds run locally. Do not add GitHub Actions, hosted builds, paid services or automation. Preserve originals and keep baseline inference local. Changes to model versions must update checksums, provenance, notices and evaluation evidence together.
