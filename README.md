# Photo Views

Native macOS photo search and organization for existing folders and external drives.

Describe what you remember. Filter what you know. Group the results however you want.

## Project state

M0 probes demonstrate native preview generation and local retrieval on this Mac; acceptance limitations are tracked in [M0_STATUS.md](M0_STATUS.md). M1 provides a local native workspace, folder access, and saved view recipes; photo indexing and search come next.
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
python3 scripts/build_app.py --open
```

Use `--release` for an optimized build. The script creates an ad-hoc signed developer app in `.build/app/Photo Views.app`. No GitHub builds or hosting are involved.

The catalog is stored in `~/Library/Application Support/Photo Views/catalog.sqlite`. `PHOTO_VIEWS_DATA_DIR` overrides its directory for isolated local checks. Sources stay in their existing folders. App builds, catalogs, photos, previews, model weights, and probe output are excluded from Git.

[M1 status](M1_STATUS.md) records implemented behavior and validation. [Prism learnings](REFERENCE_LEARNINGS.md) connects reference observations to upcoming milestones.
