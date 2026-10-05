#!/usr/bin/env python3
"""Install pinned local face models and retain their upstream licenses; no photo upload."""
import argparse
import hashlib
import subprocess
import urllib.request
from pathlib import Path
REVISION = '47534e27c9851bb1128ccc0102f1145e27f23f98'
FILES = {
 'face_detection_yunet/face_detection_yunet_2023mar.onnx': '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
 'face_recognition_sface/face_recognition_sface_2021dec.onnx': '0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79',
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.home()/'Library/Caches/PhotoViews/m0')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    python = root/'venv/bin/python'
    if not args.verify_only:
        subprocess.run([str(python),'-m','pip','install','opencv-python-headless==4.11.0.86'],check=True)
    subprocess.run([str(python),'-c',"import cv2; import importlib.metadata as m; assert m.version('opencv-python-headless') == '4.11.0.86'"],check=True)
    folder=root/'people'
    if not args.verify_only:
        folder.mkdir(parents=True,exist_ok=True)
    for file, expected in FILES.items():
        destination=folder/Path(file).name
        if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest()==expected:
            continue
        if args.verify_only:
            raise RuntimeError('Missing or damaged face model: '+str(destination))
        url=f'https://media.githubusercontent.com/media/opencv/opencv_zoo/{REVISION}/models/{file}'
        payload=urllib.request.urlopen(url,timeout=120).read()
        if hashlib.sha256(payload).hexdigest()!=expected:
            raise RuntimeError('Unexpected model checksum: '+file)
        temporary=destination.with_suffix('.download')
        temporary.write_bytes(payload)
        temporary.replace(destination)
    for name in ['face_detection_yunet','face_recognition_sface']:
        license_path=folder/(name+'-LICENSE')
        if args.verify_only:
            if not license_path.is_file():
                raise RuntimeError('Missing upstream license: '+str(license_path))
        else:
            license_path.write_bytes(urllib.request.urlopen(f'https://raw.githubusercontent.com/opencv/opencv_zoo/{REVISION}/models/{name}/LICENSE',timeout=120).read())
    print('Verified People models at '+str(folder))

if __name__ == '__main__':
    main()
