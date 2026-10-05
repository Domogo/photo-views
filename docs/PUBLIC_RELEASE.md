# Public-release preparation — 5 October 2026

The public-facing README identifies the app as a local research/hackathon developer build. Preparation adds MIT licensing for project code, upstream software/model notices, local-data/privacy and security guidance, contributing instructions, a unified external-runtime setup, pinned/checksummed model downloads and synthetic public UI captures. Historical milestone/evaluation notes live under `docs/history/`; canonical product/design requirements remain at the repository root.

## Local verification

- CatalogChecks and IndexChecks pass, covering catalog migration/recipes, exact plans, synthetic orientation/metadata/original integrity, durable indexing/restart, changed files, pairing and recovery.
- 25 worker checks pass on the documented runtime.
- Four setup regression checks cover damaged/missing model refusal, pinned fetching, provenance only after successful validation and no download in verify-only mode.
- A newly created Python 3.12 virtual environment outside the checkout installed the complete lockfile and OpenCV, passed pip dependency checks, and downloaded/verified CLIP, YuNet and SFace from pinned revisions. Package downloads reused the local pip cache; the environment and model directory started empty. Network/package-registry availability on other machines is not guaranteed.
- The existing runtime also passed offline setup verification.
- Three native public captures were visually inspected. A disposable 24-image generated-artwork catalog showed 24 indexed items; dominant-blue ≥25% returned 12. No private archive photos or faces appear in public images.

A fresh local clone of preparation commit `a4c184a` passed CatalogChecks, IndexChecks and the release developer-app build. Its setup verification, 25 worker tests and four setup regression tests passed with the freshly installed runtime. A disposable synthetic catalog encoded all 24 images in two batches without failures; a zero-cutoff visual query returned all 24 eligible items, and both face models loaded. This verifies execution, not semantic accuracy. Broader held-out retrieval/tag/identity accuracy, full accessibility, older macOS validation, notarization and self-contained packaging remain open. Publication is source availability, not a production-quality claim.

## History and data review

An all-reachable-object scan examined 242 historical text blobs for private keys, common GitHub/AWS/API token patterns, credential assignments and private filesystem paths. No credential pattern matched. The only private-path pattern findings were synthetic `/Volumes/Old Mount/Photos` test literals. Historical object filenames contained no photo/model/database/environment-key artifacts; the largest historical blob was approximately 47 KB.

Gitleaks 8.30.1 was downloaded from its official GitHub release and verified against the release SHA-256 manifest. Default rules flagged one SQLite UPSERT column-assignment literal (`excluded.last_access,byte_size=excluded.byte_size`) as a generic API key. Source review confirmed it is SQL, not a credential. `.gitleaks.toml` retains all default rules and allowlists only that exact matched SQL string. Subsequent all-history (29 commits) and committed-file snapshot scans passed with no findings. Reports/tool binaries remain outside Git.

This is bounded audit evidence, not a guarantee that no sensitive value exists. Private images, weights, catalogs, face crops/descriptors, caches, generated reports and credentials remain excluded. Only native captures of original generated artwork were added to version control. The public SUMMARY now uses tracked public-safe images rather than broken links to private review captures.

Existing Git commits contain the maintainer's personal author email. History is preserved: rewriting published commit IDs is a separate deliberate decision. The user explicitly approved public visibility with existing history and author metadata preserved on 5 October 2026. Future author metadata can use the maintainer's GitHub no-reply address if desired.

## Repository settings

Description and topics are set. No Actions, hosted builds, paid automation or infrastructure was added. Private vulnerability reporting initially returned HTTP 404 while the repository was private. After publication it was enabled successfully, and GitHub’s reporting-settings endpoint confirmed `enabled: true`. The SECURITY document links the private reporting route and retains a maintainer-profile fallback.

The repository became public on 5 October 2026 after explicit user approval; GitHub confirmed `PUBLIC` visibility. Existing reachable Git history and tracked content are publicly available. Concurrent app-branding edits were excluded from preparation/publication commits and remain separate work.
