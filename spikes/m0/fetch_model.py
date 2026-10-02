"""Download candidate weights only, recording immutable revision; never reads photos."""
import argparse
import json
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
repo = 'laion/CLIP-ViT-B-32-laion2B-s34B-b79K'
info = HfApi().model_info(repo)
if not info.sha:
    raise RuntimeError('Model revision missing')
path = Path(snapshot_download(repo_id=repo, revision=info.sha, local_dir=str(args.output),
    allow_patterns=['open_clip_config.json', 'open_clip_model.safetensors', 'README.md']))
for name in ['open_clip_config.json', 'open_clip_model.safetensors']:
    if not (path / name).exists():
        raise RuntimeError('Missing required model asset: ' + name)
(path / 'provenance.json').write_text(json.dumps({'repository': repo, 'revision': info.sha,
    'licenseListed': 'MIT', 'decision': 'evaluation candidate only; model-card deployment guidance is unresolved'}, indent=2) + '\n')
print('Candidate snapshot downloaded to external cache at revision ' + info.sha)
