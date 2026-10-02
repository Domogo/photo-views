#!/usr/bin/env python3
"""Versioned stdin/stdout worker. Local derivatives, SQLite and offline model only."""
import argparse, json, math, os, sqlite3, sys, time
from pathlib import Path

PROTOCOL = 1
REVISION = '1a25a446712ba5ee05982a381eed697ef9b435cf'
MODEL_VERSION = 'openclip-vit-b32-' + REVISION + ':imageio-m2-v1:search-v1'
RANKING_VERSION = 'rrf-k60-v1'


def constraints(recipe):
    clauses, values = [], []
    sources = recipe.get('sourceIDs', [])
    if sources:
        clauses.append('a.source_id IN (' + ','.join('?' for _ in sources) + ')'); values.extend(sources)
    f = recipe.get('filters', {})
    for key in ('camera', 'lens', 'format'):
        if f.get(key):
            clauses.append("json_extract(CAST(m.payload AS TEXT), '$." + key + "')=?"); values.append(f[key])
    if f.get('folder'):
        clauses.append('instr(lower(folder_path(a.relative_path)),lower(?))>0'); values.append(f['folder'])
    # Filter calendar days from the camera's original wall clock, not the Mac timezone.
    day = "replace(substr(json_extract(CAST(m.payload AS TEXT),'$.captureDateText'),1,10),':','-')"
    for key, op in [('fromDay','>='), ('toDay','<=')]:
        if f.get(key): clauses.append(day + op + '?'); values.append(f[key])
    for key, op in [('minISO','>='), ('maxISO','<=')]:
        if f.get(key) is not None:
            clauses.append("json_extract(CAST(m.payload AS TEXT),'$.iso')"+op+'?'); values.append(f[key])
    for tag in f.get('confirmedTags', []):
        clauses.append("EXISTS(SELECT 1 FROM tag_assignments t WHERE t.asset_id=a.id AND t.tag=? AND (t.provenance='manual' OR t.decision='accepted'))"); values.append(tag)
    return clauses, values


def reciprocal_rank_fusion(visual, lexical, k=60):
    scores = {}
    for ranking in (visual, lexical):
        for rank, asset in enumerate(ranking, 1): scores[asset] = scores.get(asset,0) + 1/(k+rank)
    return sorted(scores,key=lambda asset:(-scores[asset],asset))


