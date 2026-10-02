"""Synthetic plumbing tests; never camera-compatibility or retrieval evidence."""
import json
import tempfile
from pathlib import Path
from PIL import Image
from probe import run

with tempfile.TemporaryDirectory(prefix='photo-views-m0-smoke-') as root:
    root = Path(root)
    fixtures = root / 'fixtures'
    fixtures.mkdir()
    image = Image.new('RGB', (640, 320), '#d64030')
    exif = Image.Exif()
    exif[274] = 6
    image.save(fixtures / 'rotated.jpg', exif=exif)
    image.save(fixtures / 'plain.png')
    (fixtures / 'corrupt.nef').write_bytes(b'Not a RAW file')
    summary = run(fixtures, root / 'results', 100)
    records = json.loads((root / 'results' / 'manifest.json').read_text())
    indexed = {r['relativePath']: r for r in records}
    assert summary['probedCount'] == 3
    assert summary['originalIntegrityPassed']
    assert indexed['corrupt.nef']['status'] in {'unsupported-or-corrupt', 'preview-failed'}
    assert indexed['corrupt.nef'].get('error')
    assert indexed['plain.png']['status'] == 'preview-ready'
    assert indexed['rotated.jpg']['originalOrientation'] == 6
    assert (indexed['rotated.jpg']['previewWidth'], indexed['rotated.jpg']['previewHeight']) == (320, 640)
    try:
        run(fixtures, fixtures / 'nested-output', 100)
        raise AssertionError('Nested output must be refused')
    except ValueError:
        pass
    try:
        run(fixtures, root / 'results', 100)
        raise AssertionError('Existing output must be refused')
    except ValueError:
        pass
    print('PASS: PNG/JPEG previews, EXIF orientation transform, corrupt-file continuation, original hashes, and output isolation.')
