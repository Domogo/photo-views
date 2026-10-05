#!/usr/bin/env python3
"""Prepare external local inference dependencies. Downloads software/models only."""
import argparse
import platform
import shlex
import subprocess
import sys
import venv
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.home() / 'Library/Caches/PhotoViews/m0')
    parser.add_argument('--skip-people', action='store_true')
    parser.add_argument('--verify-only', action='store_true', help='Check existing runtime and models offline')
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        parser.error('The supported development target is Apple Silicon macOS.')
    if sys.version_info[:2] != (3, 12):
        parser.error('Run with Python 3.12: python3.12 scripts/setup.py')
    repo = Path(__file__).resolve().parents[1]
    root = args.root.expanduser().resolve()
    if root == repo or repo in root.parents:
        parser.error('--root must be outside the repository; weights and caches are local data.')
    python = root / 'venv/bin/python'
    model = root / 'model'
    def run(command):
        subprocess.run([str(x) for x in command], cwd=repo, check=True)
    try:
        if not args.verify_only:
            if not python.exists():
                venv.EnvBuilder(with_pip=True).create(root / 'venv')
            run([python, '-m', 'pip', 'install', '-r', repo / 'spikes/m0/requirements.lock'])
        run([python, '-m', 'pip', 'check'])
        run([python, '-c', "import importlib.metadata as m; assert m.version('torch') == '2.14.1'; assert m.version('open-clip-torch') == '3.3.0'"])
        run([python, repo / 'spikes/m0/fetch_model.py', '--output', model,
             *(['--verify-only'] if args.verify_only else [])])
        if not args.skip_people:
            run([python, repo / 'scripts/search/setup_people.py', '--root', root,
                 *(['--verify-only'] if args.verify_only else [])])
    except (OSError, subprocess.CalledProcessError) as error:
        print('Setup failed: ' + str(error) + '\nCompleted downloads remain cached. Fix the error and rerun.', file=sys.stderr)
        return 1
    print('Ready. For a custom root, launch the app executable with:')
    print('PHOTO_VIEWS_PYTHON=' + shlex.quote(str(python)) + ' PHOTO_VIEWS_MODEL=' + shlex.quote(str(model)) +
          ' ' + shlex.quote(str(repo / '.build/app/Still.app/Contents/MacOS/PhotoViews')))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
