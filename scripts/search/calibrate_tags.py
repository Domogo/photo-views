#!/usr/bin/env python3
"""Prepare local review material and measure tag cutoffs. Photos/labels/reports stay outside Git.
Labels map sample indices to visible subject tags; never label uninspected photos by model score.
"""
import argparse,json,sqlite3,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from worker import Worker,MODEL_VERSION
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--catalog',required=True);p.add_argument('--model',required=True);p.add_argument('--output',required=True);p.add_argument('--labels');p.add_argument('--threshold-output');a=p.parse_args();out=Path(a.output);out.mkdir(parents=True,exist_ok=True)
w=Worker(a.catalog,a.model);features=w.tag_features();tags=[v['tag'] for v in w.tag_config['tags']]
if not a.labels:
 rows=w.db.execute('SELECT a.id,a.source_id,a.relative_path,d.thumbnail_path,e.vector FROM assets a JOIN embeddings e ON e.asset_id=a.id JOIN derivatives d ON d.asset_id=a.id WHERE e.model_version=? ORDER BY a.id',[MODEL_VERSION]).fetchall()
 scores=np.stack([np.frombuffer(r['vector'],dtype='<f4') for r in rows]) @ features.T
 chosen=[];seen=set()
 for t in range(len(tags)):
  folders={};n=0
  for i in np.argsort(-scores[:,t]):
   row=rows[i];key=(row['source_id'],str(Path(row['relative_path']).with_suffix('')));folder=str(Path(row['relative_path']).parent)
   if key in seen or folders.get(folder,0)>=2 or not row['thumbnail_path'] or not Path(row['thumbnail_path']).is_file():continue
   seen.add(key);folders[folder]=folders.get(folder,0)+1;chosen.append(int(i));n+=1
   if n==8:break
 sample=[{'index':n,'assetID':rows[i]['id'],'path':rows[i]['thumbnail_path'],'event':rows[i]['source_id']+':'+str(Path(rows[i]['relative_path']).parent),'usable':(lambda limits:limits[1]-limits[0]>=3)(Image.open(rows[i]['thumbnail_path']).convert('L').getextrema()),'scores':dict(zip(tags,map(float,scores[i])))} for n,i in enumerate(chosen)]
 (out/'sample.json').write_text(json.dumps(sample,indent=2))
 for page in range(math.ceil(len(sample)/16)):
  sheet=Image.new('RGB',(960,720),'white');draw=ImageDraw.Draw(sheet)
  for slot,item in enumerate(sample[page*16:(page+1)*16]):
   image=Image.open(item['path']).convert('RGB');image.thumbnail((232,145));x=(slot%4)*240;y=(slot//4)*180;sheet.paste(image,(x+(232-image.width)//2,y))
   best=sorted(item['scores'],key=item['scores'].get,reverse=True)[:2]
   draw.text((x+4,y+148),str(item['index'])+'  '+' '.join(t+':'+format(item['scores'][t],'.2f') for t in best),fill='black')
  sheet.save(out/f'contact-{page}.jpg')
 print(json.dumps({'reviewPhotos':len(sample),'contactSheets':math.ceil(len(sample)/16)}))
else:
 sample=json.loads((out/'sample.json').read_text());labels=json.loads(Path(a.labels).read_text());assert len(labels)==len(sample),'Every selected photo must be reviewed.'
 # Whole source-folder events stay in one split. Deterministic alternation by event.
 events=sorted({s['event'] for s in sample});tune_events=set(events[::2]);tuning=[s for s in sample if s['event'] in tune_events];heldout=[s for s in sample if s['event'] not in tune_events]
 config=w.tag_config;report={'labelAuthority':'agent visual review; human acceptance pending','tuningPhotos':len(tuning),'heldoutPhotos':len(heldout),'eventSeparated':True,'tags':{}}
 for item in config['tags']:
  tag=item['tag'];candidates=sorted({0.25,0.30,0.35,1.01,*[s['scores'][tag] for s in tuning]})
  chosen=1.01
  for cutoff in candidates:
   predicted=[s for s in tuning if s.get('usable',True) and s['scores'][tag]>=cutoff];tp=sum(tag in labels[str(s['index'])] for s in predicted)
   if len(predicted)>=2 and tp/len(predicted)>=.9:chosen=cutoff;break
  item['threshold']=round(chosen,6) if chosen==1.01 else math.ceil(chosen*1e6)/1e6
  stats={}
  for name,split in [('tuning',tuning),('heldout',heldout)]:
   predicted=[s for s in split if s.get('usable',True) and s['scores'][tag]>=item['threshold']];tp=sum(tag in labels[str(s['index'])] for s in predicted);positives=sum(tag in labels[str(s['index'])] for s in split)
   stats[name]={'predictions':len(predicted),'truePositives':tp,'positives':positives,'precision':tp/len(predicted) if predicted else None,'recall':tp/positives if positives else None,'coverage':len(predicted)/len(split) if split else 0}
  report['tags'][tag]={'threshold':item['threshold'],'status':'insufficient tuning evidence; suggestions suppressed' if chosen==1.01 else 'agent-calibrated evaluation cutoff',**stats}
 config['calibration']='Per-tag cutoffs from event-separated local agent-reviewed sample; human acceptance and held-out precision targets remain open. A cutoff above 1 suppresses tags with insufficient tuning evidence.'
 report['runtimeEvaluation']={}
 for name,split in [('tuning',tuning),('heldout',heldout)]:
  predictions={s['index']:[v['tag'] for v in sorted(config['tags'],key=lambda v:(-s['scores'][v['tag']],v['tag'])) if s.get('usable',True) and s['scores'][v['tag']]>=v['threshold']][:config['maxSuggestions']] for s in split}
  metrics={}
  for tag in tags:
   predicted=[s for s in split if tag in predictions[s['index']]];tp=sum(tag in labels[str(s['index'])] for s in predicted);positives=sum(tag in labels[str(s['index'])] for s in split)
   metrics[tag]={'predictions':len(predicted),'truePositives':tp,'positives':positives,'precision':tp/len(predicted) if predicted else None,'recall':tp/positives if positives else None,'coverage':len(predicted)/len(split) if split else 0}
  total=sum(v['predictions'] for v in metrics.values());correct=sum(v['truePositives'] for v in metrics.values())
  report['runtimeEvaluation'][name]={'tags':metrics,'predictions':total,'truePositives':correct,'precision':correct/total if total else None,'photosWithSuggestions':sum(bool(v) for v in predictions.values()),'photoCoverage':sum(bool(v) for v in predictions.values())/len(split) if split else 0}
 (out/'calibration.json').write_text(json.dumps(report,indent=2)+'\n')
 if a.threshold_output:Path(a.threshold_output).write_text(json.dumps(config,indent=2)+'\n')
 print(json.dumps(report))
