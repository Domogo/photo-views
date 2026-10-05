# M7 — Drive reconnection, indexing recovery and RAW+JPEG integrity

Native macOS, local-only implementation. Originals stay in place and are never rewritten. GitHub stores code only; no Actions, CI/CD, hosting, paid APIs or spending changes.

## Delivered behavior

- Source availability is checked on mount/unmount notifications and every five seconds. A transition back to Connected queues a source rescan; paused indexing stays paused until an actual reconnection or an explicit resume. Interrupted discovering/indexing or durably disconnected sources resume on launch. Completed sources are rescanned on launch; a changed mount path also triggers rescan.
- Bookmarks resolve without UI or mounting. Fallback uses the mounted volume UUID plus relative source path, never a drive name. A wrong-volume path is refused. A stale bookmark refresh failure does not hide a readable resolved source; the resolved path can still be persisted with the existing bookmark. Unavailable source state is durable, and a missing known volume is labeled Disconnected rather than Access needed. Restore Access still requires the original volume/path identity.
- Mid-scan source loss cannot prove deletion. A partially unreadable scan preserves unseen records; a complete scan only marks absent originals unavailable. Mid-index source loss returns running jobs to pending and reports Disconnected rather than corrupting all remaining files. Records, metadata, embeddings and manual organization remain local.
- Discovery uses `inode-v1` filesystem inode identities within each source/volume, avoiding Foundation opaque resource IDs that can vary by mount. Existing legacy IDs upgrade using unchanged size/mtime without discarding valid output; ambiguous legacy moves stay separate instead of being guessed. Changed or moved members lose their old association until capture identity can be revalidated.
- Original availability is checked per file. Cached previews and cached embeddings continue to serve browsing/search without the drive. Missing or evicted previews have the existing explicit rebuild/reconnect actions.
- Conservative RAW+JPEG association uses one RAW and one JPEG with identical source/folder/stem, a matching nonempty camera model and valid capture timestamp. Conflicting recorded timezones prevent pairing; an unrecorded timezone on one member is allowed. Duplicate candidates, missing identity metadata, other formats and mismatches remain separate. Association does not mean byte-identical duplicate.
- Collapse RAW + JPEG is in View and defaults on; its optional recipe field persists in saved views while old recipes decode. Each file is filtered and ranked first; the first matching ranked member represents the logical photo. Collapsing happens before pagination/top-100. A sibling cannot bypass format, tags, favorites or collection constraints. Find Similar excludes both members of the reference photo when collapsing.
- Click a collapsed photo, then choose either original in the inspector. Its preview, metadata, availability, tags, favorites and collection membership remain per file. The gallery retains logical selection when switching members; keyboard movement and regrouping use the visible representative.
- Separate Pair records a durable exclusion that survives restart/reindexing. View → Restore Automatic Pairs clears exclusions in the view’s source scope and re-evaluates conservative associations. Collapse can also be turned off without changing associations. No originals move or change.

## Local checks

- CatalogChecks: prior source/bookmark, recipe/saved-view, organization, grouping, query-plan and future-schema refusal checks pass.
- IndexChecks: a folder is detached during a durable indexing checkpoint, the catalog reopened, and the folder restored. Cached preview, confirmed tag, favorite, saved recipe and original hash survive; pending jobs resume. Wrong-volume identity is rejected. Association tests cover valid cached offline members, missing timezone, camera mismatch, ambiguous RAW/two-JPEG candidates, durable separation and reversible restoration.
- Existing checks also cover actual child-process termination, corrupt-file isolation, moves, changed-file reindexing with rejected/confirmed tags preserved, zero-quota eviction, original hashes and M1 migration through schema 4.
- Seventeen local worker checks pass, including collapsed membership/selection, exact format and manual collection constraints, cached unavailable assets, expanded pairs, and excluding both members in similarity search. Existing bounds, ranking, tags and live-view invariants remain covered.
- The isolated copy of the real archive contains 19,877 discovered files and 5,085 visual embeddings; 1,781 cached metadata pairs qualify. Of the preview-ready membership, 5,085 files collapse to 3,416 displayed photos. This is a catalog association count, not a measured pairing precision claim.
- Native real-pair QA: filename DSC_0105 returns one photo; the inspector switches NEF ↔ JPG with each member’s own metadata; Separate Pair returns two results and Restore Automatic Pairs returns one. Other saved views and originals remain intact.

