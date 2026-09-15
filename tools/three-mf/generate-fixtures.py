from pathlib import Path
import json,zipfile,shutil,struct
ROOT=Path(__file__).resolve().parents[2]
import os
os.chdir(ROOT)
p=Path('SharedSchemas/three-mf-v2');p.mkdir(exist_ok=True)
verts='<vertices><vertex x="0" y="0" z="0"/><vertex x="1" y="0" z="0"/><vertex x="0" y="1" z="0"/><vertex x="0" y="0" z="1"/></vertices>'
tris='<triangles>'+''.join(f'<triangle v1="{a}" v2="{b}" v3="{c}"/>' for a,b,c in [(0,2,1),(0,1,3),(1,2,3),(2,0,3)])+'</triangles>'
obj=f'<object id="1" name="Tetra"><mesh>{verts}{tris}</mesh></object>'
def model(app='',unit='millimeter',resources=obj,transform='',build='<item objectid="1"/>'):
 return f'<model xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" unit="{unit}"><metadata name="Application">{app}</metadata><resources>{resources}</resources><build>{build if not transform else chr(60)+"item objectid="+chr(34)+"1"+chr(34)+" transform="+chr(34)+transform+chr(34)+"/"+chr(62)}</build></model>'
rels='<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Target="/Models/root.model" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>'
def write(name,xml=None,extra=None):
 with zipfile.ZipFile(p/(name+'.3mf'),'w',zipfile.ZIP_DEFLATED) as z:
  z.writestr('_rels/.rels',rels);z.writestr('Models/root.model',xml or model())
  for k,v in (extra or {}).items():z.writestr(k,v)
base={'printer_model':'Bambu Lab P1S','nozzle_diameter':['0.4'],'filament_type':['PLA']*4,'filament_colour':['#000000','#FFFFFF','#FF0000','#0000FF'],'filament_input_count':'4','ams_slots':'4','enable_support':'1','enable_prime_tower':'1','unknown_new_vendor_key':'keep me'}
sliceinfo='<config><plate><metadata key="index" value="1"/><metadata key="prediction" value="31320"/><metadata key="model_material_g" value="183"/><metadata key="support_material_g" value="22"/><metadata key="purge_material_g" value="71"/><metadata key="prime_tower_g" value="18"/><filament id="1" used_g="294"/></plate><plate><metadata key="index" value="2"/><metadata key="prediction" value="600"/></plate></config>'
for name,app in [('bambu-ams','BambuStudio 2.3.0'),('orca-multiplate','OrcaSlicer 2.3.1'),('anycubic','AnycubicSlicerNext 2.0.0'),('creality','Creality Print 6.0.0')]:write(name,model(app),{'Metadata/project_settings.config':json.dumps(base),'Metadata/slice_info.config':sliceinfo})
write('prusa-xl5',model('PrusaSlicer 2.9.0'),{'Metadata/Slic3r_PE.config':'; printer_model = XL5\n; nozzle_diameter = 0.4,0.4,0.4,0.4,0.4\n; filament_type = PLA;PETG;ABS;ASA;TPU\n; filament_input_count = 5\n; printer_settings_id = Original Prusa XL 5-tool\n'})
for app in ['Cura 5.0.0','FlashPrint 5.0.0','UnknownSlicer 7.0.0']:write(app.split()[0].lower(),model(app),{'Metadata/future.json':'{"newThing":{"evidence":"keep"}}'})
write('generic-inch',model(unit='inch',transform='2 0 0 0 2 0 0 0 2 10 20 30'))
write('mirrored',model(transform='-1 0 0 0 1 0 0 0 1 2 0 0'))
write('cycle',model(resources=obj+'<object id="2"><components><component objectid="2"/></components></object>',build='<item objectid="1"/><item objectid="2"/>'))
write('invalid-object',model(resources=obj+'<object id="2"><mesh>'+verts+'<triangles><triangle v1="99" v2="1" v3="2"/></triangles></mesh></object>',build='<item objectid="1"/><item objectid="2"/>'))
write('invalid-transform',model(build='<item objectid="1" transform="NaN 0 0 0 1 0 0 0 1 0 0 0"/><item objectid="1"/>'))
write('partial',model('OrcaSlicer 2.3.1'),{'Metadata/project_settings.config':'{broken','Metadata/thumb.png':b'not an image'})
write('external-relationship',model(),{'Models/_rels/root.model.rels':'<Relationships><Relationship Id="r2" Type="texture" TargetMode="External" Target="https://example.invalid/private"/></Relationships>'})
write('xxe',model(),{'Metadata/evil.xml':'<!DOCTYPE x [<!ENTITY evil SYSTEM "file:///etc/passwd">]><x>&evil;</x>'})
write('ratio',model(),{'Metadata/padding.bin':b'0'*2000000})
# Real archive with corruption only in the optional thumbnail.
with zipfile.ZipFile(p/'bad-thumbnail.3mf','w',zipfile.ZIP_STORED) as z:
 z.writestr('Metadata/thumbnail.png',b'bad thumbnail');z.writestr('_rels/.rels',rels);z.writestr('Models/root.model',model())
