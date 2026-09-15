"""Generate bounded synthetic archives and measure the read-only Swift probe on macOS.
Run after: swift build -c release --product ThreeMFProbe
Artifacts go to .workflow (ignored); no customer files are copied into fixtures.
"""
from pathlib import Path
import zipfile,tempfile,subprocess,json,re,os
ROOT=Path(__file__).resolve().parents[2]
probe=ROOT/'.build/release/ThreeMFProbe'
results=[]
with tempfile.TemporaryDirectory(prefix='pq-3mf-benchmark-') as folder:
 for name,padding,triangles in [('small',0,4),('medium',32,4),('large',192,4),('geometry',0,500000)]:
  file=Path(folder)/(name+'.3mf')
  with zipfile.ZipFile(file,'w',zipfile.ZIP_STORED) as z:
   z.writestr('_rels/.rels','<Relationships><Relationship Id="r1" Target="/3D/root.model" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>')
   with z.open('3D/root.model','w',force_zip64=True) as part:
    part.write(b'<model xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" unit="millimeter"><resources><object id="1"><mesh><vertices><vertex x="0" y="0" z="0"/><vertex x="1" y="0" z="0"/><vertex x="0" y="1" z="0"/><vertex x="0" y="0" z="1"/></vertices><triangles>')
    block=b'<triangle v1="0" v2="1" v3="2"/>'*min(triangles,1000)
    for i in range(0,triangles,1000):part.write(block)
    part.write(b'</triangles></mesh></object></resources><build><item objectid="1"/></build></model>')
   for index in range((padding+95)//96):
    with z.open(f'Assets/payload-{index}.bin','w',force_zip64=True) as part:
     for _ in range(min(96,padding-index*96)):part.write(os.urandom(1024*1024))
  run=subprocess.run(['/usr/bin/time','-l',str(probe),str(file)],capture_output=True,text=True,timeout=120,check=True)
  result=json.loads(run.stdout);result['case']=name;result['archiveMiB']=round(file.stat().st_size/1024**2,2)
  match=re.search(r'(\d+)\s+maximum resident set size',run.stderr);result['peakRSSMiB']=round(int(match.group(1))/1024**2,2) if match else None
  assert not any(c.endswith('importFailed') for c in result['diagnosticCodes']),result
  assert result['peakRSSMiB'] is None or result['peakRSSMiB']<512,result
  results.append(result);print(json.dumps(result),flush=True)
out=ROOT/'.workflow/three-mf-performance.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(results,indent=2)+'\n')
