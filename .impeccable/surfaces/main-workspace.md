# Main workspace — Photo Workbench

Status: direction selected by the user, 2026-10-02; pre-implementation brief.

## Scope and mode

Native macOS main workspace, **Operate** mode. Follow PRODUCT.md and prd.md for scope and product truth; DESIGN.md owns reusable visual rules. This brief specifies the selected first-surface expression without authorizing implementation or publication.

## Direction contract

**THESIS:** A photograph-led workbench turns retrieval into an understandable, reusable view. Use familiar panes; avoid a dashboard composition with summary cards competing for space.

**OWN-WORLD:** Appearance-aware neutral surfaces, SF system typography, native controls, quiet separators, and a clear selection accent. Distinction comes from consistent hierarchy and precise behavior.

**STORY:** Choose sources, describe or filter, inspect the results, regroup, then save the complete view. Each operation leaves its effect visible.

**FIRST VIEWPORT:** Source/saved-view sidebar; broad central search; editable constraints immediately below; unique count with labeled Group by and Sort controls; generous grouped photo grid; optional inspector. Coverage sits beside results, availability beside sources.

**SIGNATURE:** The editable view recipe connects search, filters, grouping, sorting, and saving. Regrouping preserves the query, result membership, selection, and inspector where possible.

**MOTION:** Brief state transitions retain context. Large grids update without a whole-grid animation; reduced motion uses immediate changes.

## Layout and hierarchy

- Sidebar sections distinguish Sources, Saved Views, and Collections; Favorites is an accessible destination. Source rows show availability and indexing state without becoming progress dashboards.
- Search is the broadest input. Exact constraints occupy a stable second row, wrapping when needed rather than disappearing. Grouping and sorting are labeled controls separate from membership filters.
- Compact group headers name the bucket and its count. Show the unique result count separately when groups allow repeated memberships. Unknown is a real bucket.
- Grid cells share stable geometry with aspect-preserving thumbnails. Do not expose all filenames and metadata under every image. Availability and pairing remain discoverable independently of hover.
- Inspector places preview and relevant actions before metadata and tags. Use aligned metadata, separate Confirmed and Suggested tag sections, and direct accept/reject/edit actions.

Pane sizes are adjustable; inspector and sidebar can collapse using discoverable controls. Core search/group/sort/save controls stay reachable at small window sizes. Verify exact limits on the selected macOS target.

## View recipe behavior

1. Search accepts natural language and keywords. Interpreted exact constraints become editable labeled controls; unsupported or ambiguous input remains visible for correction.
2. Filter changes alter membership. Group by changes presentation. Sort changes ordering. Never imply a grouping operation moves files.
3. Save View captures sources, query, filters, grouping, and sorting, plus model/ranking settings required by the PRD. The native naming sheet summarizes the definition being saved.
4. Editing a saved view shows a plain changed-state indicator. Provide explicit save/update behavior; do not overwrite the saved definition merely because controls changed.
5. Find Similar shows the chosen reference image and a clear way to leave similarity mode. Keep exact constraints visible if they still apply.

## Selection and context

Keyboard focus and selected photos have distinguishable treatments. Selection remains identifiable across grouping changes; preserve the selected-photo scroll anchor where possible. If a filter removes the selected photo, show the new result state and avoid silently selecting an unrelated image.

Space opens the larger preview. RAW+JPEG members remain individually accessible, with per-asset metadata and availability. Offline opening requests reconnection while cached browsing continues.

## Status placement

- Show incomplete visual indexing coverage near the result count; metadata-ready photos remain useful.
- Show disconnected sources in the sidebar and unavailable originals where users attempt access.
- Failed files are individually inspectable, with actionable reasons; indexing continues.
- Suggested tags are unconfirmed evidence, distinct from confirmed tags and failures.
- No matches preserves the full recipe and offers explicit edits; do not silently relax constraints.

## Native verification before implementation sign-off

Review both system appearances, increased contrast, reduced motion, keyboard operation, window resizing, and selected-photo continuity. Exercise the PRD demo and offline/indexing/failure states on named hardware. Validate readable control labels and uncluttered grids using actual representative RAW/JPEG/HEIC fixtures. Placeholder images or synthetic counts cannot establish retrieval or performance results.

## Remaining decisions

Minimum macOS, actual layout measurements, semantic color implementations, icon choices, exact type/spacing/radius tokens, preview behavior details, and model/hardware/RAW fixture decisions. No buildPath preference was supplied by the choice, so none is stored. The next step for a rendered design requires its own concrete request; this brief completes planning.
