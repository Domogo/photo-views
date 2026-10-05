# M0 — Feasibility evidence and remaining gates

Updated: 2026-10-02. **Core feasibility demonstrated; M0 acceptance remains conditional.** This is evidence from a sample, not blanket RAW compatibility or a held-out benchmark pass.

## Confirmed execution target

The user confirmed this Mac as the development/demo target and requested progress through all milestones. Observed hardware: MacBook Pro, Apple M5 Max, 18 CPU cores, 48 GB memory; macOS 26.6.2; Swift 6.3.3 command-line tools. Initial delivery path: local developer build; event/team details and distributable packaging remain open.

Broad RAW coverage is the user's goal. Current archive evidence covers Sony ARW and Nikon NEF. Other makes/extensions/variants require representative fixtures before any support claim. A minimum shipping macOS remains undecided; successfully running probes on this Mac does not validate older systems.

## Decoder evidence

- Authorized source: user-selected external SSD archive. Local source paths and original metadata are kept out of Git.
- Spread sample: 60 real images, comprising 20 ARW from Sony ILCE-6000, 20 NEF from Nikon Z f, and 20 Nikon JPEGs.
- All 60 produced previews; no genuine decode failures in this sample; all before/after original hashes matched.
- Native pipeline: ImageIO properties from originals, existing-thumbnail request with generation fallback, orientation transform, explicit 8-bit sRGB conversion, JPEG derivative with normal orientation, pipeline version imageio-m0-v2.
- Approximately 9.21 seconds for the full probe, including compilation and original-file hashing. This is not pure decoding throughput or a full-archive indexing estimate.
- Local contact-sheet inspection showed plausible orientation and visual output. Reference color fidelity and camera-specific compression/RAW variants are not yet systematically verified.
- AppleDouble `._` files initially appeared as failed image candidates; discovery now excludes them. Genuine corrupt-image inputs still produce explicit errors.
- Synthetic tests pass for JPEG orientation-6 transform, PNG decode, corrupt-file continuation, unchanged original hashes, and output-tree isolation.

No LibRaw fallback is required by the sampled files yet. Do not install one merely to claim more formats; evaluate it when a real required fixture fails. ImageIO thumbnail provenance is recorded at API level and does not prove a particular embedded RAW JPEG extraction path.

## Retrieval evidence

Candidate: [LAION OpenCLIP ViT-B/32](https://huggingface.co/laion/CLIP-ViT-B-32-laion2B-s34B-b79K), immutable snapshot `1a25a446712ba5ee05982a381eed697ef9b435cf`.

The model repository lists MIT licensing. Its model card describes research-oriented use, in-domain testing requirements, and deployed-use limitations. It remains an evaluation candidate; listing MIT is not approval of production suitability. [OpenCLIP software license](https://github.com/mlfoundations/open_clip/blob/main/LICENSE) is a separate artifact.

Local prototype backend: Python/OpenCLIP/PyTorch on MPS, with normalized 512-dimensional image/text embeddings and exact cosine ranking. Candidate implementation uses the checkpoint's preprocessing configuration and records model/package versions. It downloads weights only; no image/query upload occurs.

Observed on 60 decoded images and nine exploratory queries (seven text, two image-reference):

| Measure | Observed sample result |
| --- | --- |
| Model loading | 1.39 s |
| Embedding 60 derivatives | 1.43 s |
| Query P95 including first-query effects | 0.081 s |
| Exploratory top-10 hit rate | 9/9 |

Labels were authored by the agent from local image inspection, not confirmed by a human. The small selected collection includes some RAW+JPEG/near-duplicate relationships. These numbers establish execution and promising retrieval only; they do not satisfy the PRD's held-out targets. Cold/warm performance, full-archive scale, event/session splits, and human relevance judgments remain to be evaluated.

The run used `HF_HUB_OFFLINE=1` after weight download and local-only model paths. This demonstrates the candidate did not need Hugging Face network access during the run; a strict network-disabled end-to-end test remains a later gate.

## Reproducible artifacts

- `spikes/m0/ImageProbe.swift`: native metadata/preview probe.
- `spikes/m0/probe.py`: read-only original-file orchestration and integrity manifest.
- `spikes/m0/select_fixtures.py`: spread sampling and AppleDouble exclusion.
- `spikes/m0/smoke.py`: synthetic decoder/integrity checks.
- `spikes/m0/fetch_model.py`: revision-recorded candidate download.
- `spikes/m0/retrieval.py`: local text/image retrieval and exploratory ranking metrics.
- `spikes/m0/requirements.lock`: versions resolved for Python 3.12 on this Apple Silicon machine.
- `spikes/m0/README.md`: commands and limitations.

Fixtures, derivatives, labels, embeddings, model weights, and complete reports stay in the local external cache, outside this repository. No private photo path, image, GPS, or capture metadata is pushed.

## Remaining M0 acceptance gates

1. Confirm required camera/RAW variants and broaden fixtures beyond the currently sampled Sony/Nikon files as available. Validate original metadata against known camera values and systematic orientation/color cases.
2. Obtain human-reviewed relevance labels with an event/session-separated tuning/held-out split; record missed queries and meaningful negative candidates.
3. Resolve exact checkpoint suitability before production distribution; keep the inference boundary replaceable.
4. Confirm minimum shipping macOS and packaging/distribution goal. The local Python worker is feasible here, not yet a self-contained app bundle.
5. Record actual event/team scope when known; do not convert the entire backlog into an unverified two-day estimate.

These gates do not prevent starting M1 on this Mac. They prevent treating the sample as complete support, accuracy, or distribution evidence.
