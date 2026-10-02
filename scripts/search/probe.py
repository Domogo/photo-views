#!/usr/bin/env python3
"""Offline real-fixture retrieval probe; uses existing M0 derivatives, not originals."""
import argparse,json,sqlite3,time,uuid
from pathlib import Path
from worker import Worker,MODEL_VERSION,reciprocal_rank_fusion

def main():
    p=argparse.ArgumentParser();p.add_argument('--probe',type=Path,required=True);p.add_argument('--queries',type=Path,required=True);p.add_argument('--model',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=False);db=sqlite3.connect(a.output/'catalog.sqlite')
    db.executescript('''CREATE TABLE assets(id TEXT PRIMARY KEY,source_id TEXT,relative_path TEXT,file_id TEXT,byte_size INTEGER,modified_at REAL,available INTEGER);
    CREATE TABLE metadata(asset_id TEXT,payload BLOB,capture_date REAL);
    CREATE TABLE derivatives(asset_id TEXT,thumbnail_path TEXT,analysis_path TEXT,pipeline_version TEXT,preview_source TEXT);
    CREATE TABLE index_jobs(id TEXT,source_id TEXT,asset_id TEXT,stage TEXT,state TEXT,error TEXT,pipeline_version TEXT,updated_at REAL,UNIQUE(asset_id,stage,pipeline_version));
    CREATE TABLE embeddings(asset_id TEXT,model_version TEXT,dimensions INTEGER,vector BLOB,PRIMARY KEY(asset_id,model_version));
    CREATE TABLE tag_assignments(asset_id TEXT,tag TEXT,provenance TEXT,decision TEXT);''')
    records=json.loads((a.probe/'manifest.json').read_text());ids={r['id']:str(uuid.uuid5(uuid.NAMESPACE_URL,r['id'])).upper() for r in records}
    source=str(uuid.uuid4()).upper()
    for r in records:
        if r['status']!='preview-ready':continue
        id=ids[r['id']];meta=r['metadata'];exif=meta.get('{Exif}',{});camera=meta.get('{TIFF}',{}).get('Model')
        payload={'camera':camera,'captureDateText':exif.get('DateTimeOriginal'),'format':r['extension'].upper()}
        db.execute('INSERT INTO assets VALUES(?,?,?,?,?,?,?)',[id,source,r['relativePath'],None,1,1,0])
        db.execute('INSERT INTO metadata VALUES(?,?,?)',[id,json.dumps(payload).encode(),1])
        path=str((a.probe/r['derivative']).resolve())
        db.execute('INSERT INTO derivatives VALUES(?,?,?,?,?)',[id,path,path,'imageio-m2-v1',r['previewSource']])
        db.execute('INSERT INTO index_jobs VALUES(?,?,?,?,?,?,?,?)',[id,source,id,'preview','complete',None,'imageio-m2-v1',1])
    db.commit();db.close();w=Worker(a.output/'catalog.sqlite',a.model);start=time.perf_counter()
    while True:
        batch=w.handle({'protocol':1,'op':'index','limit':16})
        if batch['processed']==0:break
    indexing=time.perf_counter()-start
    outputs=[]
    for q in json.loads(a.queries.read_text()):
        recipe={'search':q.get('text','')}
        if 'asset' in q:recipe['referenceAssetID']=ids[q['asset']]
        start=time.perf_counter();result=w.handle({'protocol':1,'op':'query','recipe':recipe,'mode':'visual','limit':10});latency=time.perf_counter()-start
        ranked=[r['asset']['id'] for r in result['assets'][:10]];relevant={ids[id] for id in q['relevant']}
        outputs.append({'queryId':q['id'],'seconds':latency,'hitAt10':bool(set(ranked)&relevant),'ranking':ranked})
    before=w.db.execute('SELECT asset_id,hex(vector) FROM embeddings ORDER BY asset_id').fetchall();w.db.close()
    resumed=Worker(a.output/'catalog.sqlite',a.model)
    # An index request after relaunch must not rewrite completed vectors.
    resumed_batch=resumed.handle({'protocol':1,'op':'index','limit':16})
    after=resumed.db.execute('SELECT asset_id,hex(vector) FROM embeddings ORDER BY asset_id').fetchall()
    import numpy as np
    vectors=[np.frombuffer(r[0],dtype='<f4') for r in resumed.db.execute('SELECT vector FROM embeddings')]
    assert resumed_batch['processed']==0 and [tuple(r) for r in before]==[tuple(r) for r in after]
    assert all(v.shape==(512,) and np.isfinite(v).all() and abs(np.linalg.norm(v)-1)<.002 for v in vectors)
    # Every returned candidate must meet hard filters, even after top-k reduction.
    camera=records[0]['metadata']['{TIFF}']['Model']
    filtered=resumed.handle({'protocol':1,'op':'query','recipe':{'search':'a photo','filters':{'camera':camera}},'mode':'visual','limit':10})
    assert all(r['metadata']['camera']==camera for r in filtered['assets'])
    report={'modelVersion':MODEL_VERSION,'fixtures':len(vectors),'formats':{ext:sum(r['extension']==ext for r in records) for ext in sorted({r['extension'] for r in records})},'indexingIncludingModelLoadSeconds':indexing,'queries':len(outputs),'exploratoryHitAt10':sum(o['hitAt10'] for o in outputs)/len(outputs),'queryP95Seconds':float(np.percentile([o['seconds'] for o in outputs],95)),'completedVectorsReusedAfterRelaunch':True,'normalized512D':True,'hardFiltersChecked':True,'cachedOfflineOriginalAvailability':False,'limitations':['M0 agent-authored labels reused; no human-held-out acceptance claim.','Originals never opened by this probe; existing M0 derivatives used.','Network-disabled environment flags used; OS network isolation not established.']}
    (a.output/'summary.json').write_text(json.dumps(report,indent=2));(a.output/'rankings.json').write_text(json.dumps(outputs,indent=2));print(json.dumps(report))
if __name__=='__main__':main()
