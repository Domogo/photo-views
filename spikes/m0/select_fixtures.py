"""Select a spread of actual images per extension; save paths only to an external file."""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from probe import EXTENSIONS

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fixtures', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--per-extension', type=int, default=20)
args = parser.parse_args()
root = args.fixtures.resolve()
output = args.output.resolve()
if not root.is_dir() or args.per_extension < 1:
    parser.error('Need an existing fixture root and a positive sample size')
if output == root or root in output.parents:
    parser.error('Selection evidence must stay outside the original fixture tree')
if output.exists():
    parser.error('Use a fresh output file')
groups = defaultdict(list)
sidecars = 0
for path in root.rglob('*'):
    if path.is_symlink() or not path.is_file() or root not in path.resolve().parents:
        continue
    if path.name.startswith('._'):
        sidecars += 1
        continue
    if path.suffix.lower() in EXTENSIONS:
        groups[path.suffix.lower()].append(path)
selected = []
for extension, paths in sorted(groups.items()):
    paths.sort()
    if args.per_extension == 1:
        indices = {0}
    else:
        indices = {round((len(paths) - 1) * i / (args.per_extension - 1)) for i in range(args.per_extension)}
    selected.extend(str(paths[i]) for i in sorted(indices))
if not selected:
    parser.error('No candidate images found')
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(selected, indent=2) + '\n')
print(json.dumps({'imageCounts': {key: len(value) for key, value in groups.items()},
                  'selectedCount': len(selected), 'ignoredAppleDoubleFiles': sidecars}, indent=2))