f=p/'bad-thumbnail.3mf';data=bytearray(f.read_bytes());n,x=struct.unpack_from('<HH',data,26);data[30+n+x]^=1;f.write_bytes(data)
# External production resource transforms, without hardcoded 3D/3dmodel.model.
root='<model xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" unit="millimeter"><resources><object id="2"><components><component objectid="1" p:path="/Parts/child.model" transform="1 0 0 0 1 0 0 0 1 10 0 0"/></components></object></resources><build><item objectid="2" transform="1 0 0 0 1 0 0 0 1 0 20 0"/></build></model>'
write('external-component',root,{'Parts/child.model':model()})
# 1-12 toolheads, IDEX and support-interface routing.
for count in [1,2,12]:
 config={'printer_model':'Custom test','physical_toolhead_count':str(count),'nozzle_diameter':['0.4']*count,'filament_input_count':str(count),'tool_architecture':'idex' if count==2 else 'custom','support_material_extruder':'2','support_material_interface_extruder':'1'}
 write('tools-'+str(count),model('PrusaSlicer 2.9.0'),{'Metadata/project_settings.config':json.dumps(config)})
expected={'bambu-ams':{'slicer':'Bambu Studio','physicalToolheads':1,'filamentInputs':4,'materials':4,'plates':2},'prusa-xl5':{'slicer':'PrusaSlicer','physicalToolheads':5,'filamentInputs':5,'materials':5},'generic-inch':{'boundsMinMM':[254,508,762],'dimensionsMM':[50.8,50.8,50.8],'volumeMM3':25.4**3*8/6}}
(p/'golden.json').write_text(json.dumps(expected,indent=2))
for f in p.glob('*.3mf'):shutil.copy2(f,Path('Tests/QuoteTests/Fixtures/ThreeMFV2')/f.name)
# Adversarial/regression fixtures: each keeps the valid tetrahedron where recovery is expected.
write('conflicting-printer',model('OrcaSlicer 99.0.0'),{'Metadata/a.json':'{"printer_model":"P1S","physical_toolhead_count":"1","nozzle_diameter":["0.4"]}','Metadata/b.json':'{"printer_model":"XL5","physical_toolhead_count":"5","nozzle_diameter":["0.6"]}'})
write('overflow-instance',model(build='<item objectid="1" transform="1e200 0 0 0 1e200 0 0 0 1e200 0 0 0"/><item objectid="1"/>'))
write('unknown-namespace',model(resources=obj+'<z:object xmlns:z="urn:unknown" id="88"><z:mesh><z:vertex x="nan"/></z:mesh></z:object>'))
write('duplicate-material',model(resources='<basematerials id="5"><base name="A" displaycolor="#FFFFFF"/></basematerials><basematerials id="5"><base name="B" displaycolor="#000000"/></basematerials>'+obj))
write('path-traversal',model(),{'../escape.txt':'bad'})
write('giant-metadata',model(),{'Metadata/big.txt':'x'*70000})
write('xml-depth',model(),{'Metadata/deep.xml':'<x>'*70+'value'+'</x>'*70})
write('shuffled-metadata',model('OrcaSlicer 2.3.1'),{'Metadata/reordered.config':'<config xmlns:u="urn:future"><u:future meaning="preserve"/><metadata value="P1S" key="printer_model"/><metadata value="0.4" key="nozzle_diameter"/></config>'})
write('plate-alias',model('BambuStudio 2.3.0'),{'Metadata/model_settings.config':'<config><plate><metadata key="plater_id" value="1"/><model_instance><metadata key="object_id" value="1"/></model_instance></plate></config>','Metadata/custom_gcode_per_layer.xml':'<custom_gcodes_per_layer><plate><plate_info id="1"/></plate></custom_gcodes_per_layer>'})
write('metadata-only-job',model('OrcaSlicer 2.3.1',resources='',build=''),{'Metadata/project_settings.config':json.dumps(base),'Metadata/slice_info.config':sliceinfo})
write('gcode-profile',model('BambuStudio 2.3.0',resources='',build=''),{'Metadata/plate_1.gcode':'; filament_type = PETG\n; filament_density = 1.27\n; filament_colour = #FF0000\n; filament_cost = 20\n; filament used [g] = 100\n; estimated printing time (normal mode) = 1h 2m\n'})
for n in range(1,6):
 raw=(p/'bambu-ams.3mf').read_bytes();(p/f'truncated-{n}.3mf').write_bytes(raw[:-n*13])
for f in p.glob('*.3mf'):shutil.copy2(f,ROOT/'Tests/QuoteTests/Fixtures/ThreeMFV2'/f.name)
shutil.copy2(p/'golden.json',ROOT/'Tests/QuoteTests/Fixtures/ThreeMFV2/golden.json')
