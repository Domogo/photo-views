#!/usr/bin/env python3
"""Install the free local face runtime and pinned OpenCV Zoo weights; no photo upload."""
import hashlib, subprocess, sys, urllib.request
from pathlib import Path
REVISION = '47534e27c9851bb1128ccc0102f1145e27f23f98'
FILES = {
 'face_detection_yunet/face_detection_yunet_2023mar.onnx': '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
 'face_recognition_sface/face_recognition_sface_2021dec.onnx': '0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79',
}
root = Path.home()/'Library/Caches/PhotoViews/m0'
subprocess.run([str(root/'venv/bin/python'),'-m','pip','install','opencv-python-headless==4.11.0.86'],check=True)
folder=root/'people';folder.mkdir(exist_ok=True)
for file, expected in FILES.items():
 destination=folder/Path(file).name
 if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest()==expected: continue
 url=f'https://media.githubusercontent.com/media/opencv/opencv_zoo/{REVISION}/models/{file}'
 payload=urllib.request.urlopen(url,timeout=120).read()
 digest=hashlib.sha256(payload).hexdigest()
 if digest!=expected: raise RuntimeError(f'Unexpected model checksum for {file}: {digest}')
 temporary=destination.with_suffix('.download');temporary.write_bytes(payload);temporary.replace(destination)
for name in ['face_detection_yunet','face_recognition_sface']:
 (folder/(name+'-LICENSE')).write_bytes(urllib.request.urlopen(f'https://raw.githubusercontent.com/opencv/opencv_zoo/{REVISION}/models/{name}/LICENSE').read())
print(folder)
