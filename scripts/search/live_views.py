#!/usr/bin/env python3
"""Native indexing + actual local embeddings + persisted recipe live-membership check.
Synthetic JPEG originals and all derivatives/reports remain in a fresh external output folder.
"""
import argparse, hashlib, json, sqlite3, subprocess, sys
from pathlib import Path
from worker import MODEL_VERSION

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--index-checks',required=True);p.add_argument('--output',required=True);p.add_argument('--model',required=True)
a=p.parse_args();root=Path(a.output).resolve()
if root.exists():raise SystemExit('Use a fresh external output folder.')
root.mkdir(parents=True)
subprocess.run([a.index_checks,'--live-view',str(root),'setup'],check=True)
catalog=root/'catalog.sqlite'
def recipes():
    with sqlite3.connect(catalog) as db:
        return {name:json.loads(recipe) for name,recipe in db.execute('SELECT name,recipe FROM saved_views')}
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def start():
    return subprocess.Popen([sys.executable,str(Path(__file__).with_name('worker.py')),'--catalog',str(catalog),'--model',a.model],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
def call(worker,op,**values):
    worker.stdin.write(json.dumps({'protocol':1,'id':'live-check','op':op,**values})+'\n');worker.stdin.flush()
    reply=json.loads(worker.stdout.readline())
    assert reply['ok'],reply
    return reply['result']
def stop(worker):
    worker.stdin.close();worker.wait(timeout=15);assert worker.returncode==0
saved=recipes();original=root/'Photos/matching-one.jpg';before=digest(original)
w=start()
first=call(w,'index',limit=16);assert first['completed']==1,first
filename=saved['Matching photos'];similar=saved['Similar fixture photos']
assert call(w,'query',mode='filename',recipe=filename)['resultCount']==1
assert call(w,'query',mode='visual',recipe=similar)['resultCount']==0
with sqlite3.connect(catalog) as db:vector_before=db.execute('SELECT vector FROM embeddings WHERE model_version=?',[MODEL_VERSION]).fetchone()[0]
subprocess.run([a.index_checks,'--live-view',str(root),'add'],check=True)
assert recipes()==saved # No saved-definition rewrite or recreation.
assert call(w,'query',mode='filename',recipe=filename)['resultCount']==2
assert call(w,'query',mode='visual',recipe=similar)['resultCount']==0 # Preview-ready isn't visually ready.
second=call(w,'index',limit=16);assert second['completed']==1,second
result=call(w,'query',mode='visual',recipe=similar);assert result['resultCount']==1,result
stop(w);w=start()
assert call(w,'query',mode='visual',recipe=recipes()['Similar fixture photos'])['resultCount']==1
stop(w)
assert digest(original)==before
with sqlite3.connect(catalog) as db:assert db.execute('SELECT vector FROM embeddings WHERE asset_id=? AND model_version=?',[similar['referenceAssetID'],MODEL_VERSION]).fetchone()[0]==vector_before
report={'syntheticNativeJPEGFixtures':2,'filenameMembershipBeforeAfter':[1,2],'similarityMembershipBeforeAfter':[0,1],'previewReadyNotVisuallyReady':True,'savedDefinitionsUnchanged':recipes()==saved,'reopenMembershipPreserved':True,'originalHashUnchanged':True,'firstVectorByteIdentical':True}
(root/'summary.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
