#!/usr/bin/env python3
"""Versioned stdin/stdout worker. Local derivatives, SQLite and offline model only."""
import argparse, hashlib, json, math, os, sqlite3, sys, time, uuid
from datetime import datetime
from pathlib import Path
from palette import VERSION as PALETTE_VERSION, COLORS as PALETTE_COLORS, histogram

PROTOCOL = 1
REVISION = '1a25a446712ba5ee05982a381eed697ef9b435cf'
MODEL_VERSION = 'openclip-vit-b32-' + REVISION + ':imageio-m2-v1:search-v1'
RANKING_VERSION = 'rrf-k60-v1'


def constraints(recipe):
    clauses, values = [], []
    sources = recipe.get('sourceIDs', [])
    if sources:
        clauses.append('a.source_id IN (' + ','.join('?' for _ in sources) + ')'); values.extend(sources)
    if recipe.get('favoritesOnly'): clauses.append('a.favorite=1')
    if recipe.get('collectionID'):
        clauses.append('EXISTS(SELECT 1 FROM collection_assets ca WHERE ca.asset_id=a.id AND ca.collection_id=?)');values.append(recipe['collectionID'])
    f = recipe.get('filters', {})
    for key in ('camera', 'lens', 'format'):
        if f.get(key):
            clauses.append("json_extract(CAST(m.payload AS TEXT), '$." + key + "')=?"); values.append(f[key])
    if f.get('folder'):
        clauses.append('instr(lower(folder_path(a.relative_path)),lower(?))>0'); values.append(f['folder'])
    # Filter calendar days from the camera's original wall clock, not the Mac timezone.
    day = "capture_day(json_extract(CAST(m.payload AS TEXT),'$.captureDateText'))"
    for key, op in [('fromDay','>='), ('toDay','<=')]:
        if f.get(key): clauses.append(day + op + '?'); values.append(f[key])
    for field, keys in [('iso',('minISO','maxISO')),('aperture',('minAperture','maxAperture')),('shutterSeconds',('minShutterSeconds','maxShutterSeconds')),('width',('minWidth','maxWidth')),('height',('minHeight','maxHeight'))]:
        if f.get(keys[0]) is not None and f.get(keys[1]) is not None and isinstance(f[keys[0]],(int,float)) and isinstance(f[keys[1]],(int,float)) and f[keys[0]]>f[keys[1]]:raise ValueError(field+' minimum exceeds maximum. Edit its limits in Filters.')
        for key, op in zip(keys,('>=','<=')):
            if f.get(key) is not None:
                value=f[key]
                if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or value<=0:raise ValueError('Metadata limits must be finite positive numbers.')
                expression="json_extract(CAST(m.payload AS TEXT),'$."+field+"')"
                clauses.append("typeof("+expression+") IN ('integer','real') AND "+expression+op+'?');values.append(value)
    for tag in f.get('confirmedTags', []):
        clauses.append("EXISTS(SELECT 1 FROM tag_assignments t WHERE t.asset_id=a.id AND t.tag=? AND t.decision!='rejected' AND (t.provenance='manual' OR t.decision='accepted'))"); values.append(tag)
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
        def capture_day(value):
            try:return datetime.strptime(value[:10].replace(':','-'),'%Y-%m-%d').strftime('%Y-%m-%d')
            except (ValueError,TypeError):return None
        self.db.create_function('capture_day',1,capture_day)
        self.model_dir = Path(model)
        self.model = None
        self.version = MODEL_VERSION
        config_path=Path(__file__).with_name('tag_vocabulary.json')
        self.tag_config=json.loads(config_path.read_text())
        self.tag_version=self.tag_config['version']+':'+hashlib.sha256(config_path.read_bytes()).hexdigest()[:12]
        self.tag_vectors=None

    @staticmethod
    def palette_fingerprint(row):
        return json.dumps([row['modified_at'],row['byte_size'],row['pipeline_version']],separators=(',',':'))

    def palette_batch(self, limit=32, retry=False):
        if retry:
            with self.db: self.db.execute('DELETE FROM palettes WHERE payload IS NULL')
        rows=self.db.execute("""SELECT a.id,a.modified_at,a.byte_size,d.pipeline_version,d.thumbnail_path,d.analysis_path,
            p.version,p.fingerprint FROM assets a JOIN derivatives d ON d.asset_id=a.id
            LEFT JOIN palettes p ON p.asset_id=a.id ORDER BY a.id""").fetchall()
        pending=[r for r in rows if r['version']!=PALETTE_VERSION or r['fingerprint']!=self.palette_fingerprint(r)]
        processed=0
        for row in pending[:min(128,max(1,limit))]:
            fingerprint=self.palette_fingerprint(row); payload=None; error=None
            try:
                path=next((Path(p) for p in (row['analysis_path'],row['thumbnail_path']) if p and Path(p).is_file()),None)
                if path is None: raise ValueError('Cached preview missing. Rebuild the preview, then retry palette analysis.')
                payload=json.dumps(histogram(path),separators=(',',':'))
            except Exception as failure: error=str(failure)[:500]
            # A concurrent changed-file scan must not commit stale palette data.
            with self.db:
                current=self.db.execute('SELECT a.modified_at,a.byte_size,d.pipeline_version FROM assets a JOIN derivatives d ON d.asset_id=a.id WHERE a.id=?',[row['id']]).fetchone()
                if current is None or self.palette_fingerprint(current)!=fingerprint: continue
                self.db.execute('INSERT INTO palettes VALUES(?,?,?,?,?) ON CONFLICT(asset_id) DO UPDATE SET version=excluded.version,fingerprint=excluded.fingerprint,payload=excluded.payload,error=excluded.error',[row['id'],PALETTE_VERSION,fingerprint,payload,error])
            processed+=1
        return {'processed':processed,'remaining':max(0,len(pending)-processed)}

    def palette_coverage(self, recipe):
        clauses,args=constraints(recipe)
        rows=self.db.execute("""SELECT a.modified_at,a.byte_size,d.pipeline_version,p.version AS palette_version,
            p.fingerprint AS palette_fingerprint,p.payload AS palette_payload FROM assets a LEFT JOIN metadata m ON m.asset_id=a.id
            LEFT JOIN derivatives d ON d.asset_id=a.id LEFT JOIN palettes p ON p.asset_id=a.id"""+(' WHERE '+' AND '.join(clauses) if clauses else ''),args).fetchall()
        prepared=failed=0
        for row in rows:
            valid=row['palette_version']==PALETTE_VERSION and row['palette_fingerprint']==self.palette_fingerprint(row)
            if valid:
                if row['palette_payload'] is not None: prepared+=1
                else: failed+=1
        return {'total':len(rows),'prepared':prepared,'failed':failed}

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

    def tag_coverage(self, recipe):
        clauses,args=constraints(recipe)
        where=' WHERE '+' AND '.join(clauses) if clauses else ''
        count=self.db.execute('SELECT count(*),sum(CASE WHEN tr.asset_id IS NOT NULL THEN 1 ELSE 0 END) FROM assets a LEFT JOIN metadata m ON m.asset_id=a.id LEFT JOIN tag_runs tr ON tr.asset_id=a.id AND tr.vocabulary_version=? AND tr.model_version=?'+where,[self.tag_version,self.version]+args).fetchone()
        return {'total':count[0],'prepared':count[1] or 0}

    def tag_features(self):
        self.load_model()
        if self.tag_vectors is not None:return self.tag_vectors
        features=[]
        for item in self.tag_config['tags']:
            with self.torch.inference_mode(): v=self.model.encode_text(self.tokenizer(item['prompts']).to(self.device),normalize=True).cpu().numpy().mean(axis=0)
            features.append(v/self.np.linalg.norm(v))
        self.tag_vectors=self.np.stack(features);return self.tag_vectors

    def tag_batch(self, limit=128):
        rows=self.db.execute("""SELECT e.asset_id,e.vector,d.thumbnail_path,d.analysis_path FROM embeddings e LEFT JOIN derivatives d ON d.asset_id=e.asset_id LEFT JOIN tag_runs tr ON tr.asset_id=e.asset_id
            WHERE e.model_version=? AND (tr.asset_id IS NULL OR tr.vocabulary_version!=? OR tr.model_version!=?) ORDER BY e.asset_id LIMIT ?""",[self.version,self.tag_version,self.version,min(128,max(1,limit))]).fetchall()
        if not rows:return 0
        features=self.tag_features()
        for row in rows:
            vector=self.np.frombuffer(row['vector'],dtype='<f4')
            if vector.shape!=(512,) or not self.np.isfinite(vector).all():raise ValueError('Invalid cached vector for suggested tags.')
            # Uniform/absent cached previews cannot support inspectable visual suggestions.
            from PIL import Image
            path=next((Path(p) for p in (row['thumbnail_path'],row['analysis_path']) if p and Path(p).is_file()),None)
            usable=False
            if path:
                try:
                    with Image.open(path) as image: low,high=image.convert('L').getextrema();usable=high-low>=3
                except (OSError,ValueError):pass
            scores=features @ vector
            candidates=sorted([(item,float(scores[i])) for i,item in enumerate(self.tag_config['tags']) if usable and float(scores[i])>=item['threshold']],key=lambda v:(-v[1],v[0]['tag']))[:self.tag_config['maxSuggestions']]
            with self.db:
                current=self.db.execute('SELECT vector FROM embeddings WHERE asset_id=? AND model_version=?',[row['asset_id'],self.version]).fetchone()
                if current is None or current[0]!=row['vector']:continue
                self.db.execute("DELETE FROM tag_assignments WHERE asset_id=? AND provenance='suggested' AND decision='unconfirmed'",[row['asset_id']])
                for item,score in candidates:
                    # A user decision overrides every model/vocabulary revision, including rejected manual tags.
                    prior=self.db.execute('SELECT 1 FROM tag_assignments WHERE asset_id=? AND tag=? COLLATE NOCASE',[row['asset_id'],item['tag']]).fetchone()
                    if prior:continue
                    self.db.execute("INSERT INTO tag_assignments(id,asset_id,tag,provenance,decision,model_version,score,threshold,vocabulary_version) VALUES(?,?,?,'suggested','unconfirmed',?,?,?,?)",[str(uuid.uuid4()).upper(),row['asset_id'],item['tag'],self.version,score,item['threshold'],self.tag_version])
                self.db.execute('INSERT OR REPLACE INTO tag_runs VALUES(?,?,?,?)',[row['asset_id'],self.tag_version,self.version,hashlib.sha256(row['vector']).hexdigest()])
        return len(rows)

    def subjects(self, ids):
        vocabulary={v['tag'] for v in self.tag_config['tags']};result={}
        if not ids:return result
        # Read current catalog decisions once. No inference is involved in grouping.
        for row in self.db.execute("SELECT asset_id,tag,provenance,decision,model_version,score,threshold,vocabulary_version FROM tag_assignments WHERE decision!='rejected'"):
            if row['asset_id'] not in ids or row['tag'] not in vocabulary:continue
            confirmed=row['provenance']=='manual' or row['decision']=='accepted'
            suggested=row['provenance']=='suggested' and row['decision']=='unconfirmed' and row['model_version']==self.version and row['vocabulary_version']==self.tag_version and row['score'] is not None and row['threshold'] is not None and row['score']>=row['threshold']
            if confirmed or suggested:
                key=(0 if confirmed else 1,-(row['score'] or 0),row['tag'])
                if row['asset_id'] not in result or key<result[row['asset_id']][0]:result[row['asset_id']]=(key,row['tag'],not confirmed)
        return result

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
        tagged=self.tag_batch()
        return {'tagged':tagged,'processed':len(rows)+tagged,'completed':done,'failedBatch':failed,**self.coverage(recipe)}

    def job(self, row, state, error):
        self.db.execute("""INSERT INTO index_jobs(id,source_id,asset_id,stage,state,error,pipeline_version,updated_at)
            VALUES(?,?,?,'embedding',?,?,?,?) ON CONFLICT(asset_id,stage,pipeline_version)
            DO UPDATE SET state=excluded.state,error=excluded.error,updated_at=excluded.updated_at""",
            [row['id']+':'+self.version,row['source_id'],row['id'],state,error,self.version,time.time()])

    def query(self, request):
        recipe = request.get('recipe', {})
        clauses, args = constraints(recipe)
        clauses.append("j.state IN ('complete','failed')")
        rows = self.db.execute("""SELECT a.id,a.source_id,a.relative_path,a.file_id,a.byte_size,a.modified_at,a.available,a.favorite,
          m.payload,m.capture_date,d.thumbnail_path,d.analysis_path,d.pipeline_version,d.preview_source,j.state,j.error,
          e.vector,p.version AS palette_version,p.fingerprint AS palette_fingerprint,p.payload AS palette_payload FROM assets a LEFT JOIN palettes p ON p.asset_id=a.id LEFT JOIN metadata m ON m.asset_id=a.id LEFT JOIN derivatives d ON d.asset_id=a.id
          LEFT JOIN index_jobs j ON j.asset_id=a.id AND j.stage='preview' AND j.pipeline_version='imageio-m2-v1'
          LEFT JOIN embeddings e ON e.asset_id=a.id AND e.model_version=? WHERE """ + ' AND '.join(clauses),[self.version]+args).fetchall()
        palette = recipe.get('palette')
        if palette:
            if palette.get('version')!=PALETTE_VERSION: raise ValueError('This view uses a different palette version. Choose the color again and update the saved view explicitly.')
            fraction=palette.get('minimumFraction',.25)
            if palette.get('color') not in PALETTE_COLORS or isinstance(fraction,bool) or not isinstance(fraction,(float,int)) or not math.isfinite(fraction) or not 0 < fraction <= 1: raise ValueError('Choose a supported palette color and a coverage between 1% and 100%.')
        palette_coverage=self.palette_coverage(recipe)
        palette_scores={}
        if palette:
            for row in rows:
                if row['palette_version']!=PALETTE_VERSION or row['palette_fingerprint']!=self.palette_fingerprint(row) or row['palette_payload'] is None: continue
                areas=json.loads(row['palette_payload']); share=areas.get(palette['color'],0)
                if share>=fraction and share>=max(areas.values(),default=0): palette_scores[row['id']]=share
            rows=[row for row in rows if row['id'] in palette_scores]
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
            # Suggestions participate in keyword search, but never satisfy confirmed-tag constraints.
            if text:
                tag_ids = {r[0] for r in self.db.execute("SELECT asset_id FROM tag_assignments WHERE instr(lower(tag),lower(?))>0 AND decision!='rejected' AND (provenance IN ('imported','manual') OR decision='accepted' OR (provenance='suggested' AND decision='unconfirmed' AND model_version=? AND vocabulary_version=?))",[text,self.version,self.tag_version])}
                matched += [(2,0,id) for id in tag_ids if id in by_id and not any(v[2]==id for v in matched)]
            return [r[2] for r in sorted(matched)]
        searching = bool(text or reference or palette)
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
        if palette:
            palette_ranked=sorted((id for id in ranked if id in palette_scores),key=lambda id:(-palette_scores[id],id))
            ranked=reciprocal_rank_fusion(ranked,palette_ranked) if text or reference else palette_ranked
        # Semantic searches return nearest neighbors, not guaranteed matches. No probability claims.
        # Constraints apply to each asset before logical-photo collapsing. The first ranked matching
        # member represents the photo; no sibling can bypass exact filters or collection membership.
        associations = {r['asset_id']:r['photo_id'] for r in self.db.execute('SELECT asset_id,photo_id FROM photo_assets')}
        collapse = recipe.get('collapsePairs') is not False
        if collapse and reference in associations:
            ranked = [id for id in ranked if associations.get(id) != associations[reference]]
        matching = set(ranked)
        if collapse:
            seen = set(); collapsed = []
            for id in ranked:
                key = associations.get(id,id)
                if key not in seen: seen.add(key); collapsed.append(id)
            ranked = collapsed
        total = len(ranked)
        limit = min(10000,max(1,request.get('limit',500)))
        eligible = set(ranked[:100] if searching and mode!='filename' else ranked)
        ranked = ranked[:min(limit,100) if searching and mode!='filename' else limit]
        eligible_members = {id for id in matching if id in eligible or (collapse and associations.get(id) in {associations.get(r) for r in eligible if r in associations})}
        subjects=self.subjects(eligible_members)
        def asset_payload(id):
            row=by_id[id]; metadata=json.loads(row['payload']) if row['payload'] else None
            return {'photoID':associations.get(id),'pairedAssetIDs':[r[0] for r in self.db.execute('SELECT asset_id FROM photo_assets WHERE photo_id=? ORDER BY asset_id',[associations[id]])] if id in associations else None,'favorite':bool(row['favorite']),'primarySubject':subjects[id][1] if id in subjects else None,'primarySubjectSuggested':subjects[id][2] if id in subjects else False,'asset':{'id':id,'sourceID':row['source_id'],'relativePath':row['relative_path'],'fileID':row['file_id'],'byteSize':row['byte_size'],'modifiedAt':row['modified_at']-978307200 if row['modified_at'] is not None else None},'available':bool(row['available']), 'metadata':metadata,'thumbnailPath':row['thumbnail_path'],'analysisPath':row['analysis_path'],'pipelineVersion':row['pipeline_version'],'previewSource':row['preview_source'],'previewState':row['state'],'error':row['error']}
        assets = [asset_payload(id) for id in ranked]
        selected = request.get('selectedAssetID')
        selected_asset = asset_payload(selected) if selected in eligible_members else None
        source_clauses, source_args = constraints({'sourceIDs':recipe.get('sourceIDs',[])})
        where=' WHERE '+' AND '.join(source_clauses) if source_clauses else ''
        cameras = [r[0] for r in self.db.execute("SELECT DISTINCT json_extract(CAST(m.payload AS TEXT),'$.camera') FROM assets a JOIN metadata m ON m.asset_id=a.id"+where+(' AND ' if where else ' WHERE ')+"json_extract(CAST(m.payload AS TEXT),'$.camera') IS NOT NULL ORDER BY 1",source_args)]
        facets={}
        for field in ('lens','format'):
            facets[field]=[r[0] for r in self.db.execute("SELECT DISTINCT json_extract(CAST(m.payload AS TEXT),'$."+field+"') FROM assets a JOIN metadata m ON m.asset_id=a.id"+where+(' AND ' if where else ' WHERE ')+"json_extract(CAST(m.payload AS TEXT),'$."+field+"') IS NOT NULL ORDER BY 1",source_args)]
        return {'paletteCoverage':palette_coverage,'lenses':facets['lens'],'formats':facets['format'],'tagCoverage':self.tag_coverage(recipe),'tagVersion':self.tag_version,'assets':assets,'selectedAsset':selected_asset,'resultCount':min(total,100) if searching and mode!='filename' else total,'candidateCount':total,'cameras':cameras, 'coverage':self.coverage(recipe),'modelVersion':self.version,'rankingVersion':RANKING_VERSION}

    def handle(self, request):
        if request.get('protocol') != PROTOCOL: raise ValueError('Unsupported worker protocol')
        op=request.get('op')
        if op=='query': return self.query(request)
        if op=='index':
            result=self.index_batch(request); self.palette_batch(32); return result
        if op=='palettes': return self.palette_batch(request.get('limit',32),request.get('retry',False))
        if op=='tags': return {'processed':self.tag_batch(request.get('limit',128))}
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
