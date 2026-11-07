"""Reproducible CC0 import. Source topology and rig retained; smooth normals only."""
from pathlib import Path
import json, hashlib, urllib.request, struct, sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/python-libs'))
import numpy as np
MODELS={
 'casual-character':('https://raw.githubusercontent.com/euuuuuuan/fatal-funnel-public/main/packages/renderer/assets/models/quaternius-men/casual-character.glb','ultimatemodularcharacters'),
 'worker':('https://raw.githubusercontent.com/euuuuuuan/fatal-funnel-public/main/packages/renderer/assets/models/quaternius-men/worker.glb','ultimatemodularcharacters'),
 'business-man':('https://raw.githubusercontent.com/nishit47/Blender-Pre-vis-Pipeline---Screenplay-to-Animatic/main/assets/Ultimate%20Modular%20Men%20Pack-glb/Business%20Man.glb','ultimatemodularcharacters'),
 'hoodie-character':('https://raw.githubusercontent.com/nishit47/Blender-Pre-vis-Pipeline---Screenplay-to-Animatic/main/assets/Ultimate%20Modular%20Men%20Pack-glb/Hoodie%20Character.glb','ultimatemodularcharacters'),
 'woman-casual':('https://raw.githubusercontent.com/nishit47/Blender-Pre-vis-Pipeline---Screenplay-to-Animatic/main/assets/Animated%20Women%20Pack-glb/Woman%20Casual.glb','animatedwomen'),
}
def smooth_normals(raw):
    result=bytearray(raw)
    size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);start=20+size+8
    def accessor(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        assert a['componentType']==5126 and a['type']=='VEC3'
        return np.ndarray((a['count'],3),dtype='<f4',buffer=result,offset=start+v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',12),4))
    done=set()
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attributes=primitive['attributes']
            if 'NORMAL' not in attributes or attributes['NORMAL'] in done:continue
            p=accessor(attributes['POSITION']);n=accessor(attributes['NORMAL'])
            _,inverse=np.unique(np.round(p,5),axis=0,return_inverse=True)
            summed=np.zeros((inverse.max()+1,3));np.add.at(summed,inverse,n)
            lengths=np.linalg.norm(summed,axis=1);summed/=np.maximum(lengths[:,None],1e-8)
            n[:]=summed[inverse];done.add(attributes['NORMAL'])
    return bytes(result)
def main():
    entries=[]
    for name,(url,pack) in MODELS.items():
        raw=urllib.request.urlopen(url,timeout=60).read()
        path=ROOT/'game/assets/characters'/f'{name}.glb'
        path.write_bytes(smooth_normals(raw))
        entries.append({'name':name,'author':'Quaternius','license':'CC0-1.0','license_source':f'https://quaternius.com/packs/{pack}.html','download':url,'original_sha256':hashlib.sha256(raw).hexdigest(),'path':str(path.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'modifications':'Smooth vertex normals within each material; runtime metre normalization, clothing and skin palette, blended source animations. Stylized adult models, not photorealistic scans.'})
    (ROOT/'docs/character-provenance.json').write_text(json.dumps(entries,indent=2),encoding='utf8')
    print('Imported',len(entries),'adult character variants')
if __name__=='__main__':main()
