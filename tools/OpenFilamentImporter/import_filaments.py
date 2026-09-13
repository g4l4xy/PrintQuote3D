"""Normalize a local OFD bulk export. No network access or retail price inference."""
import argparse, hashlib, json
from datetime import datetime, timezone
from pathlib import Path

RENAMES = {'density':'density_g_cm3','min_print_temperature':'nozzle_min_c','max_print_temperature':'nozzle_max_c','min_bed_temperature':'bed_min_c','max_bed_temperature':'bed_max_c','diameter_tolerance':'diameter_tolerance_mm','filament_weight':'net_weight_g','empty_spool_weight':'empty_spool_weight_g','spool_core_diameter':'spool_core_diameter_mm','spool_outer_diameter':'spool_outer_diameter_mm','spool_width':'spool_width_mm','diameter':'diameter_mm'}
SKIP={'uuid','id','brand_id','material_id','filament_id','variant_id','slug','name','material','source'}
def fields(row, table):
    return {RENAMES.get(k,k):dict(value=json.dumps(v,ensure_ascii=False) if not isinstance(v,str) else v,sourcePath=f'{table}/{row["id"]}/{k}',sourcePriority=3,userOverride=False) for k,v in row.items() if k not in SKIP and v is not None}
def normalize(data, sha):
    brands={x['id']:x for x in data['brands']}; materials={x['id']:x for x in data['materials']}
    variants={}; sizes={}; links={}
    for x in data['purchase_links']: links.setdefault(x['size_id'],[]).append(x['url'])
    for x in data['sizes']:
        sizes.setdefault(x['variant_id'],[]).append(dict(id=x['id'],diameterMM=x.get('diameter'),netWeightGrams=x.get('filament_weight'),fields=fields(x,'sizes'),purchaseURLs=links.get(x['id'],[])))
    for x in data['variants']:
        variants.setdefault(x['filament_id'],[]).append(dict(id=x['id'],name=x.get('name','Unknown color'),colorHex=x.get('color_hex'),fields=fields(x,'variants'),sizes=sizes.get(x['id'],[])))
    products=[]
    for x in data['filaments']:
        brand=brands[x['brand_id']]; material=materials[x['material_id']]
        products.append(dict(id=x['id'],brand=brand['name'],name=x.get('name','Unnamed filament'),materialFamily=x.get('material',material.get('material','Unknown')),fields=fields(material,'materials')|fields(x,'filaments'),variants=variants.get(x['id'],[])))
    assert len({x['id'] for x in products}) == len(products)
    return dict(schemaVersion=2,sourceName='Open Filament Database',sourceURL='https://api.openfilamentdatabase.org/json/all.json',sourceLicense='MIT',upstreamVersion=data['version'],generatedAt=data['generated_at'],retrievedAt=datetime.now(timezone.utc).isoformat(),sha256=sha,products=products)
if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('input'); parser.add_argument('output'); args=parser.parse_args()
    raw=Path(args.input).read_bytes(); result=normalize(json.loads(raw),hashlib.sha256(raw).hexdigest())
    Path(args.output).write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print(f'Normalized {len(result["products"])} products, {sum(len(x["variants"]) for x in result["products"])} variants')
