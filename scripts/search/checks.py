#!/usr/bin/env python3
"""Local retrieval invariants; synthetic vectors test constraints independently of model quality."""
import json, sqlite3, tempfile, unittest
from pathlib import Path
import numpy as np
from worker import Worker, MODEL_VERSION, reciprocal_rank_fusion

class SearchChecks(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'catalog.sqlite'
        db=sqlite3.connect(self.path)
        db.executescript('''CREATE TABLE assets(id TEXT PRIMARY KEY,source_id TEXT,relative_path TEXT,file_id TEXT,byte_size INTEGER,modified_at REAL,available INTEGER,favorite INTEGER DEFAULT 0);
        CREATE TABLE metadata(asset_id TEXT,payload BLOB,capture_date REAL);
        CREATE TABLE derivatives(asset_id TEXT,thumbnail_path TEXT,analysis_path TEXT,pipeline_version TEXT,preview_source TEXT);
        CREATE TABLE index_jobs(id TEXT,source_id TEXT,asset_id TEXT,stage TEXT,state TEXT,error TEXT,pipeline_version TEXT,updated_at REAL,UNIQUE(asset_id,stage,pipeline_version));
        CREATE TABLE embeddings(asset_id TEXT,model_version TEXT,dimensions INTEGER,vector BLOB,PRIMARY KEY(asset_id,model_version));
        CREATE TABLE tag_assignments(asset_id TEXT,tag TEXT,provenance TEXT,decision TEXT,id TEXT,model_version TEXT,score REAL,threshold REAL,vocabulary_version TEXT);
        CREATE TABLE tag_runs(asset_id TEXT PRIMARY KEY,vocabulary_version TEXT,model_version TEXT,input_fingerprint TEXT);
        CREATE TABLE photos(id TEXT PRIMARY KEY,primary_asset_id TEXT);
        CREATE TABLE photo_assets(photo_id TEXT,asset_id TEXT UNIQUE);
        CREATE TABLE collections(id TEXT PRIMARY KEY,name TEXT);
        CREATE TABLE collection_assets(collection_id TEXT,asset_id TEXT,PRIMARY KEY(collection_id,asset_id));''')
        for id,source,path,camera,day,score in [('a','one','Japan/car.jpg','Nikon','2025:11:06',1),('b','one','Japan/lake.nef','Nikon','2025:11:07',.8),('c','two','Elsewhere/car.arw','Sony','2024:01:01',.9),('d','one','Unknown/car.jpg',None,None,.7)]:
            db.execute('INSERT INTO assets(id,source_id,relative_path,file_id,byte_size,modified_at,available) VALUES(?,?,?,?,?,?,?)',[id,source,path,None,10,123,0])
            db.execute('INSERT INTO metadata VALUES(?,?,?)',[id,json.dumps({'camera':camera,'captureDateText':day,'format':Path(path).suffix[1:].upper()}).encode(),123])
            db.execute('INSERT INTO derivatives VALUES(?,?,?,?,?)',[id,None,None,'imageio-m2-v1','fixture'])
            db.execute('INSERT INTO index_jobs VALUES(?,?,?,?,?,?,?,?)',[id,source,id,'preview','complete',None,'imageio-m2-v1',1])
            vector=np.zeros(512,dtype='<f4');vector[0]=score;vector[1]=np.sqrt(1-score*score)
            db.execute('INSERT INTO embeddings VALUES(?,?,?,?)',[id,MODEL_VERSION,512,vector.tobytes()])
        db.execute('INSERT INTO tag_assignments(asset_id,tag,provenance,decision) VALUES(?,?,?,?)',['b','mountain','imported','unconfirmed'])
        db.commit();db.close()
        self.worker=Worker(self.path,Path(self.tmp.name));self.worker.model=object();self.worker.np=np
    def tearDown(self):self.worker.db.close();self.tmp.cleanup()
    def query(self,recipe,mode='filename'):
        return self.worker.handle({'protocol':1,'op':'query','recipe':recipe,'mode':mode,'limit':1})
    def test_pair_collapse_respects_asset_constraints_and_selection(self):
        db=sqlite3.connect(self.path)
        db.execute("INSERT INTO photos VALUES('p','b')")
        db.executemany("INSERT INTO photo_assets VALUES('p',?)",[('a',),('b',)])
        db.commit();db.close()
        result=self.worker.query({'recipe':{},'limit':100,'selectedAssetID':'a'})
        self.assertEqual(result['resultCount'],3)
        self.assertEqual(sum(a['photoID']=='p' for a in result['assets']),1)
        self.assertEqual(result['selectedAsset']['asset']['id'],'a')
        similar=self.worker.query({'recipe':{'referenceAssetID':'b'},'mode':'visual'})
        self.assertFalse({'a','b'} & {a['asset']['id'] for a in similar['assets']})
        separate=self.worker.query({'recipe':{'collapsePairs':False}})
        self.assertEqual(separate['resultCount'],4)
        jpeg=self.worker.query({'recipe':{'filters':{'format':'JPG'}}})
        self.assertTrue(all(a['metadata']['format']=='JPG' for a in jpeg['assets']))
        db=sqlite3.connect(self.path);db.execute("INSERT INTO collection_assets VALUES('pick','a')");db.commit();db.close()
        picked=self.worker.query({'recipe':{'collectionID':'pick'},'selectedAssetID':'b'})
        self.assertEqual([a['asset']['id'] for a in picked['assets']],['a'])
        self.assertIsNone(picked['selectedAsset'])
        # Missing originals retain cached retrieval and pair membership.
        self.assertTrue(all(not a['available'] for a in result['assets']))
        self.assertEqual(len(next(a for a in result['assets'] if a['photoID']=='p')['pairedAssetIDs']),2)

    def test_complete_metadata_constraints(self):
        payload={'lens':'Prime','iso':400,'aperture':2.8,'shutterSeconds':0.002,'width':6000,'height':4000,'format':'JPG','camera':'Nikon','captureDateText':'2025:11:06'}
        self.worker.db.execute('UPDATE metadata SET payload=? WHERE asset_id=?',[json.dumps(payload).encode(),'a']);self.worker.db.commit()
        filters={'lens':'Prime','minISO':400,'maxISO':400,'minAperture':2.8,'maxAperture':2.8,'minShutterSeconds':.002,'maxShutterSeconds':.002,'minWidth':6000,'maxWidth':6000,'minHeight':4000,'maxHeight':4000,'format':'JPG'}
        self.assertEqual(self.query({'filters':filters})['resultCount'],1)
        for key,value in [('minISO',401),('minAperture',2.9),('minShutterSeconds',.003),('minWidth',6001),('minHeight',4001)]:
            self.assertEqual(self.query({'filters':{key:value}})['resultCount'],0)
        for key in ('minISO','maxAperture','maxShutterSeconds','minWidth','maxHeight'):
            for value in (-1,float('nan'),float('inf'),'1 OR 1=1',True):
                with self.assertRaises(ValueError):self.query({'filters':{key:value}})
        with self.assertRaises(ValueError):self.query({'filters':{'minWidth':6000,'maxWidth':2000}})
        payload['width']='6000';payload['captureDateText']='2025:99:01';self.worker.db.execute('UPDATE metadata SET payload=? WHERE asset_id=?',[json.dumps(payload).encode(),'a']);self.worker.db.commit()
        self.assertEqual(self.query({'filters':{'minWidth':1}})['resultCount'],0)
        self.assertEqual(self.query({'filters':{'fromDay':'2025-11-06','toDay':'2025-11-06'}})['resultCount'],0)
        self.assertEqual(self.query({})['lenses'],['Prime'])
        self.assertEqual(self.query({'sourceIDs':['two']})['formats'],['ARW'])
        self.assertEqual(self.query({'filters':{'lens':"' OR 1=1 --"}})['resultCount'],0)
    def test_literal_keyword_and_no_relaxation(self):
        r=self.query({'search':'car','sourceIDs':['one'],'filters':{'camera':'Nikon'}})
        self.assertEqual([a['asset']['id'] for a in r['assets']],['a']);self.assertEqual(r['resultCount'],1)
        self.assertEqual(self.query({'search':"%' OR 1=1 --"})['resultCount'],0)
        self.assertEqual(self.query({'search':'car','filters':{'camera':'Nonexistent'}})['resultCount'],0)
        self.assertEqual(self.query({'search':'mountain'})['assets'][0]['asset']['id'],'b')
    def test_dates_unknown_and_folder(self):
        self.assertEqual(self.query({'filters':{'fromDay':'2025-11-07','toDay':'2025-11-07'}})['resultCount'],1)
        self.assertEqual(self.query({'filters':{'fromDay':'2026-01-01','toDay':'2025-01-01'}})['resultCount'],0)
        self.assertEqual(self.query({'filters':{'folder':'car.jpg'}})['resultCount'],0)
        self.assertEqual(self.query({'filters':{'folder':'Japan'}})['resultCount'],2)
    def test_filter_before_top_k_and_reference_excluded(self):
        r=self.query({'referenceAssetID':'a','sourceIDs':['one'],'filters':{'camera':'Nikon'}})
        self.assertEqual([a['asset']['id'] for a in r['assets']],['b'])
        self.assertEqual(r['coverage']['embedded'],2)
        self.assertFalse(r['assets'][0]['available']) # cached retrieval works without originals
    def test_model_version_and_fusion(self):
        self.worker.db.execute('UPDATE embeddings SET model_version=? WHERE asset_id=?',['old','b']);self.worker.db.commit()
        r=self.query({'referenceAssetID':'a','filters':{'camera':'Nikon'}})
        self.assertEqual(r['assets'],[])
        self.assertEqual(reciprocal_rank_fusion(['a','b','c'],['b']),['b','a','c'])
        self.assertEqual(reciprocal_rank_fusion(['a','b'],[]),['a','b'])
    def test_missing_cache_failure_isolation_and_retry(self):
        self.worker.db.execute('DELETE FROM embeddings');self.worker.db.execute("UPDATE derivatives SET analysis_path='/nonexistent/fixture.jpg'");self.worker.db.commit()
        first=self.worker.handle({'protocol':1,'op':'index','limit':16})
        self.assertEqual(first['failedBatch'],4)
        self.assertEqual(len(self.worker.coverage({})['failures']),3)
        self.assertEqual(self.worker.handle({'protocol':1,'op':'index'})['processed'],0)
        self.assertEqual(self.worker.handle({'protocol':1,'op':'retry'})['failed'],0)
        self.assertEqual(self.worker.handle({'protocol':1,'op':'index'})['processed'],4)
    def test_partial_coverage_and_filename_fallback(self):
        self.worker.db.execute("DELETE FROM embeddings WHERE asset_id='b'");self.worker.db.commit()
        r=self.query({'search':'lake.nef','sourceIDs':['one']})
        self.assertEqual(r['assets'][0]['asset']['id'],'b')
        self.assertEqual(r['coverage']['embedded'],2)
        visual=self.query({'referenceAssetID':'a','sourceIDs':['one'],'filters':{'camera':'Nikon'}})
        self.assertEqual(visual['assets'],[])
        self.assertEqual(visual['coverage']['embedded'],1)
    def test_presentation_does_not_change_membership_or_rank(self):
        for grouping in ('none','month','camera','folder'):
            result=self.worker.handle({'protocol':1,'op':'query','mode':'visual','limit':100,'recipe':{'referenceAssetID':'a','grouping':grouping,'filters':{'camera':'Nikon'}}})
            self.assertEqual([a['asset']['id'] for a in result['assets']],['b'])
    def test_selected_identity_outside_page_and_removed_by_filter(self):
        request={'protocol':1,'op':'query','mode':'filename','limit':1,'selectedAssetID':'d','recipe':{'sorting':'filename'}}
        result=self.worker.handle(request)
        self.assertEqual(result['selectedAsset']['asset']['id'],'d')
        self.assertNotEqual(result['assets'][0]['asset']['id'],'d')
        request['recipe']['filters']={'camera':'Nikon'}
        self.assertIsNone(self.worker.handle(request)['selectedAsset'])
    def test_live_saved_recipe_newly_ready_membership_and_reopen(self):
        self.worker.db.execute('CREATE TABLE saved_views(id TEXT PRIMARY KEY, recipe BLOB)')
        recipe={'search':'car','searchMode':'filename','sourceIDs':['one'],'filters':{'camera':'Nikon'},'grouping':'month','sorting':'filename','modelVersion':MODEL_VERSION,'rankingVersion':'rrf-k60-v1'}
        self.worker.db.execute('INSERT INTO saved_views VALUES(?,?)',['view',json.dumps(recipe)]);self.worker.db.commit()
        self.assertEqual(self.query(recipe)['resultCount'],1)
        self.worker.db.execute("INSERT INTO assets(id,source_id,relative_path,file_id,byte_size,modified_at,available) VALUES('new','one','Japan/car-new.jpg',NULL,10,123,0)")
        self.worker.db.execute("INSERT INTO metadata VALUES('new',?,123)",[json.dumps({'camera':'Nikon','captureDateText':'2025:11:08'}).encode()])
        self.worker.db.execute("INSERT INTO index_jobs VALUES('new','one','new','preview','pending',NULL,'imageio-m2-v1',1)");self.worker.db.commit()
        self.assertEqual(self.query(recipe)['resultCount'],1)
        self.worker.db.execute("UPDATE index_jobs SET state='complete' WHERE asset_id='new'");self.worker.db.commit()
        self.worker.db.close();self.worker=Worker(self.path,Path(self.tmp.name))
        saved=json.loads(self.worker.db.execute("SELECT recipe FROM saved_views WHERE id='view'").fetchone()[0])
        self.assertEqual(saved,recipe);self.assertEqual(self.query(saved)['resultCount'],2)
    def test_saved_version_mismatch_requires_explicit_change(self):
        for field in ('modelVersion','rankingVersion'):
            recipe={'referenceAssetID':'a',field:'old-version'}
            with self.assertRaisesRegex(ValueError,'different search model'):self.query(recipe)
            self.assertEqual(recipe[field],'old-version')
        self.assertEqual(self.query({'referenceAssetID':'a','modelVersion':MODEL_VERSION,'rankingVersion':'rrf-k60-v1'})['resultCount'],3)
    def test_favorites_collections_are_exact_and_manual(self):
        self.worker.db.execute("UPDATE assets SET favorite=1 WHERE id='b'")
        self.worker.db.execute("INSERT INTO collection_assets VALUES('trip','a')");self.worker.db.commit()
        self.assertEqual(self.query({'favoritesOnly':True})['assets'][0]['asset']['id'],'b')
        self.assertEqual(self.query({'collectionID':'trip'})['resultCount'],1)
        self.assertEqual(self.query({'collectionID':'trip','filters':{'camera':'Sony'}})['resultCount'],0)
        self.assertEqual(self.query({'collectionID':"trip' OR 1=1 --"})['resultCount'],0)
    def test_suggestions_searchable_but_not_confirmed_and_rejections_excluded(self):
        self.worker.db.execute("INSERT INTO tag_assignments VALUES('b','water','suggested','unconfirmed','tag',?,.4,.3,?)",[MODEL_VERSION,self.worker.tag_version]);self.worker.db.commit()
        self.assertEqual(self.query({'search':'water'})['resultCount'],1)
        self.assertEqual(self.query({'filters':{'confirmedTags':['water']}})['resultCount'],0)
        self.worker.db.execute("UPDATE tag_assignments SET decision='accepted' WHERE id='tag'");self.worker.db.commit()
        self.assertEqual(self.query({'filters':{'confirmedTags':['water']}})['resultCount'],1)
        self.worker.db.execute("UPDATE tag_assignments SET provenance='manual',decision='rejected' WHERE id='tag'");self.worker.db.commit()
        self.assertEqual(self.query({'search':'water'})['resultCount'],0)
        self.assertEqual(self.query({'filters':{'confirmedTags':['water']}})['resultCount'],0)
    def test_primary_subject_confirmed_precedence_unknown_and_stale(self):
        self.worker.db.execute("INSERT INTO tag_assignments VALUES('b','water','suggested','unconfirmed','s',?,.4,.3,?)",[MODEL_VERSION,self.worker.tag_version])
        self.worker.db.execute("INSERT INTO tag_assignments VALUES('b','cars','manual','accepted','m',NULL,NULL,NULL,NULL)");self.worker.db.commit()
        photo=self.query({'search':'lake'})['assets'][0]
        self.assertEqual(photo['primarySubject'],'cars');self.assertFalse(photo['primarySubjectSuggested'])
        self.worker.db.execute("UPDATE tag_assignments SET decision='rejected' WHERE id='m'");self.worker.db.commit()
        photo=self.query({'search':'lake'})['assets'][0];self.assertEqual(photo['primarySubject'],'water');self.assertTrue(photo['primarySubjectSuggested'])
        self.worker.db.execute("UPDATE tag_assignments SET vocabulary_version='old' WHERE id='s'");self.worker.db.commit()
        self.assertIsNone(self.query({'search':'lake'})['assets'][0]['primarySubject'])
    def test_tag_batches_checkpoint_decisions_and_uniform_preview(self):
        from PIL import Image
        image=Path(self.tmp.name)/'preview.jpg';Image.new('RGB',(20,20),'black').save(image)
        self.worker.db.execute('UPDATE derivatives SET thumbnail_path=?',[str(image)]);self.worker.db.commit()
        self.worker.tag_vectors=np.zeros((8,512),dtype='<f4');self.worker.tag_vectors[:,0]=1
        self.assertEqual(self.worker.tag_batch(),4)
        self.assertEqual(self.worker.db.execute("SELECT count(*) FROM tag_assignments WHERE provenance='suggested'").fetchone()[0],0)
        self.assertEqual(self.worker.tag_batch(),0) # completed empty runs do not repeat
        im=Image.new('RGB',(20,20),'black');im.paste('white',(0,0,10,20));im.save(image)
        self.worker.db.execute('DELETE FROM tag_runs')
        self.worker.db.execute("INSERT INTO tag_assignments VALUES('a','cars','suggested','rejected','reject',?,.5,.3,?)",[MODEL_VERSION,self.worker.tag_version])
        self.worker.db.execute("INSERT INTO tag_assignments VALUES('b','water','manual','accepted','manual',NULL,NULL,NULL,NULL)");self.worker.db.commit()
        self.assertEqual(self.worker.tag_batch(limit=2),2)
        self.assertEqual(self.worker.db.execute("SELECT count(*) FROM tag_assignments WHERE asset_id='a' AND tag='cars'").fetchone()[0],1)
        self.assertEqual(self.worker.db.execute("SELECT decision FROM tag_assignments WHERE id='reject'").fetchone()[0],'rejected')
        self.assertEqual(self.worker.db.execute("SELECT provenance FROM tag_assignments WHERE id='manual'").fetchone()[0],'manual')
        self.worker.tag_version='next-vocabulary';self.worker.tag_batch()
        self.assertEqual(self.worker.db.execute("SELECT decision FROM tag_assignments WHERE id='reject'").fetchone()[0],'rejected')
    def test_invalid_protocol(self):
        with self.assertRaises(ValueError):self.worker.handle({'protocol':999,'op':'query'})

if __name__=='__main__':unittest.main()
