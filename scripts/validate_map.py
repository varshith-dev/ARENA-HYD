"""Independent geometric checks against the prepared district and WGS84 controls."""
from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/python-libs'))
from shapely.geometry import Polygon
from shapely.ops import unary_union
from pyproj import Transformer
from prepare_map import project
data=json.loads((ROOT/'game/data/hitec-city.render.json').read_text())
transform=Transformer.from_pipeline('+proj=pipeline +step +proj=cart +ellps=WGS84 +step +proj=topocentric +ellps=WGS84 +lat_0=17.4485 +lon_0=78.3825 +h_0=0')
for lat,lon in [(17.4485,78.3825),(17.4500177,78.3795362),(17.4447356,78.3772674),(17.425,78.406)]:
    east,north,up=transform.transform(lon,lat,0)
    assert math.dist(project(lat,lon),(east,-north))<.001, 'ENU projection disagrees with PROJ'
holes=0;seen=set()
for item in data['buildings']:
    identifier=(item['key'],item['fragment']);assert identifier not in seen;seen.add(identifier)
    polygon=Polygon(item['rings'][0],item['rings'][1:])
    assert polygon.is_valid and item['height']>item['min_height']>=0
    assert not polygon.exterior.is_ccw,'Outward wall orientation'
    roof=[Polygon(t) for t in item['roof']]
    assert abs(sum(t.area for t in roof)-polygon.area)<max(.01,polygon.area*.00001)
    if polygon.interiors:
        union=unary_union(roof)
        assert union.symmetric_difference(polygon).area<.01,'Roof covers a courtyard'
        holes+=len(polygon.interiors)
    if item['style']=='canopy':assert item['min_height']>=3
    if item['reference'].endswith('.png'):assert (ROOT/'hyd-images'/item['reference']).is_file(),item['reference']
assert not any(item['id']==854204711 for item in data['buildings']), 'Duplicate Raidurg station block'
assert holes==data['metadata']['statistics']['courtyards_preserved']
assert next(b for b in data['buildings'] if b['id']==68883448)['style']=='cyber_towers'
assert {68883415,416945180,89914112,89914725,596783347}.issubset({b['id'] for b in data['buildings']})
print(f'MAP CHECKS PASSED: PROJ control points, {len(seen)} footprints, {holes} open courtyards, roof coverage, heights, source photos, preserved landmarks.')
