"""Fetch the exact validated checkpoint; never reads photos."""
import argparse
import hashlib
import json
from pathlib import Path
from huggingface_hub import snapshot_download

REPOSITORY = 'laion/CLIP-ViT-B-32-laion2B-s34B-b79K'
REVISION = '1a25a446712ba5ee05982a381eed697ef9b435cf'
CHECKSUMS = {
    'open_clip_config.json': '4302a891b495ad0966d1e7eeff102b5f34a3f1e647e57a9198933f862d5f8ba7',
    'open_clip_model.safetensors': 'ac4f8c4b88af6d963118cbf40ad93176d092abbedfcb752601ae1866352656e6',
}

def verify(path):
    for name, expected in CHECKSUMS.items():
        digest = hashlib.sha256()
        with (path / name).open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
        if digest.hexdigest() != expected:
            raise RuntimeError('Checksum mismatch: ' + name + '. Remove the damaged file and rerun setup.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--verify-only', action='store_true', help='Validate local assets without network access')
    args = parser.parse_args()
    path = args.output.expanduser().resolve()
    if not args.verify_only:
        snapshot_download(repo_id=REPOSITORY, revision=REVISION, local_dir=str(path),
                          allow_patterns=[*CHECKSUMS, 'README.md'])
    verify(path)
    (path / 'provenance.json').write_text(json.dumps({
        'repository': REPOSITORY, 'revision': REVISION, 'sha256': CHECKSUMS,
        'licenseListed': 'MIT',
        'decision': 'research prototype; model-card deployed-use guidance remains unresolved',
    }, indent=2) + '\n')
    print('Verified checkpoint at ' + str(path))

if __name__ == '__main__':
    main()
