"""Generate original synthetic demo artwork (MIT); never reads personal photos."""
import argparse
from PIL import Image,ImageDraw
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
root=args.output.expanduser().resolve()
repo=Path(__file__).resolve().parents[1]
if root==repo or repo in root.parents:parser.error('Generate fixtures outside the repository.')
root.mkdir(parents=True,exist_ok=True)
colors=[('#397aa0','#a8d1de','#e6c998'),('#b97957','#e6bc88','#f3dfb7'),('#578270','#b3caba','#e5e2bd'),('#5d6f9b','#b6c3df','#e5d8c9')]
for i in range(24):
 w,h=(800,1000) if i%3==0 else (1200,800)
 sky,mountain,sand=colors[i%4];im=Image.new('RGB',(w,h),sky);d=ImageDraw.Draw(im)
 d.ellipse((w*.68,h*.12,w*.83,h*.12+w*.15),fill=sand)
 d.polygon([(0,h*.65),(w*.23,h*.3),(w*.6,h*.68),(w*.8,h*.4),(w,h*.66),(w,h),(0,h)],fill=mountain)
 d.polygon([(0,h*.82),(w*.45,h*.68),(w,h*.8),(w,h),(0,h)],fill=sand)
 if i%2:d.rectangle((w*.12,h*.66,w*.24,h*.82),fill=sky)
 im.save(root/f'Landscape-{i+1:02}.jpg',quality=95)
print(root)
