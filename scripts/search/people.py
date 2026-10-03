"""Offline YuNet/SFace indexing of cached previews, with persistent anonymous identities."""
import hashlib, json, uuid
from pathlib import Path
VERSION='yunet-2023mar:sface-2021dec:people-v1'
THRESHOLD=.50

def ensure_schema(db):
    db.executescript('''CREATE TABLE IF NOT EXISTS people (id TEXT PRIMARY KEY, vector BLOB NOT NULL);
    CREATE TABLE IF NOT EXISTS faces (id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
        person_id TEXT REFERENCES people(id), vector BLOB NOT NULL, avatar_path TEXT NOT NULL, quality REAL NOT NULL, rejected INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS person_aliases (id TEXT PRIMARY KEY, target_id TEXT NOT NULL REFERENCES people(id));
    CREATE TABLE IF NOT EXISTS person_exclusions (asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE, person_id TEXT NOT NULL REFERENCES people(id), PRIMARY KEY(asset_id,person_id));
    CREATE INDEX IF NOT EXISTS faces_person ON faces(person_id,asset_id);
    CREATE TABLE IF NOT EXISTS face_scans (asset_id TEXT PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE, fingerprint TEXT NOT NULL, error TEXT);''')

def fingerprint(row):
    path=Path(row['thumbnail_path'] or row['analysis_path'] or '')
    try: stat=path.stat(); stamp=[stat.st_mtime_ns,stat.st_size]
    except OSError: stamp=None
    return json.dumps([VERSION,row['modified_at'],row['byte_size'],row['pipeline_version'],str(path),stamp])

