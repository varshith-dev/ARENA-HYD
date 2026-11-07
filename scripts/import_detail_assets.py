"""Import licensed source materials; preserve their source and content hashes."""
from pathlib import Path
import json, shutil, urllib.request, hashlib, concurrent.futures

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'metaverse'
OUT = ROOT / 'game/assets/materials'
OUT.mkdir(parents=True, exist_ok=True)
manifest = []
for item in json.loads((SOURCE / 'docs/asset-provenance.json').read_text()):
    if item.get('name') not in ['stone', 'plaster', 'asphalt', 'paving', 'brick', 'ground', 'sky'] and not any('deccan_sky' in f.get('path','') for f in item.get('files',[])):
        continue
    entry = dict(item)
    for f in entry.get('files', []):
        src = SOURCE / f['path'].replace('\\','/')
        dst = ROOT / f['path'].replace('\\','/')
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        f['sha256'] = hashlib.sha256(dst.read_bytes()).hexdigest()
    manifest.append(entry)

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent':'ArenaHyderabad/0.2 (local asset import; Powered by Poly Haven)'})
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read()

def material(pair):
    name, asset = pair
    data = json.loads(fetch('https://api.polyhaven.com/files/' + asset))
    entry = {'name':name, 'asset':asset, 'source':'https://polyhaven.com/a/'+asset, 'license':'CC0-1.0', 'resolution':'2k', 'files':[]}
    for channel, suffix in [('Diffuse','albedo'),('nor_gl','normal'),('Rough','rough')]:
        item = data[channel]['2k']['jpg']
        dst = OUT / (name+'_'+suffix+'.jpg')
        payload = fetch(item['url'])
        dst.write_bytes(payload)
        entry['files'].append({'path':dst.relative_to(ROOT).as_posix(),'url':item['url'],'sha256':hashlib.sha256(payload).hexdigest()})
    print('Imported 2k material:', asset, flush=True)
    return entry

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    for item in pool.map(material, [('concrete','concrete_wall_001'),('stone','sandstone_blocks_04'),('asphalt','asphalt_03')]):
        manifest = [m for m in manifest if m.get('name') != item['name']]
        manifest.append(item)
(ROOT/'docs').mkdir(exist_ok=True)
(ROOT/'docs/asset-provenance.json').write_text(json.dumps(manifest,indent=2))
print('Asset manifest written', flush=True)

