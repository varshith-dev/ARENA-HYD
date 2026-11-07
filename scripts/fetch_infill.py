"""Extract imagery-derived building outlines for this district, without changing OSM."""
from pathlib import Path
import urllib.request, json, gzip, hashlib
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'docs/infill-download.json').read_text())
features=[]
for tile in manifest['tiles']:
    cache=ROOT/'tools/map-cache'/f"microsoft-{tile['QuadKey']}.geojsonl.gz"
    cache.parent.mkdir(parents=True,exist_ok=True)
    if not cache.exists():
        temporary=cache.with_suffix('.download')
        # Direct blob endpoint is equivalent to Azure's static-site host, which
        # can stall on this network. Preserve both addresses for provenance.
        tile['download_url']=tile['Url'].replace('bfppub.z5.web.core.windows.net/','bfppub.blob.core.windows.net/%24web/')
        with urllib.request.urlopen(tile['download_url'],timeout=40) as response,temporary.open('wb') as out:
            while block:=response.read(1024*1024):out.write(block)
        temporary.replace(cache)
    scanned=0
    with gzip.open(cache,'rt',encoding='utf8') as stream:
        for line in stream:
            scanned+=1
            f=json.loads(line);g=f.get('geometry',{})
            if g.get('type')!='Polygon':continue
            points=g['coordinates'][0]
            if not any(78.365<=p[0]<=78.406 and 17.425<=p[1]<=17.469 for p in points):continue
            f['source_id']=f"ms-{tile['QuadKey']}-{scanned}"
            features.append(f)
    tile['sha256']=hashlib.sha256(cache.read_bytes()).hexdigest()
    tile['records_scanned']=scanned
    print(tile['QuadKey'],'scanned',scanned,'district candidates',len(features),flush=True)
metadata={'provider':'Microsoft Global ML Building Footprints','license':'CDLA-Permissive-2.0','license_url':'https://cdla.dev/permissive-2-0/','source':'https://github.com/microsoft/GlobalMLBuildingFootprints','index':manifest['index'],'tiles':manifest['tiles'],'limitations':'Imagery-derived detections, not surveyed current buildings. Imagery dates vary (global release describes 2014–2024); the tile upload date is not a construction date. OSM and exclusions take priority.'}
(ROOT/'game/data/hitec-city.infill.geojson').write_text(json.dumps({'type':'FeatureCollection','metadata':metadata,'features':features},separators=(',',':')),encoding='utf8')
(ROOT/'docs/infill-provenance.json').write_text(json.dumps(metadata,indent=2),encoding='utf8')
print('Saved district-only candidate dataset',flush=True)
