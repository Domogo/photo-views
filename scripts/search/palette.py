"""Deterministic sRGB preview area histogram. No inference or original-file access."""
import colorsys
from PIL import Image

VERSION = 'srgb-hsv-area-v1'
COLORS = ('red','orange','yellow','green','cyan','blue','purple','pink','brown','black','gray','white')

def histogram(path):
    with Image.open(path) as image:
        # Derivatives are orientation-corrected, opaque, sRGB images.
        image = image.convert('RGB').resize((64,64), Image.Resampling.BOX)
        counts = dict.fromkeys(COLORS,0)
        pixels = image.tobytes()
        for r,g,b in zip(pixels[0::3],pixels[1::3],pixels[2::3]):
            h,s,v = colorsys.rgb_to_hsv(r/255,g/255,b/255); h *= 360
            if v < .16: name='black'
            elif s < .14: name='white' if v >= .85 else 'gray'
            elif 15 <= h < 65 and v < .65: name='brown'
            elif h < 15 or h >= 345: name='red'
            elif h < 45: name='orange'
            elif h < 70: name='yellow'
            elif h < 165: name='green'
            elif h < 200: name='cyan'
            elif h < 265: name='blue'
            elif h < 300: name='purple'
            else: name='pink'
            counts[name] += 1
        return {name:count/4096 for name,count in counts.items()}