## Volume integration and handoff

Actual disposable APFS volume testing passed: unmounting while the native app runs reports Disconnected; reopening while unmounted retains cached visual search. Remounting at a different path resolves the original source by volume UUID and automatically rescans. A newly added matching JPEG appears in the unchanged live saved view, giving three files and two logical photos.

The first remount exposed unstable opaque Foundation file identifiers. After replacing them with per-volume inode identities, a repeated changed-path remount preserved every asset ID, all three embedding hashes, derivative modification times, saved recipe bytes and manual tag decisions. The source returned to Connected and its scan completed. Four representative user-original hashes and two test-copy hashes match their baselines. Evidence is saved outside Git in `~/Library/Caches/PhotoViews/m7-recovery/integration-summary.json`. Only the disposable test volume was unmounted; the user’s SSD remained connected and read-only.

The final release app was reopened against the normal catalog: schema 4, 19,877 files, 5,085 embeddings and two saved views were retained. The normal catalog has 1,669 associations and shows 3,416 preview-ready logical photos; association counts differ from the isolated QA catalog above. The source remains Connected and its previously paused indexing remains paused. The normal app is left open. Local release builds and the checks above passed.

Schema 4 adds durable pair exclusions; the existing photos/photo_assets tables hold associations. New recipe/result fields are optional. Per-file indexing/failure state and manual organization are retained; no migration merges tags or collection membership between files.

## Scope and limits

Camera model plus timestamp is the available capture identity; camera serial numbers are not extracted. Missing identity remains separate. Pairing precision across every camera/archive and full RAW compatibility are not established. Source-root renames are distinct from mount-path changes and require deliberate source/access handling. Fingerprints use filesystem identity, size and modification time; edits that preserve all those values are not guaranteed to be detected. Cache eviction can remove offline previews but preserves metadata and embeddings. Broad performance/relevance targets, physical cable removal, complete native accessibility and distributable packaging remain M8 verification.

## Scoped native design review

Reviewer disposition: **ship**, with no material findings in the full M7 changed regions. Reviewed artifact: `.build/app/Photo Views.app`. The reopened native captures and `WorkspaceView.swift`, `PhotoGrid.swift`, and `WorkspaceModel.swift` were compared with PRODUCT.md, the incumbent Photo Workbench rules in DESIGN.md and `.impeccable/design.json`, and the main-workspace surface brief.

- `.impeccable/review/m7-wide-pair.png` — 1180 × 760pt, light: JPEG member selected in the inspector while the collapsed logical photo retains its gallery highlight. Both originals have named member controls and per-file availability.
- `.impeccable/review/m7-wide-member-metadata.png` — 1180 × 760pt, light: the scrolled inspector exposes the selected JPG's metadata, original availability, suggested-tag actions and view recipe without adding gallery captions.
- `.impeccable/review/m7-compact-pair.png` — 780 × 520pt content, dark, all three panes visible: pair filenames, availability, selected-member checkmark, explanation and Separate Pair remain readable and fit the compact inspector.
- `.impeccable/review/m7-wide-offline.png` — light: after an actual disposable APFS test-volume unmount and app restart, cached visual search for “cars” remains visible alongside the Disconnected source, reconnection explanation and native Check Drive action. This capture records the offline presentation; changed-mount-path recovery proof is tracked separately above.

The extension retains the incumbent minimal native panes, neutral appearance-aware surfaces, image-only gallery, labeled native actions and scrollable per-file inspector. Names and member details stay in the inspector; pairing adds no decorative cards or competing visual hierarchy. Native state feedback makes disconnection understandable while cached images remain useful. No new visual world, token system, raster assets or approved composition is introduced. HTML/CSS detection does not apply to this SwiftUI/AppKit artifact, and no native macOS skill reference was available.

This is a bounded rendered/source design review, separate from CatalogChecks, IndexChecks, worker checks and volume integration proof. It does not establish complete recovery behavior, full accessibility, measured contrast, increased-contrast or reduced-motion behavior, retrieval relevance, pairing precision or blanket RAW compatibility. Historical M1 canonical DESIGN.md and sidecar scope remains unchanged; their implementation drift is deferred to M8.
