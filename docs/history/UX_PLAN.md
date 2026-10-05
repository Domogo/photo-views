# Photo Views — Proposed UX Plan

Prepared from [prd.md](../../prd.md) and [PRODUCT.md](../../PRODUCT.md). Scope: native macOS MVP workflow planning, without implementation; Photo Workbench is the selected visual direction. PRD requirements are binding; interaction details below are proposals for review.

## Job, audience, and outcome

**Surface mode: Operate.** Help an archive owner locate a remembered photo on existing folders/drives, understand why it appears, and preserve a useful search as a live view. The photographs carry the content; controls support retrieval and organization.

The focal interaction is switching a filtered search from month grouping to camera grouping while keeping the same unique result set and selection where possible.

## Workspace structure

Use the PRD's three panes:

- **Sidebar:** sources with availability and indexing status; saved views; manual collections; favorites. Keep saved rules and explicit membership visibly distinct. Provide Add Folder through the native picker.
- **Center:** search and editable interpreted constraints, filter controls, Group by, Sort, unique result count, and grouped thumbnail results. Prefer a stable toolbar structure across browse, search, and saved views.
- **Optional inspector:** preview, original files and availability, metadata, confirmed tags, suggested tags with accept/reject/edit, favorite/collection actions, Find Similar, and Reveal in Finder.

The inspector can collapse to give photos more room. Window sizing should preserve core controls; compact windows may hide the inspector and collapse the sidebar. Exact window limits and grid sizing await implementation on the chosen macOS version.

## Core flow

1. **Add a source.** Explain that folders are cataloged in place; open the native picker. Show the source immediately and begin metadata extraction, then visual indexing.
2. **Browse during indexing.** Show available thumbnails and explicit metadata/visual coverage. Source-level progress offers pause/resume and access to failed files. Search results disclose incomplete visual coverage.
3. **Search.** Accept visual descriptions and keywords. For interpreted mixed queries, expose visual intent and editable exact constraints. Display ambiguity or unsupported phrases; never quietly discard them.
4. **Refine.** Start with camera, date, and folder controls. Applied constraints remain visible and removable. Keep “no exact matches” separate from indexing incompleteness; any relaxation is an explicit user action.
5. **Regroup and sort.** Regroup current results without new image inference. Use explicit Unknown buckets. Show unique photo counts separately from memberships when a grouping permits repetition. Relevance is meaningful for ranked searches; ordinary browsing needs an explicit deterministic sort.
6. **Inspect.** Preserve keyboard selection; Space opens a larger preview. Expose RAW+JPEG members in a collapsed photo. Find Similar establishes a visible query-by-image reference that can be cleared.
7. **Save.** Save sources, query, filters, grouping, and sorting as a named live view. A proposed edited-state indicator distinguishes unsaved changes from the saved definition. Collections instead capture selected membership.

## State requirements

| State | User-facing behavior |
| --- | --- |
| No sources | Add Folder is the primary action; explain in-place cataloging and local baseline search. |
| Metadata ready, visual indexing underway | Browsing/filtering work; show visual coverage and allow pause/resume. |
| No matches | Preserve query and filters; offer deliberate editing/clearing without silently relaxing constraints. |
| Paused or interrupted indexing | Retain catalog results and resume the persisted job. |
| Unsupported/corrupt file | Surface individual actionable failures and continue other files. |
| Disconnected drive | Keep cached search/browsing; mark affected originals unavailable and request reconnection when opening. |
| Access unavailable | Explain source access failure and offer reauthorization through native folder selection. |
| Missing metadata/tag | Use Unknown; do not invent subject or camera values. |
| Suggested tags | Show provenance; acceptance/rejection/editing persists through reindexing. |
| RAW+JPEG association | Collapsed photo exposes each asset's format, metadata, and availability; ambiguous pairs remain separate. |
| Saved view changes after indexing/model refresh | Membership updates as assets index; model-change refresh and its implications must be understandable. |

## Proposed accessibility and native behavior

Use standard macOS controls and semantics where practical. Provide visible keyboard focus, accessible labels for thumbnails/actions, and status information beyond color alone. Make the search, grouping, sorting, grid, preview, and inspector operable by keyboard. Announce indexing/search status without excessive interruptions. Respect system appearance and reduced-motion settings. Verify shortcuts against macOS conventions before assignment; Space preview is already required.

## Scope and sequencing

First validate RAW decoding and retrieval with actual fixtures. Build the folder → resumable catalog → native grid → search vertical slice, then filters/grouping/saved views and minimal organization. Add offline recovery, pairing, and failure handling before optional DSPy/Jev/face experiments.

No landing page, browser UI, website deployment, person-identity workflow, photo editor, or file-moving operation belongs in this preparation.

## Review and validation

Walk through the PRD demo on the named demo hardware: search RAW-inclusive results; constrain camera/date; switch month → camera; find similar; save a view; index a new matching photo; disconnect the HDD and browse cached results.

Validate constraint correctness, grouping/Unknown counts, persistent tag corrections, selection behavior, RAW orientation, unavailable-file feedback, and original hashes. Use the PRD's held-out benchmark to evaluate retrieval. Its latency and relevance targets are proposed goals, not current measurements.

The PRD assumes a 2,000–5,000-image hackathon collection; actual size, throughput, thumbnail/cache footprint, and minimum/typical/maximum content ranges remain unverified.

## Decisions before UI implementation

- Confirm minimum macOS and demo hardware, camera/RAW fixture matrix, and event/team constraints.
- Resolve model/backend/license and distribution requirements through the technical spike.
- Photo Workbench is selected. Follow DESIGN.md and .impeccable/surfaces/main-workspace.md; resolve exact tokens through native implementation.
- The image-comp versus direct-code workflow is unanswered. No buildPath default has been stored. If a future session starts visual work with image generation available and no default, Impeccable uses comp-first for that session.
- Review this proposed interaction plan before treating it as a confirmed implementation brief.
