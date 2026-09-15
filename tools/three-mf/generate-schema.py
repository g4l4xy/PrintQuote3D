"""Regenerate the portable, typed manufacturing import contract (ISO-8601 dates)."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
shapes={
'DetectedSlicer':'name:string version:string? family:string confidence:ImportConfidence evidence:ValueString[] capabilities:mapString',
'ImportedPrinterConfiguration':'manufacturer:ValueString? model:ValueString? variant:ValueString? presetName:ValueString? presetID:ValueString? profileVersion:ValueString? operatingMode:ValueString?',
'ImportedToolhead':'index:int nozzleDiameterMM:ValueNumber? nozzleMaterial:ValueString?',
'ImportedToolSystem':'physicalToolheads:ValueInt? extruderCount:ValueInt? nozzleCount:ValueInt? filamentInputs:ValueInt? feederSlots:ValueInt? feederType:ValueString? architecture:ValueString? tools:ImportedToolhead[] needsReview:bool',
'ImportedMaterial':'id:string family:ValueString? preset:ValueString? manufacturer:ValueString? productName:ValueString? sourceColorHex:ValueString? normalizedColorHex:string? manufacturerColorName:ValueString? densityGramsPerCM3:ValueNumber? diameterMM:ValueNumber? embeddedSlicerCost:ValueDecimal? temperatures:ValueNumber[] properties:ImportedSetting[]',
'ImportedAssignment':'scope:string role:string materialID:string? toolIndex:int? source:ValueString',
'ImportedSetting':'name:string scope:string source:ValueString',
'ImportedProcessSettings':'settings:ImportedSetting[] purgeSettings:ImportedSetting[]',
'ImportedQuantity':'role:string plateID:string? objectID:string? materialID:string? amount:ValueNumber unit:string',
'ImportedPlate':'id:string name:ValueString? objectIDs:string[] settings:ImportedSetting[] estimates:ImportedQuantity[]',
'ImportedBounds':'minimum:vector3 maximum:vector3',
'ImportedObject':'id:string resourceID:string parentID:string? name:string? role:string sourcePath:string children:string[] triangleCount:int instanceCount:int unit:string sourceTransform:matrix12? boundsMM:ValueBounds? surfaceAreaMM2:ValueNumber? enclosedVolumeMM3:ValueNumber? mirrored:bool?',
'ImportedPrintProject':'filename:string sha256:hash fileSize:int importedAt:date threeMFImporterVersion:string schemaVersion:int slicer:DetectedSlicer printer:ImportedPrinterConfiguration toolSystem:ImportedToolSystem materials:ImportedMaterial[] assignments:ImportedAssignment[] plates:ImportedPlate[] objects:ImportedObject[] processSettings:ImportedProcessSettings estimates:ImportedQuantity[] standardMetadata:UnmappedMetadata[] slicerMetadata:UnmappedMetadata[] unmappedMetadata:UnmappedMetadata[]',
'ImportDiagnostic':'id:uuid severity:ImportSeverity category:string code:string sourcePath:string? message:string',
'UnmappedMetadata':'sourcePath:string namespace:string? scope:string key:string value:string? rawXMLSnippet:string?',
'ImportMatch':'id:uuid name:string quality:string reason:string',
'ConfigurationDifference':'field:string imported:string current:string',
'ThreeMFImportResult':'project:ImportedPrintProject? diagnostics:ImportDiagnostic[] printerMatches:ImportMatch[] materialMatches:mapMatches differences:ConfigurationDifference[] cacheHit:bool stageStatus:mapString',
'ThreeMFImportReference':'sha256:hash filename:string parserVersion:string importedAt:date acceptedFields:string[]',
}
def ref(name):return {'$ref':'#/$defs/'+name}
def typ(t):
 if t.endswith('[]'):return {'type':'array','items':typ(t[:-2])}
 if t in ['vector3','matrix12']:return {'type':'array','items':{'type':'number'},'minItems':3 if t=='vector3' else 12,'maxItems':3 if t=='vector3' else 12}
 if t in ['string','int','number','bool']:return {'type':{'int':'integer','bool':'boolean'}.get(t,t)}
 if t in ['uuid','date']:return {'type':'string','format':'uuid' if t=='uuid' else 'date-time'}
 if t=='hash':return {'type':'string','pattern':'^[a-f0-9]{64}$'}
 if t=='mapString':return {'type':'object','additionalProperties':{'type':'string'}}
 if t=='mapMatches':return {'type':'object','additionalProperties':typ('ImportMatch[]')}
 return ref(t)
defs={}
for name,fields in shapes.items():
 props={};required=[]
 for field in fields.split():
  key,t=field.split(':');optional=t.endswith('?');props[key]=typ(t.rstrip('?'))
  if not optional:required.append(key)
 defs[name]={'type':'object','properties':props,'required':required,'additionalProperties':False}
for name,t in [('ValueString','string'),('ValueNumber','number'),('ValueInt','int'),('ValueDecimal','number'),('ValueBounds','ImportedBounds')]:
 defs[name]={'type':'object','properties':{'value':typ(t),'sourcePath':typ('string'),'metadataKey':typ('string'),'sourceType':ref('ImportSourceType'),'confidence':ref('ImportConfidence')},'required':['value','sourcePath','metadataKey','sourceType','confidence'],'additionalProperties':False}
for name,values in [('ImportConfidence',['high','medium','low','unknown']),('ImportSourceType',['standard3MF','slicerMetadata','printerProfile','filamentProfile','derived','userOverride']),('ImportSeverity',['info','warning','recoverableError','fatalError'])]:defs[name]={'type':'string','enum':values}
defs['ImportedPrintProject']['properties']['schemaVersion']={'const':2}
schema={'$schema':'https://json-schema.org/draft/2020-12/schema','$id':'https://github.com/g4l4xy/PrintQuote3D/raw/refs/heads/codex/model-import/SharedSchemas/three-mf-v2/manufacturing.schema.json','title':'PrintQuote 3MF manufacturing import v2','$comment':'Portable exports use ISO-8601 dates and JSON decimal numbers; implementations must use Decimal for monetary fields. Optional fields are omitted. Internal Swift caches are not this interchange representation. sourceTransform is the composed canonical-mm affine transform, not the unscaled source attribute. Raw source attributes are retained in standardMetadata.','$ref':'#/$defs/ThreeMFImportResult','$defs':defs}
out=ROOT/'SharedSchemas/three-mf-v2';(out/'manufacturing.schema.json').write_text(json.dumps(schema,indent=2)+'\n')
for name in shapes:
 (out/(name+'.schema.json')).write_text(json.dumps({'$schema':schema['$schema'],'title':name,'$ref':'manufacturing.schema.json#/$defs/'+name},indent=2)+'\n')
