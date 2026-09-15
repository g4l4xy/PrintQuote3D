#!/usr/bin/env python3
"""Check body/accent contrast and adaptive ordering; no UI or customer data needed."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
t=json.loads((root/'SharedSchemas/pq-design-tokens.json').read_text())
def luminance(value):
    channels=[int(value[i:i+2],16)/255 for i in (1,3,5)]
    linear=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in channels]
    return sum(v*w for v,w in zip(linear,(0.2126,0.7152,0.0722)))
for theme,colors in t['color'].items():
    for foreground in ('text','secondary','accent'):
        for background in ('workspace','panel','raised'):
            a,b=sorted((luminance(colors[foreground]),luminance(colors[background])))
            ratio=(b+0.05)/(a+0.05)
            assert ratio>=4.5, (theme,foreground,background,ratio)
    print(theme+': text, secondary and accent meet 4.5:1 on all content surfaces')
assert list(t['layout'].values())==sorted(t['layout'].values())
assert t['controlSize']['androidTouch']>=48 and t['controlSize']['appleTouch']>=44
print('Adaptive breakpoints and touch-target tokens pass')
