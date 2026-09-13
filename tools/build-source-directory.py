from pathlib import Path
import re,json,uuid
p=Path(__file__).resolve().parents[1]; entries=[]
for category,file in [('Filament','filament-data-sources.md'),('Printer','printer-data-sources.md')]:
 s=(p/'docs'/file).read_text()
 for heading,body in re.findall(r'^#{1,2} ([^\n]+)\n(.*?)(?=^#{1,2} |\Z)',s,re.M|re.S):
  urls=list(dict.fromkeys(re.findall(r'https://[^\s`]+',body)))
  if not urls and heading != 'Amazon pricing': continue
  name=re.sub(r'^\d+\. ','',heading)
  priority=1 if 'Open Filament Database' in heading else 2
  entries.append(dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,category+'/'+heading)),name=category+' · '+name,priority=priority,urls=urls,notes=body.strip(),status='Reference directory; see offline catalog status for implemented imports'))
for q in [p/'SharedSchemas/filament_sources_v2.json',p/'Sources/QuoteData/SeedData/filament_sources_v2.json']: q.write_text(json.dumps(dict(schemaVersion=2,sources=entries),indent=2))
print(len(entries),'source groups')
