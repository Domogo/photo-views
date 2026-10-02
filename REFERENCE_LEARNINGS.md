# Learnings from Prism

Reviewed 2026-10-02: [Prism website](https://prism.futc.de/) and [creator video](https://www.youtube.com/watch?v=bnwqXhDbZSI). These are product descriptions and the creator’s account, not independent verification of performance or privacy.

## Decisions for Photo Views

| Learning | Application | Milestone |
| --- | --- | --- |
| Remembering content is easier than remembering folders; the video demonstrates natural-language retrieval. | Keep search central, with exact metadata filters alongside it. Preserve the selected Photo Workbench direction. | M3–M4 |
| A useful prototype still needs recovery from interrupted scans and folder changes (video around 10:25). | Persist per-stage indexing checkpoints. Test quit/relaunch, moved files, disconnected drives, and unchanged-file reuse. A restarted scan must not redo completed expensive work. | M2 |
| Local processing and untouched originals are central promises on the site. | Request read-only folder bookmarks; store catalog, previews, and models separately from originals. Make any first model download explicit with size and destination. | M1–M3 |
| Automatic tags need manual corrections and EXIF context (video around 13:40). | Store human tag decisions separately from model suggestions, including provenance/version. Reindexing must preserve accepted and rejected decisions. | M5 |
| File handoff matters beyond search (video around 14:45). | Keep Reveal in Finder available for sources now; add original-file reveal and drag-out for selected photos later. | M1, M6 |
| Model interchange was necessary during development. | Keep model/version identity in embeddings and recipes. Verify the actual chosen checkpoint’s terms separately before distribution; do not adopt the video’s broad licensing claim as fact. | M0, M3 |
| Supporting two desktop platforms substantially expanded testing. | Complete and validate the native Mac workflow first. | All |

## Scope retained

Prism’s creator explicitly excluded RAW support. Photo Views retains RAW as a core requirement, using our tested decoder pipeline and reporting unsupported variants honestly. The current Sony/Nikon fixtures do not establish compatibility with every camera.

The site’s visual treatment is a reference for restrained controls and photo prominence, not a replacement for our approved native layout. Its advertised hardware support and library scale need our own benchmarks. No external app installation, paid service, hosting, or GitHub automation is needed to apply these lessons.
