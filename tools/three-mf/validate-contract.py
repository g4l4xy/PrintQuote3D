"""Validate every synthetic normalized export against the portable JSON Schema.
Requires jsonschema==4.25.1 and a built ThreeMFProbe. --write-goldens refreshes portable examples.
"""
from pathlib import Path
import json,subprocess,sys
from jsonschema import Draft202012Validator,FormatChecker
ROOT=Path(__file__).resolve().parents[2];fixtures=ROOT/'SharedSchemas/three-mf-v2'
schema=json.loads((fixtures/'manufacturing.schema.json').read_text());Draft202012Validator.check_schema(schema)
validator=Draft202012Validator(schema,format_checker=FormatChecker())
count=0
for file in sorted(fixtures.glob('*.3mf')):
 result=json.loads(subprocess.check_output([str(ROOT/'.build/debug/ThreeMFProbe'),str(file),'--normalized'],text=True))
 validator.validate(result);count+=1
 if '--write-goldens' in sys.argv and file.stem in ['bambu-ams','prusa-xl5','generic-inch','plate-alias']:
  if result.get('project'):result['project']['importedAt']='2026-09-15T00:00:00Z'
  for index,diagnostic in enumerate(result['diagnostics']):diagnostic['id']=f'00000000-0000-0000-0000-{index:012d}'
  (fixtures/(file.stem+'.normalized.json')).write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(f'Validated {count} normalized fixture results, including fatal and partial results.')
