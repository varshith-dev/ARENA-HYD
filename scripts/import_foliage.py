from pathlib import Path
import urllib.request, json, concurrent.futures, hashlib
ROOT = Path(__file__).resolve().parents[1]
def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'ArenaHyderabad/0.2 (Powered by Poly Haven)'}),timeout=90).read()
jobs=[]
asset='shrub_01'
data=json.loads(fetch('https://api.polyhaven.com/files/'+asset))['gltf']['1k']['gltf']
base=ROOT/'game/assets/foliage'/asset
jobs.append((base/(asset+'.gltf'),data['url']))
jobs += [(base/path,entry['url']) for path,entry in data['include'].items()]
tree_files=json.loads(fetch('https://api.polyhaven.com/files/tree_small_02'))['blend']['1k']['blend']['include']
branch=tree_files['textures/tree_small_02_branch_diff_1k.png']
jobs.append((ROOT/'game/assets/foliage/branch.png',branch['url']))
jobs.append((ROOT/'game/assets/foliage/leaves.png',tree_files['textures/tree_small_02_leaves_diff_1k.png']['url']))
jobs.append((ROOT/'game/assets/foliage/leaves_alpha.png',tree_files['textures/tree_small_02_leaves_alpha_1k.png']['url']))
def save(job):
    path,url=job
    path.parent.mkdir(parents=True,exist_ok=True)
    payload=fetch(url)
    path.write_bytes(payload)
    print('Imported',path.name,flush=True)
    return {'path':path.relative_to(ROOT).as_posix(),'url':url,'sha256':hashlib.sha256(payload).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(4) as pool: files=list(pool.map(save,jobs))
(ROOT/'docs/foliage-provenance.json').write_text(json.dumps({'license':'CC0-1.0','author':'Poly Haven contributors','sources':['https://polyhaven.com/a/shrub_01','https://polyhaven.com/a/tree_small_02'],'files':files},indent=2))
