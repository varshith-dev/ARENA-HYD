"""Build auditable, hole-aware render geometry from OSM; never modify OSM itself."""
from pathlib import Path
import sys, json, math, re, collections, hashlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/python-libs'))
import shapely
from shapely.geometry import Polygon, LineString, MultiPolygon, box
from shapely.ops import polygonize, unary_union
from shapely.geometry.polygon import orient
from shapely.strtree import STRtree

A=6378137.0
E2=6.6943799901413165e-3
LAT0,LON0=map(math.radians,(17.4485,78.3825))
def ecef(lat,lon):
    lat,lon=map(math.radians,(lat,lon))
    n=A/math.sqrt(1-E2*math.sin(lat)**2)
    return n*math.cos(lat)*math.cos(lon),n*math.cos(lat)*math.sin(lon),n*(1-E2)*math.sin(lat)
ORIGIN=ecef(17.4485,78.3825)
def project(lat,lon):
    x,y,z=[v-o for v,o in zip(ecef(lat,lon),ORIGIN)]
    east=-math.sin(LON0)*x+math.cos(LON0)*y
    north=-math.sin(LAT0)*math.cos(LON0)*x-math.sin(LAT0)*math.sin(LON0)*y+math.cos(LAT0)*z
    return round(east,3),round(-north,3)
def number(value,default=0):
    match=re.search(r'-?\d+(?:\.\d+)?',str(value or ''))
    if not match:return default
    n=float(match.group())
    return n*0.3048 if 'ft' in str(value) or "'" in str(value) else n
def polys(geometry):
    if geometry.is_empty:return []
    if geometry.geom_type=='Polygon':return [geometry]
    return [p for g in getattr(geometry,'geoms',[]) for p in polys(g)]
def points(geom):return [project(p['lat'],p['lon']) for p in geom if 'lat' in p and 'lon' in p]
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))