class Worker:
    def __init__(self, catalog, model):
        self.db = sqlite3.connect(catalog, timeout=5)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.create_function('folder_path',1,lambda p: str(Path(p).parent) if str(Path(p).parent) != '.' else '')
        self.model_dir = Path(model)
        self.model = None
        self.version = MODEL_VERSION

    def load_model(self):
        if self.model is not None: return
        os.environ['HF_HUB_OFFLINE'] = '1'; os.environ['TRANSFORMERS_OFFLINE'] = '1'
        import numpy as np
        import torch, open_clip
        from importlib.metadata import version
        if version('open-clip-torch') != '3.3.0' or version('torch') != '2.14.1':
            raise ValueError('Search runtime differs from the validated M0 packages. Restore the pinned local environment.')
        provenance = json.loads((self.model_dir/'provenance.json').read_text())
        if provenance['revision'] != REVISION: raise ValueError('The model snapshot differs from the validated local checkpoint.')
        config = json.loads((self.model_dir/'open_clip_config.json').read_text())
        self.device = 'mps' if torch.backends.mps.is_available() else 'cpu'
        model, _, self.preprocess = open_clip.create_model_and_transforms('ViT-B-32', pretrained=str(self.model_dir/'open_clip_model.safetensors'), image_mean=config['preprocess_cfg']['mean'],image_std=config['preprocess_cfg']['std'])
        self.tokenizer = open_clip.get_tokenizer('ViT-B-32')
        self.model = model.to(self.device).eval(); self.torch = torch; self.np = np

    def coverage(self, recipe):
        clauses, args = constraints(recipe)
        where = ' WHERE ' + ' AND '.join(clauses) if clauses else ''
        row = self.db.execute('SELECT count(*),sum(CASE WHEN e.asset_id IS NOT NULL THEN 1 ELSE 0 END) FROM assets a LEFT JOIN metadata m ON m.asset_id=a.id LEFT JOIN embeddings e ON e.asset_id=a.id AND e.model_version=?'+where,[self.version]+args).fetchone()
        failed_sql = " FROM assets a LEFT JOIN metadata m ON m.asset_id=a.id JOIN index_jobs ij ON ij.asset_id=a.id WHERE ij.stage='embedding' AND ij.pipeline_version=? AND ij.state='failed'" + (' AND '+ ' AND '.join(clauses) if clauses else '')
        failed = self.db.execute('SELECT count(*)'+failed_sql,[self.version]+args).fetchone()[0]
        failures = [{'assetID':r['id'],'filename':Path(r['relative_path']).name,'error':r['error']} for r in self.db.execute('SELECT a.id,a.relative_path,ij.error'+failed_sql+' ORDER BY a.id LIMIT 3',[self.version]+args)]
        return {'total':row[0], 'embedded':row[1] or 0, 'failed':failed,'failures':failures}

    def index_batch(self, request):
        from PIL import Image
        self.load_model()
        # Never regenerate an unchanged completed vector; skip individual recorded failures until retry.
        recipe = {'sourceIDs':request.get('sourceIDs',[])}
        clauses, args = constraints(recipe)
        clauses += ["j.state='complete'", 'e.asset_id IS NULL', "COALESCE(ij.state,'pending')!='failed'", '(d.analysis_path IS NOT NULL OR d.thumbnail_path IS NOT NULL)']
        rows = self.db.execute("""SELECT a.id,a.source_id,a.modified_at,a.byte_size,d.analysis_path,d.thumbnail_path,d.pipeline_version
            FROM assets a JOIN derivatives d ON d.asset_id=a.id LEFT JOIN metadata m ON m.asset_id=a.id
            JOIN index_jobs j ON j.asset_id=a.id AND j.stage='preview' AND j.pipeline_version=d.pipeline_version
            LEFT JOIN embeddings e ON e.asset_id=a.id AND e.model_version=?
            LEFT JOIN index_jobs ij ON ij.asset_id=a.id AND ij.stage='embedding' AND ij.pipeline_version=?
            WHERE """+' AND '.join(clauses)+' ORDER BY a.id LIMIT ?', [self.version,self.version]+args+[min(32,max(1,request.get('limit',16)))]).fetchall()
        done = failed = 0
        for row in rows:
            try:
                path = next((Path(p) for p in (row['analysis_path'],row['thumbnail_path']) if p and Path(p).is_file()),None)
                if path is None: raise ValueError('Cached preview is unavailable. Rebuild the preview before retrying visual indexing.')
                with Image.open(path) as image: batch = self.preprocess(image.convert('RGB')).unsqueeze(0).to(self.device)
                with self.torch.inference_mode(): vector = self.model.encode_image(batch,normalize=True).cpu().numpy().astype('<f4')[0]
                if vector.shape != (512,) or not self.np.isfinite(vector).all(): raise ValueError('Invalid image embedding')
                # Reindexing can invalidate an input while inference runs; commit only its current generation.
                with self.db:
                    current = self.db.execute('SELECT a.modified_at,a.byte_size,d.pipeline_version FROM assets a JOIN derivatives d ON d.asset_id=a.id WHERE a.id=?',[row['id']]).fetchone()
                    if current is None or current['modified_at'] != row['modified_at'] or current['byte_size'] != row['byte_size'] or current['pipeline_version'] != row['pipeline_version']: continue
                    self.db.execute('INSERT OR REPLACE INTO embeddings VALUES(?,?,?,?)',[row['id'],self.version,512,vector.tobytes()])
                    self.job(row,'complete',None)
                done += 1
            except Exception as error:
                with self.db: self.job(row,'failed',str(error))
                failed += 1
        return {'processed':len(rows),'completed':done,'failedBatch':failed,**self.coverage(recipe)}

    def job(self, row, state, error):
        self.db.execute("""INSERT INTO index_jobs(id,source_id,asset_id,stage,state,error,pipeline_version,updated_at)
            VALUES(?,?,?,'embedding',?,?,?,?) ON CONFLICT(asset_id,stage,pipeline_version)
            DO UPDATE SET state=excluded.state,error=excluded.error,updated_at=excluded.updated_at""",
            [row['id']+':'+self.version,row['source_id'],row['id'],state,error,self.version,time.time()])

    def query(self, request):
        recipe = request.get('recipe', {})
        clauses, args = constraints(recipe)
        clauses.append("j.state IN ('complete','failed')")
        rows = self.db.execute("""SELECT a.id,a.source_id,a.relative_path,a.file_id,a.byte_size,a.modified_at,a.available,
          m.payload,m.capture_date,d.thumbnail_path,d.analysis_path,d.pipeline_version,d.preview_source,j.state,j.error,
          e.vector FROM assets a LEFT JOIN metadata m ON m.asset_id=a.id LEFT JOIN derivatives d ON d.asset_id=a.id
          LEFT JOIN index_jobs j ON j.asset_id=a.id AND j.stage='preview' AND j.pipeline_version='imageio-m2-v1'
          LEFT JOIN embeddings e ON e.asset_id=a.id AND e.model_version=? WHERE """ + ' AND '.join(clauses),[self.version]+args).fetchall()
        text = recipe.get('search','').strip(); mode = request.get('mode','visual'); reference = recipe.get('referenceAssetID')
        if (reference or (text and mode != 'filename')) and (
            recipe.get('modelVersion') not in (None, self.version) or recipe.get('rankingVersion') not in (None, RANKING_VERSION)):
            raise ValueError('This view uses a different search model or ranking version. Use the current search model explicitly, then update the saved view if you want to keep the change.')
        by_id = {r['id']:r for r in rows}
        def lexical():
            matched = []
            for row in rows:
                name = row['relative_path'].casefold()
                if text.casefold() in name: matched.append((0 if Path(name).name == text.casefold() else 1,len(name),row['id']))
            # Existing imported/manual/accepted keywords are searchable; suggested labels are not confirmed.
            if text:
                tag_ids = {r[0] for r in self.db.execute("SELECT asset_id FROM tag_assignments WHERE instr(lower(tag),lower(?))>0 AND (provenance IN ('imported','manual') OR decision='accepted')",[text])}
                matched += [(2,0,id) for id in tag_ids if id in by_id and not any(v[2]==id for v in matched)]
            return [r[2] for r in sorted(matched)]
        searching = bool(text or reference)
        if reference or (text and mode != 'filename'):
            self.load_model()
            candidates = []
            vectors = []
            for row in rows:
                if row['vector'] is None or row['id']==reference: continue
                v = self.np.frombuffer(row['vector'],dtype='<f4')
                if v.shape==(512,) and self.np.isfinite(v).all(): candidates.append(row['id']); vectors.append(v)
            if reference:
                ref = self.db.execute('SELECT vector FROM embeddings WHERE asset_id=? AND model_version=?',[reference,self.version]).fetchone()
                if ref is None: raise ValueError('This photo is not visually indexed yet. Finish visual indexing or choose another photo.')
                query = self.np.frombuffer(ref[0],dtype='<f4')
            else:
                with self.torch.inference_mode(): query = self.model.encode_text(self.tokenizer([text]).to(self.device),normalize=True).cpu().numpy()[0]
            if vectors:
                scores = self.np.stack(vectors) @ query
                visual = [candidates[i] for i in sorted(range(len(candidates)),key=lambda i:(-float(scores[i]),candidates[i]))]
            else: visual = []
            ranked = visual if reference else reciprocal_rank_fusion(visual,lexical())
        elif text: ranked = lexical()
        else:
            sort = recipe.get('sorting','captureNewest')
            if sort=='filename': ranked = sorted(by_id,key=lambda id:(by_id[id]['relative_path'].casefold(),id))
            else: ranked = sorted(by_id,key=lambda id:((by_id[id]['capture_date'] or by_id[id]['modified_at'] or 0),id),reverse=sort!='captureOldest')
        # Semantic searches return nearest neighbors, not guaranteed matches. No probability claims.
        total = len(ranked)
        limit = min(10000,max(1,request.get('limit',500)))
        eligible = set(ranked[:100] if searching and mode!='filename' else ranked)
        ranked = ranked[:min(limit,100) if searching and mode!='filename' else limit]
        def asset_payload(id):
            row=by_id[id]; metadata=json.loads(row['payload']) if row['payload'] else None
            return {'asset':{'id':id,'sourceID':row['source_id'],'relativePath':row['relative_path'],'fileID':row['file_id'],'byteSize':row['byte_size'],'modifiedAt':row['modified_at']-978307200 if row['modified_at'] is not None else None},'available':bool(row['available']), 'metadata':metadata,'thumbnailPath':row['thumbnail_path'],'analysisPath':row['analysis_path'],'pipelineVersion':row['pipeline_version'],'previewSource':row['preview_source'],'previewState':row['state'],'error':row['error']}
        assets = [asset_payload(id) for id in ranked]
        selected = request.get('selectedAssetID')
        selected_asset = asset_payload(selected) if selected in eligible else None
        source_clauses, source_args = constraints({'sourceIDs':recipe.get('sourceIDs',[])})
        where=' WHERE '+' AND '.join(source_clauses) if source_clauses else ''
        cameras = [r[0] for r in self.db.execute("SELECT DISTINCT json_extract(CAST(m.payload AS TEXT),'$.camera') FROM assets a JOIN metadata m ON m.asset_id=a.id"+where+(' AND ' if where else ' WHERE ')+"json_extract(CAST(m.payload AS TEXT),'$.camera') IS NOT NULL ORDER BY 1",source_args)]
        return {'assets':assets,'selectedAsset':selected_asset,'resultCount':min(total,100) if searching and mode!='filename' else total,'candidateCount':total,'cameras':cameras, 'coverage':self.coverage(recipe),'modelVersion':self.version,'rankingVersion':RANKING_VERSION}

    def handle(self, request):
        if request.get('protocol') != PROTOCOL: raise ValueError('Unsupported worker protocol')
        op=request.get('op')
        if op=='query': return self.query(request)
        if op=='index': return self.index_batch(request)
        if op=='retry':
            with self.db: self.db.execute("DELETE FROM index_jobs WHERE stage='embedding' AND pipeline_version=? AND state='failed'",[self.version])
            return self.coverage({})
        if op=='status': return self.coverage(request.get('recipe',{}))
        raise ValueError('Unknown worker operation')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--catalog',required=True);parser.add_argument('--model',required=True)
    args=parser.parse_args();worker=Worker(args.catalog,args.model)
    for line in sys.stdin:
        try:
            request=json.loads(line);result=worker.handle(request)
            response={'protocol':PROTOCOL,'id':request.get('id'),'ok':True,'result':result}
        except Exception as error: response={'protocol':PROTOCOL,'id':locals().get('request',{}).get('id'),'ok':False,'error':str(error)}
        print(json.dumps(response,allow_nan=False),flush=True)

if __name__=='__main__': main()
