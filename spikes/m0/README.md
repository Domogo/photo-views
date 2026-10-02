# M0 feasibility spikes

## Native decoder probe

Requires macOS and Swift command-line tools; orchestration uses Python standard library.

```sh
python3 spikes/m0/probe.py --fixtures '/absolute/path/to/selected/photos' --output '/absolute/path/to/separate/fresh/run' --limit 100
```

Use separate non-nested input/output trees. Originals are read only. Each run records SHA-256 before/after, original ImageIO metadata, orientation, source type, thumbnail origin, color-space name, derivative dimensions, timing, and individual failures. Reports/derivatives may contain private metadata and remain outside Git. Exit status fails when original integrity cannot be established; decoding failures are recorded individually rather than stopping the run. Review summary failureCount as well as exit status.

The probe first requests an existing thumbnail; it generates one if absent or below the analysis-size threshold. ImageIO may recognize a corrupt RAW's type but fail decoding, which is reported as preview-failed. This is not a definitive classifier for unsupported versus corrupt RAW files. Existing thumbnail provenance is ImageIO-level and does not prove embedded RAW JPEG extraction. Pipeline v2 explicitly normalizes decoded previews to 8-bit sRGB. Systematic color fidelity validation and camera-specific fallback coverage remain open.

### Synthetic smoke check

With Pillow installed:

```sh
python3 spikes/m0/smoke.py
```

Checks orientation-6 JPEG output dimensions, PNG decoding, per-file corrupt-input reporting, original hashes, and output isolation. Synthetic checks make no RAW compatibility or semantic retrieval claim.

## Local retrieval candidate

Isolate Python dependencies in an external venv. The evaluated initial package versions are open-clip-torch 3.3.0 and torch 2.14.1; the resolved environment is recorded in requirements.lock (Python 3.12, Apple Silicon). Use pip install -r spikes/m0/requirements.lock to reproduce it.

```sh
python3 -m venv '/absolute/external/cache/venv'
'/absolute/external/cache/venv/bin/python' -m pip install 'open-clip-torch==3.3.0' 'torch==2.14.1'
'/absolute/external/cache/venv/bin/python' spikes/m0/fetch_model.py --output '/absolute/external/cache/model'
'/absolute/external/cache/venv/bin/python' spikes/m0/retrieval.py --model '/absolute/external/cache/model' --probe '/absolute/path/to/probe/run' --queries '/absolute/path/to/human-labels.json' --output '/absolute/path/to/fresh/retrieval/run' --device mps
```

The model fetch reads public model assets only and records the immutable checkpoint revision. Retrieval reads local derivatives and labels; it never sends images or queries to a provider. Weights, vectors, labels, and results stay outside Git. Run after downloads with networking disabled to verify the offline claim.

Copy queries.example.json outside Git and replace every placeholder with actual manifest IDs and human judgments. Include visual descriptions and separate query-by-example cases (exclude the reference itself). Use meaningful non-relevant candidates; top-10 success with fewer than ten images is not evidence of good ranking. Event/session-separated held-out evaluation remains necessary. This spike does not yet implement metadata filtering or text/visual fusion.

## Acceptance record

See ../../M0_STATUS.md. Real RAW fixtures, human labels, pipeline color validation, and decoder fallback decisions are required before M0 can pass.