class People:
    def __init__(self, db, model_dir):
        self.db=db; self.folder=Path(model_dir).parent/'people';self.ready=False
        ensure_schema(db)
    def canonical(self, person):
        seen=set()
        while person not in seen:
            seen.add(person);row=self.db.execute('SELECT target_id FROM person_aliases WHERE id=?',[person]).fetchone()
            if row is None:return person
            person=row[0]
        raise ValueError('Invalid person merge cycle')
    def load(self):
        if self.ready:return
        import cv2 as cv, numpy as np
        detector=self.folder/'face_detection_yunet_2023mar.onnx';recognizer=self.folder/'face_recognition_sface_2021dec.onnx'
        if not detector.is_file() or not recognizer.is_file():raise ValueError('People models are missing. Run scripts/search/setup_people.py once; recognition then works offline.')
        cv.setNumThreads(1);self.cv=cv;self.np=np
        self.detector=cv.FaceDetectorYN.create(str(detector),'',(512,512),.9,.3,100)
        self.recognizer=cv.FaceRecognizerSF.create(str(recognizer),'');self.ready=True
    def rows(self):
        return self.db.execute('''SELECT a.id,a.modified_at,a.byte_size,d.thumbnail_path,d.analysis_path,d.pipeline_version,
            s.fingerprint,s.error FROM assets a JOIN derivatives d ON d.asset_id=a.id LEFT JOIN face_scans s ON s.asset_id=a.id
            WHERE d.thumbnail_path IS NOT NULL OR d.analysis_path IS NOT NULL
            ORDER BY EXISTS(SELECT 1 FROM tag_assignments t WHERE t.asset_id=a.id AND t.tag='people' AND t.decision!='rejected') DESC,a.id''').fetchall()
    def summary(self):
        rows=self.rows();prepared=sum(r['fingerprint']==fingerprint(r) for r in rows)
        people=[]
        for person in self.db.execute('''SELECT p.id,COUNT(DISTINCT f.asset_id) AS count FROM people p JOIN faces f ON f.person_id=p.id
            WHERE f.rejected=0 GROUP BY p.id ORDER BY count DESC,p.id'''):
            face=self.db.execute('SELECT avatar_path FROM faces WHERE person_id=? AND rejected=0 ORDER BY quality DESC,id LIMIT 1',[person['id']]).fetchone()
            # Count paired originals as one logical photo when a pairing exists.
            count=self.db.execute('''SELECT COUNT(DISTINCT COALESCE(pa.photo_id,f.asset_id)) FROM faces f LEFT JOIN photo_assets pa ON pa.asset_id=f.asset_id
                WHERE f.person_id=? AND f.rejected=0''',[person['id']]).fetchone()[0]
            people.append({'id':person['id'],'avatarPath':face[0],'count':count})
        people.sort(key=lambda p:(-p['count'],p['id']))
        return {'people':people,'total':len(rows),'prepared':prepared,'failed':sum(r['error'] is not None and r['fingerprint']==fingerprint(r) for r in rows),'processed':0,'remaining':len(rows)-prepared}
    def index(self, limit=4, retry=False):
        self.load()
        if retry:
            with self.db:self.db.execute('DELETE FROM face_scans WHERE error IS NOT NULL')
        rows=[r for r in self.rows() if r['fingerprint']!=fingerprint(r)][:min(16,max(1,limit))]
        for row in rows:
            stamp=fingerprint(row)
            try:
                self.scan(row,stamp)
            except (OSError,ValueError,self.cv.error) as error:
                with self.db:self.db.execute('INSERT OR REPLACE INTO face_scans VALUES(?,?,?)',[row['id'],stamp,str(error)])
        result=self.summary();result['processed']=len(rows);return result
    def scan(self,row,stamp):
        cv,np=self.cv,self.np
        path=row['thumbnail_path'] or row['analysis_path'];image=cv.imread(path)
        if image is None:raise ValueError('Cached preview could not be read. Rebuild its preview and retry.')
        h,w=image.shape[:2]
        if max(h,w)>1024:image=cv.resize(image,(round(w*1024/max(h,w)),round(h*1024/max(h,w))))
        h,w=image.shape[:2];self.detector.setInputSize((w,h));_,detections=self.detector.detect(image)
        folder=self.folder/'avatars';folder.mkdir(parents=True,exist_ok=True)
        previous=[(self.canonical(r['person_id']),self.np.frombuffer(r['vector'],dtype='<f4')) for r in self.db.execute('SELECT person_id,vector FROM faces WHERE asset_id=? AND person_id IS NOT NULL',[row['id']])]
        excluded={self.canonical(r[0]) for r in self.db.execute('SELECT person_id FROM person_exclusions WHERE asset_id=?',[row['id']])}
        profiles=self.profiles()
        # Replace this asset atomically, including the zero-face case.
        with self.db:
            self.db.execute('DELETE FROM faces WHERE asset_id=?',[row['id']])
            occupied=set()
            for index,face in enumerate([] if detections is None else sorted(detections,key=lambda f:float(f[0]))):
                if min(face[2],face[3])<32:continue
                aligned=self.recognizer.alignCrop(image,face);vector=self.recognizer.feature(aligned).reshape(-1).astype('<f4')
                norm=np.linalg.norm(vector)
                if not np.isfinite(vector).all() or norm<=0:continue
                vector/=norm
                face_id=str(uuid.uuid5(uuid.NAMESPACE_URL,VERSION+row['id']+str(index))).upper()
                choices=[]
                for person,(center,samples,_,_) in profiles.items():
                    if person in occupied:continue
                    score=float(vector @ center)
                    support=samples @ vector
                    if score>=THRESHOLD and float(support.max())>=THRESHOLD:
                        choices.append((score,person))
                choices.sort(reverse=True)
                # Ambiguous matches remain separate rather than merging lookalikes.
                if len(choices)>1 and choices[0][0]-choices[1][0]<.04:choices=[]
                # Preserve prior face membership by descriptor, never by detection ordinal.
                prior=[(float(vector @ prior_vector),person) for person,prior_vector in previous if person not in occupied]
                if prior and max(prior)[0]>=THRESHOLD:person_id=max(prior)[1]
                elif choices:person_id=max(choices)[1]
                else:
                    person_id=str(uuid.uuid4()).upper();self.db.execute('INSERT INTO people VALUES(?,?)',[person_id,vector.tobytes()])
                occupied.add(person_id)
                x,y,fw,fh=[float(v) for v in face[:4]];pad=.25*max(fw,fh)
                crop=image[max(0,int(y-pad)):min(h,int(y+fh+pad)),max(0,int(x-pad)):min(w,int(x+fw+pad))]
                avatar=folder/(face_id+'-'+hashlib.sha256(stamp.encode()).hexdigest()[:12]+'.jpg')
                if not cv.imwrite(str(avatar),crop):raise ValueError('Could not save face avatar.')
                self.db.execute('INSERT INTO faces VALUES(?,?,?,?,?,?,?)',[face_id,row['id'],person_id,vector.tobytes(),str(avatar),float(min(fw,fh)*face[-1]),int(person_id in excluded)])
            self.db.execute('INSERT OR REPLACE INTO face_scans VALUES(?,?,NULL)',[row['id'],stamp])

    def correct(self, request, summarize=True):
        person=self.canonical(request.get('personID'));action=request.get('action')
        if not self.db.execute('SELECT 1 FROM people WHERE id=?',[person]).fetchone():raise ValueError('This person is no longer available. Refresh People.')
        with self.db:
            if action=='remove':
                asset=request.get('assetID')
                assets={asset}|{r[0] for r in self.db.execute('SELECT asset_id FROM photo_assets WHERE photo_id IN (SELECT photo_id FROM photo_assets WHERE asset_id=?)',[asset])}
                for asset in assets:
                    self.db.execute('INSERT OR IGNORE INTO person_exclusions VALUES(?,?)',[asset,person])
                    self.db.execute('UPDATE faces SET rejected=1 WHERE person_id=? AND asset_id=?',[person,asset])
            elif action=='merge':
                target=self.canonical(request.get('targetID'))
                if target==person or not self.db.execute('SELECT 1 FROM people WHERE id=?',[target]).fetchone():raise ValueError('Choose a different person to merge into.')
                self.db.execute('UPDATE faces SET person_id=? WHERE person_id=?',[target,person])
                self.db.execute('INSERT OR REPLACE INTO person_aliases VALUES(?,?)',[person,target])
                self.db.execute('INSERT OR IGNORE INTO person_exclusions SELECT asset_id,? FROM person_exclusions WHERE person_id=?',[target,person])
                self.db.execute('DELETE FROM person_exclusions WHERE person_id=?',[person])
            elif action=='restore':
                self.db.execute('DELETE FROM person_exclusions WHERE person_id=?',[person])
                self.db.execute('UPDATE faces SET rejected=0 WHERE person_id=?',[person])
            else:raise ValueError('Unknown people correction')
        return self.summary() if summarize else None

    def profiles(self):
        import numpy as np
        groups={}
        for row in self.db.execute('SELECT person_id,asset_id,vector FROM faces WHERE rejected=0 AND person_id IS NOT NULL ORDER BY quality DESC'):
            groups.setdefault(row['person_id'],[]).append((row['asset_id'],np.frombuffer(row['vector'],dtype='<f4')))
        profiles={}
        for person,rows in groups.items():
            matrix=np.stack([v for _,v in rows]);center=matrix.mean(axis=0);norm=np.linalg.norm(center)
            if norm>0:profiles[person]=(center/norm,matrix,{asset for asset,_ in rows},rows)
        return profiles

    def refine(self):
        """Conservative complete-link consolidation, blocking co-occurring identities."""
        import numpy as np
        profiles=self.profiles();ids=sorted(profiles,key=lambda id:(-len(profiles[id][2]),id))
        logical={r[0]:r[1] for r in self.db.execute('SELECT asset_id,photo_id FROM photo_assets')}
        clusters=[]
        def compatible(a,b):
            ca,ma,aa,ra=profiles[a];cb,mb,ab,rb=profiles[b]
            if aa & ab:return False
            if self.db.execute('SELECT 1 FROM person_exclusions WHERE person_id IN (?,?) LIMIT 1',[a,b]).fetchone():return False
            similarity=float(ca @ cb)
            if min(len({logical.get(a,a) for a in aa}),len({logical.get(b,b) for b in ab}))<2:return similarity>=.85
            if similarity<.65:return False
            scores=ma @ mb.T
            left={logical.get(asset,asset) for (asset,_),score in zip(ra,scores.max(axis=1)) if score>=.60}
            right={logical.get(asset,asset) for (asset,_),score in zip(rb,scores.max(axis=0)) if score>=.60}
            return len(left)>=2 and len(right)>=2
        for person in ids:
            for cluster in clusters:
                if all(compatible(person,member) for member in cluster):cluster.append(person);break
            else:clusters.append([person])
        merged=0
        for cluster in clusters:
            for person in cluster[1:]:
                self.correct({'action':'merge','personID':person,'targetID':cluster[0]},summarize=False);merged+=1
        result=self.summary();result['merged']=merged;return result
