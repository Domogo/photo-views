#!/usr/bin/env python3
"""Build a local developer .app with ad-hoc signing; no accounts, hosting, or paid services."""
import argparse
import plistlib
import shutil
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--release', action='store_true')
parser.add_argument('--open', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
configuration = 'release' if args.release else 'debug'
subprocess.run(['swift','build','-c',configuration],cwd=root,check=True)
binary_dir = Path(subprocess.check_output(['swift','build','-c',configuration,'--show-bin-path'],cwd=root,text=True).strip())
app = root / '.build' / 'app' / 'Still.app'
contents = app / 'Contents'
(contents / 'MacOS').mkdir(parents=True,exist_ok=True)
shutil.copy2(binary_dir / 'PhotoViews',contents / 'MacOS' / 'PhotoViews')
(contents / 'Resources').mkdir(exist_ok=True)
shutil.copy2(root / 'scripts/search/worker.py',contents / 'Resources/search_worker.py')
shutil.copy2(root / 'scripts/search/people.py',contents / 'Resources/people.py')
shutil.copy2(root / 'scripts/search/palette.py',contents / 'Resources/palette.py')
shutil.copy2(root / 'scripts/search/tag_vocabulary.json',contents / 'Resources/tag_vocabulary.json')
shutil.copy2(root / 'Resources/Brand/Still.icns',contents / 'Resources/Still.icns')
info = {'CFBundleName':'Still','CFBundleDisplayName':'Still',
        'CFBundleIdentifier':'com.domogo.photoviews','CFBundleExecutable':'PhotoViews',
        'CFBundleIconFile':'Still','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'1',
        'LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True}
(contents / 'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
print(app)
if args.open:
    subprocess.run(['open',str(app)],check=True)
