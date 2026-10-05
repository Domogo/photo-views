#!/usr/bin/env python3
"""Check navigation-cache boundaries locally, with no app launch or archive access."""
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
subprocess.run(['swift', 'build', '-c', 'release', '--target', 'PhotoViewsCore'], cwd=root, check=True)
bin_dir = Path(subprocess.check_output(['swift', 'build', '-c', 'release', '--show-bin-path'], cwd=root, text=True).strip())
with tempfile.TemporaryDirectory(prefix='still-workspace-checks-') as temporary:
    executable = Path(temporary) / 'WorkspaceCacheChecks'
    sources = [root / 'Sources/PhotoViewsApp/BrowseSnapshots.swift', root / 'Sources/PhotoViewsApp/SearchBridge.swift', root / 'Tests/WorkspaceCacheChecks/main.swift']
    objects = sorted((bin_dir / 'PhotoViewsCore.build').glob('*.swift.o'))
    subprocess.run(['swiftc', '-I', str(bin_dir / 'Modules'), '-I', str(root / 'Sources/CSQLite'), *map(str, sources), *map(str, objects), '-lsqlite3', '-o', str(executable)], cwd=root, check=True)
    subprocess.run([str(executable)], cwd=root, check=True)

    navigation = Path(temporary) / 'WorkspaceNavigationChecks'
    app_sources = sorted(path for path in (root / 'Sources/PhotoViewsApp').glob('*.swift') if path.name != 'PhotoViewsApp.swift')
    subprocess.run(['swiftc', '-swift-version', '5', '-I', str(bin_dir / 'Modules'), '-I', str(root / 'Sources/CSQLite'), *map(str, app_sources), str(root / 'Tests/WorkspaceNavigationChecks/main.swift'), *map(str, objects), '-lsqlite3', '-o', str(navigation)], cwd=root, check=True)
    environment = os.environ.copy()
    environment['PHOTO_VIEWS_DATA_DIR'] = str(Path(temporary) / 'catalog')
    environment['PHOTO_VIEWS_PYTHON'] = str(Path(temporary) / 'no-worker')
    subprocess.run([str(navigation)], cwd=root, env=environment, check=True)
