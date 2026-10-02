#!/usr/bin/env python3
"""Read an explicitly selected fixture directory; write all artifacts elsewhere."""
import argparse
import hashlib
import json
import platform
import subprocess
import tempfile
import time
from pathlib import Path

EXTENSIONS = {'.jpg', '.jpeg', '.png', '.heic', '.heif', '.nef', '.cr2', '.cr3', '.arw', '.raf', '.orf', '.rw2', '.dng'}

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def run(source, output, limit, selection=None):
    source, output = source.resolve(), output.resolve()
    if not source.is_dir():
        raise ValueError('Fixture directory does not exist')
    if output == source or source in output.parents or output in source.parents:
        raise ValueError('Output and fixture directories must be separate, non-nested trees')
    if output.exists():
        raise ValueError('Output must be a fresh run directory to preserve previous evidence')
    # Never follow symlinked files outside the authorized fixture tree.
    if selection is None:
        paths = sorted(p for p in source.rglob('*') if p.is_file() and not p.is_symlink() and not p.name.startswith('._')
                       and source in p.resolve().parents and p.suffix.lower() in EXTENSIONS)
    else:
        paths = [Path(p) for p in selection]
        if not all(p.is_file() and not p.is_symlink() and not p.name.startswith('._') and source in p.resolve().parents
                   and p.suffix.lower() in EXTENSIONS for p in paths):
            raise ValueError('Selected fixtures must be supported candidate files inside the authorized input tree')
        paths = sorted(set(p.resolve() for p in paths))
    if not paths:
        raise ValueError('No candidate image fixtures found')
    selected = paths[:limit]
    output.mkdir(parents=True)
    records = []
    start = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix='photo-views-m0-build-') as build:
        binary = Path(build) / 'image-probe'
        subprocess.run(['swiftc', str(Path(__file__).with_name('ImageProbe.swift')), '-o', str(binary)], check=True)
        for index, path in enumerate(selected):
            record = {'id': f'asset-{index:05d}', 'relativePath': str(path.relative_to(source)), 'extension': path.suffix.lower()}
            try:
                before = digest(path)
                derivative = output / (record['id'] + '.jpg')
                completed = subprocess.run([str(binary), str(path), str(derivative)], capture_output=True, text=True, timeout=120, check=True)
                record.update(json.loads(completed.stdout))
                record['sha256Before'] = before
                record['sha256After'] = digest(path)
                record['originalUnchanged'] = record['sha256Before'] == record['sha256After']
                if derivative.exists():
                    record['derivative'] = derivative.name
                    record['derivativeSha256'] = digest(derivative)
            except Exception as error:
                record.update(status='probe-error', error=str(error))
                if 'before' in locals():
                    record['sha256Before'] = before
                    try:
                        record['sha256After'] = digest(path)
                        record['originalUnchanged'] = before == record['sha256After']
                    except OSError:
                        record['originalUnchanged'] = False
            records.append(record)
            (output / 'manifest.json').write_text(json.dumps(records, indent=2) + '\n')
            print(f"{record['id']}: {record['status']}", flush=True)
            # Prevent carrying an earlier hash into another file's failure.
            if 'before' in locals():
                del before
    summary = {'pipelineVersion': 'imageio-m0-v2', 'platform': platform.platform(),
               'candidateCount': len(paths), 'probedCount': len(selected), 'truncated': len(paths) > limit,
               'readyCount': sum(r['status'] == 'preview-ready' for r in records),
               'failureCount': sum(r['status'] != 'preview-ready' for r in records),
               'originalIntegrityPassed': all(r.get('originalUnchanged') is True for r in records),
               'elapsedIncludingCompileSeconds': time.perf_counter() - start,
               'validation': 'Decoder smoke evidence only; inspect orientation/color/metadata against actual originals before accepting compatibility.'}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    return summary

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--limit', type=int, default=100)
    parser.add_argument('--selection', type=Path, help='Optional external JSON array of selected absolute fixture paths')
    args = parser.parse_args()
    if args.limit < 1:
        parser.error('--limit must be positive')
    selection = json.loads(args.selection.read_text()) if args.selection else None
    summary = run(args.fixtures, args.output, args.limit, selection)
    print(json.dumps(summary, indent=2))
    raise SystemExit(0 if summary['originalIntegrityPassed'] else 1)
