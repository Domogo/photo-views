#!/usr/bin/env python3
"""Local OpenCLIP spike over probe derivatives; no image/query uploads."""
import argparse
import json
import math
import time
from pathlib import Path

def evaluate(ranking, relevant, k=10):
    top = ranking[:k]
    gains = [int(asset in relevant) for asset in top]
    dcg = sum(gain / math.log2(i + 2) for i, gain in enumerate(gains))
    ideal = sum(1 / math.log2(i + 2) for i in range(min(len(relevant), k)))
    return {'hitAt10': any(gains), 'precisionAt10': sum(gains) / k,
            'ndcgAt10': dcg / ideal if ideal else None}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', type=Path, required=True)
    parser.add_argument('--queries', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--model', type=Path, required=True,
                        help='External model directory containing open_clip_config.json and open_clip_model.safetensors')
    parser.add_argument('--device', choices=['cpu', 'mps'], default='cpu')
    args = parser.parse_args()
    import numpy as np
    import torch
    import open_clip
    from PIL import Image
    from importlib.metadata import version
    if args.output.exists():
        parser.error('Use a fresh output directory to preserve evidence')
    model_dir = args.model.resolve()
    config = json.loads((model_dir / 'open_clip_config.json').read_text())
    records = json.loads((args.probe / 'manifest.json').read_text())
    ready = [r for r in records if r.get('status') == 'preview-ready' and r.get('derivative')]
    ids = [r['id'] for r in ready]
    queries = json.loads(args.queries.read_text())
    if not ready or not queries:
        parser.error('Need decoded images and labeled queries')
    if len(set(ids)) != len(ids):
        parser.error('Duplicate asset ids')
    for query in queries:
        if not query.get('relevant') or not set(query['relevant']).issubset(ids):
            parser.error('Each evaluated query needs existing relevant asset IDs')
        if ('text' in query) == ('asset' in query):
            parser.error('Query must contain exactly one of text or asset')
        if 'asset' in query and (query['asset'] not in ids or query['asset'] in query['relevant']):
            parser.error('Similarity reference must exist and be excluded from relevant IDs')
    args.output.mkdir(parents=True)
    # Fixed architecture; weights and preprocessing are read from the pinned local snapshot.
    started = time.perf_counter()
    model, _, preprocess = open_clip.create_model_and_transforms(
        'ViT-B-32', pretrained=str(model_dir / 'open_clip_model.safetensors'),
        **{'image_mean': config['preprocess_cfg']['mean'],
           'image_std': config['preprocess_cfg']['std']})
    tokenizer = open_clip.get_tokenizer('ViT-B-32')
    model = model.to(args.device).eval()
    def sync():
        if args.device == 'mps':
            torch.mps.synchronize()
    sync()
    load_seconds = time.perf_counter() - started
    vectors = []
    start = time.perf_counter()
    with torch.inference_mode():
        for record in ready:
            with Image.open(args.probe / record['derivative']) as image:
                batch = preprocess(image.convert('RGB')).unsqueeze(0).to(args.device)
            vectors.append(model.encode_image(batch, normalize=True).cpu())
        image_vectors = torch.cat(vectors).to(args.device)
        sync()
        indexing_seconds = time.perf_counter() - start
        outputs = []
        for query in queries:
            start = time.perf_counter()
            if 'text' in query:
                vector = model.encode_text(tokenizer([query['text']]).to(args.device), normalize=True)
            else:
                vector = image_vectors[ids.index(query['asset'])].unsqueeze(0)
            scores = (vector @ image_vectors.T).squeeze(0).cpu().tolist()
            order = sorted(range(len(ids)), key=lambda i: (-scores[i], ids[i]))
            ranking = [ids[i] for i in order if ids[i] != query.get('asset')]
            sync()
            seconds = time.perf_counter() - start
            outputs.append({'queryId': query['id'], 'ranking': ranking[:10],
                            'elapsedSeconds': seconds, **evaluate(ranking, set(query['relevant']))})
    np.save(args.output / 'embeddings.npy', image_vectors.cpu().numpy())
    (args.output / 'rankings.json').write_text(json.dumps(outputs, indent=2) + '\n')
    report = {'model': json.loads((model_dir / 'provenance.json').read_text()),
              'openClipVersion': version('open-clip-torch'), 'torchVersion': torch.__version__,
              'device': args.device, 'assetIds': ids, 'decodedAssets': len(ids),
              'excludedProbeFailures': len(records) - len(ready),
              'queryCount': len(outputs), 'modelLoadSeconds': load_seconds,
              'indexingSeconds': indexing_seconds,
              'hitAt10Rate': sum(r['hitAt10'] for r in outputs) / len(outputs),
              'meanPrecisionAt10': sum(r['precisionAt10'] for r in outputs) / len(outputs),
              'meanNdcgAt10': sum(r['ndcgAt10'] for r in outputs) / len(outputs),
              'queryP95Seconds': float(np.percentile([r['elapsedSeconds'] for r in outputs], 95)),
              'limitations': ['Small-spike metrics, not product targets or held-out benchmark claims.',
                              'Latency includes first query; cold/warm trials need separate repeated runs.',
                              'Human labels must be complete for precision/nDCG to be meaningful.',
                              'ImageIO color normalization remains to be validated on real camera fixtures.']}
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['decodedAssets', 'queryCount', 'device', 'modelLoadSeconds', 'indexingSeconds', 'hitAt10Rate', 'queryP95Seconds']}, indent=2))

if __name__ == '__main__':
    main()