def prepare():
    source=ROOT/'game/data/hitec-city.osm.json'
    data=read(source)
    profiles=read(ROOT/'game/data/building-profiles.json')
    elements=data['elements']
    stats=collections.Counter()
    rejected=[]
    records=[]
    consumed=set()
    bounds=box(-1858,-2282,2497,2617)
    def reject(key,reason):
        stats[reason]+=1
        rejected.append({'id':key,'reason':reason})
    def add(element,poly):
        tags=element.get('tags',{})
        key=f"{element['type']}/{element['id']}"
        if key in profiles.get('exclude',{}):reject(key,'explicit_exclusion');return
        if tags.get('building')=='no' or tags.get('building:part')=='no':reject(key,'not_a_building');return
        if tags.get('demolished')=='yes' or tags.get('razed')=='yes' or tags.get('building') in ['demolished','razed','proposed']:reject(key,'not_existing');return
        if tags.get('station')=='subway' or tags.get('building')=='train_station' and 'Metro' in tags.get('network',''):reject(key,'replaced_by_existing_metro_station');return
        if not poly.is_valid:
            poly=shapely.make_valid(poly)
            stats['repaired_invalid_geometry']+=1
        for index,part in enumerate(polys(poly)):
            if part.area<2:reject(key,'degenerate_footprint');continue
            if not bounds.intersects(part):reject(key,'outside_district');continue
            records.append({'key':key,'fragment':index,'id':element['id'],'type':element['type'],'tags':tags,'poly':orient(part,sign=-1)})
    # Assemble multipolygon rings before processing member ways.
    for element in elements:
        tags=element.get('tags',{})
        if element['type']!='relation' or not ('building' in tags or 'building:part' in tags):continue
        outer=[];inner=[];members=[]
        for m in element.get('members',[]):
            pts=points(m.get('geometry',[]))
            if len(pts)<2:continue
            (inner if m.get('role')=='inner' else outer).append(LineString(pts))
            members.append(m.get('ref'))
        if not outer:reject(f"relation/{element['id']}",'missing_outer_geometry');continue
        shells=list(polygonize(unary_union(outer)))
        holes=list(polygonize(unary_union(inner))) if inner else []
        if not shells:reject(f"relation/{element['id']}",'open_relation_ring');continue
        geometry=unary_union(shells)
        if holes:geometry=geometry.difference(unary_union(holes))
        add(element,geometry)
        consumed.update(members)
        stats['assembled_building_relations']+=1
    for element in elements:
        tags=element.get('tags',{})
        if element['type']!='way' or not ('building' in tags or 'building:part' in tags):continue
        if element['id'] in consumed:reject(f"way/{element['id']}",'relation_member_not_extruded_twice');continue
        pts=points(element.get('geometry',[]))
        if len(pts)<4 or math.dist(pts[0],pts[-1])>0.25:reject(f"way/{element['id']}",'open_or_missing_footprint');continue
        add(element,Polygon(pts))
    # Exact duplicate outlines are safe to discard. Different building parts are not.
    unique={};clean=[]
    for record in records:
        t=record['tags'];poly=record['poly']
        key=(shapely.normalize(shapely.set_precision(poly,0.02)).wkb,t.get('min_height','0'),t.get('height',''),t.get('building:part',''))
        if key in unique:reject(record['key'],'duplicate_footprint');continue
        unique[key]=record['key'];clean.append(record)
    part_geoms=[r['poly'] for r in clean if r['tags'].get('building:part') not in [None,'no']]
    part_union=unary_union(part_geoms) if part_geoms else None
    prepared=[]
    for r in clean:
        tags=r['tags'];poly=r['poly'];profile=profiles['profiles'].get(r['key'],{})
        if part_union is not None and 'building:part' not in tags and poly.intersection(part_union).area/poly.area>.97:
            reject(r['key'],'outline_replaced_by_building_parts');continue
        kind=tags.get('building','yes')
        levels=number(tags.get('building:levels'))
        height=number(tags.get('height'))
        source_height='osm_height' if height else 'osm_levels' if levels else 'reference_estimate' if profile.get('levels_estimate') else 'conservative_estimate'
        if not levels:
            levels=profile.get('levels_estimate',1 if kind in ['shed','roof','garage','cowshed'] else 4 if kind in ['apartments','office','commercial'] or tags.get('office') else 2 if poly.area<100 else 3)
        if not height:height=levels*3.2
        minimum=number(tags.get('min_height'),number(tags.get('building:min_level'))*3.2)
        if kind=='roof':minimum=max(minimum,3.0);height=max(height,minimum+0.28)
        height=max(minimum+0.25,min(height,220))
        style=profile.get('style')
        if not style:
            if kind=='construction':style='construction'
            elif kind in ['roof','shed','garage','warehouse']:style='canopy' if kind=='roof' else 'service'
            elif kind in ['office','commercial'] or tags.get('office'):style='office'
            elif kind in ['school','hospital'] or tags.get('amenity') in ['school','college','hospital']:style='campus'
            elif tags.get('shop') or kind=='retail':style='retail'
            else:style='residential'
        rings=[list(poly.exterior.coords)[:-1]]+[list(i.coords)[:-1] for i in poly.interiors]
        triangles=shapely.constrained_delaunay_triangles(poly)
        triangle_area=sum(t.area for t in triangles.geoms)
        if abs(triangle_area-poly.area)>max(.01,poly.area*.00001):raise ValueError('Roof triangulation does not preserve footprint area: '+r['key'])
        stats['courtyards_preserved']+=len(poly.interiors)
        stats['height_'+source_height]+=1
        stats['style_'+style]+=1
        center=poly.centroid
        prepared.append({'key':r['key'],'id':r['id'],'osm_type':r['type'],'fragment':r['fragment'],'name':profile.get('label',tags.get('name','')),'rings':rings,'roof':[list(t.exterior.coords)[:3] for t in triangles.geoms],'center':[round(center.x,3),round(center.y,3)],'height':round(height,3),'min_height':round(minimum,3),'levels':int(levels),'height_source':source_height,'style':style,'reference':profile.get('reference',''),'shop_sign':profile.get('shop_sign',''),'area':round(poly.area,2)})
    stats['render_buildings']=len(prepared)
    report={'osm_timestamp':data.get('osm3s',{}).get('timestamp_osm_base'),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'projection':'WGS84 ECEF to local east/north; origin 17.4485,78.3825; Godot z=-north','origin_ecef':ORIGIN,'statistics':dict(stats),'excluded':rejected}
    output={'metadata':report,'buildings':prepared}
    (ROOT/'game/data/hitec-city.render.json').write_text(json.dumps(output,separators=(',',':')),encoding='utf-8')
    (ROOT/'docs/map-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report['statistics'],indent=2),flush=True)
    print('ECEF origin:',ORIGIN,flush=True)

if __name__=='__main__':prepare()
