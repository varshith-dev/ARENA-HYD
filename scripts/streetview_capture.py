"""Capture public Street View reference angles with coordinates and OSM candidates.

Uses the supported Maps URL scheme and a visible, isolated Chrome context.
Never reads private Google APIs or downloads panorama tile collections.
"""
from __future__ import annotations
from pathlib import Path
import argparse, csv, datetime as dt, io, json, math, re, sys, time
from urllib.parse import urlencode, unquote
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/python-libs'))
from prepare_map import project

DEFAULT_ROUTE=[
    {'label':'HITEC City station','lat':17.4490055,'lon':78.3831376},
    {'label':'Cyber Towers northeast','lat':17.4509238,'lon':78.3818386},
    {'label':'Trident frontage','lat':17.4500177,'lon':78.3795362},
    {'label':'Motorola junction','lat':17.4479,'lon':78.3777},
    {'label':'Cyber Pearl and HDFC Bank','lat':17.446125,'lon':78.377562},
    {'label':'Deccan Park','lat':17.4447356,'lon':78.3772674},
    {'label':'Raidurg station','lat':17.44218,'lon':78.3772038},
]
def maps_url(lat,lon,heading,pitch,fov):
    return 'https://www.google.com/maps/@?'+urlencode({'api':1,'map_action':'pano','viewpoint':f'{lat:.7f},{lon:.7f}','heading':heading%360,'pitch':pitch,'fov':fov})
def resolved_pose(url):
    """Read only the public address-bar pose; missing values remain unknown."""
    # Google can serialize the same public panorama using 3a or 600a.
    match=re.search(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),\d+a,([^/]+)',unquote(url))
    if not match:return None
    values={}
    for value,suffix in re.findall(r'(-?\d+(?:\.\d+)?)([yht])',match[3]):values[suffix]=float(value)
    pano=re.search(r'!1s([^!/?]+)',unquote(url))
    if not pano:return None
    return {'lat':float(match[1]),'lon':float(match[2]),'heading':values.get('h'),'pitch':None if 't' not in values else values['t']-90,'url_fov':values.get('y'),'panorama_id':pano[1] if pano else None,'source':'public_address_bar'}
def angle_delta(a,b):return (a-b+180)%360-180
def rendered_image(png):
    """Reject black/blank WebGL frames without removing any attribution."""
    from PIL import Image,ImageStat
    image=Image.open(io.BytesIO(png)).convert('RGB')
    w,h=image.size;sample=image.crop((w*.2,h*.2,w*.8,h*.8)).resize((96,54))
    pixels=list(sample.getdata());dark=sum(max(pixel)<14 for pixel in pixels)/len(pixels)
    return dark<.95 and max(ImageStat.Stat(sample).stddev)>8
def candidate_buildings(buildings,lat,lon,heading,fov):
    from shapely.geometry import Polygon,Point
    origin=project(lat,lon);camera=Point(origin);result=[]
    for b in buildings:
        dx=b['center'][0]-origin[0];dz=b['center'][1]-origin[1]
        if dx*dx+dz*dz>220**2:continue
        polygon=Polygon(b['rings'][0],b['rings'][1:])
        distance=polygon.distance(camera)
        bearing=math.degrees(math.atan2(dx,-dz))%360
        delta=abs(angle_delta(bearing,heading))
        if distance>150 or delta>fov/2+20:continue
        result.append({'id':b['key'],'name':b['name'],'distance_to_footprint_m':round(distance,2),'bearing_deg':round(bearing,2),'view_angle_delta_deg':round(delta,2),'height_source':b['height_source'],'status':'candidate_only_not_an_identification'})
    return sorted(result,key=lambda b:b['distance_to_footprint_m']+b['view_angle_delta_deg']*.5)[:12]
def route_points(args):
    points=DEFAULT_ROUTE
    if args.coords:
        with Path(args.coords).open(encoding='utf-8-sig',newline='') as f:points=list(csv.DictReader(f))
    points=[{'lat':float(p['lat']),'lon':float(p['lon']),'label':p.get('label','Reference')} for p in points]
    for p in points:
        if not -90<=p['lat']<=90 or not -180<=p['lon']<=180:raise ValueError('Invalid WGS84 coordinate')
    if args.spacing:
        samples=[]
        for a,b in zip(points,points[1:]):
            length=math.dist(project(a['lat'],a['lon']),project(b['lat'],b['lon']))
            count=max(1,math.ceil(length/args.spacing))
            for i in range(count):samples.append({'lat':a['lat']+(b['lat']-a['lat'])*i/count,'lon':a['lon']+(b['lon']-a['lon'])*i/count,'label':a['label']})
        points=samples+[points[-1]]
    return points
def atomic_json(path,data):
    temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf8');temporary.replace(path)
def write_index(output,records):
    import html
    cards=[]
    for record in records:
        file=record.get('file')
        if not file:continue
        r=record['requested'];pose=record.get('resolved') or {}
        nearby='; '.join(f"{b['id']} {b['name']} ({b['distance_to_footprint_m']} m)" for b in record.get('osm_candidates',[])[:4])
        cards.append(f'<article><a href="{html.escape(file)}"><img loading="lazy" src="{html.escape(file)}"></a><h3>{html.escape(record["label"])}</h3><p>{r["lat"]:.7f}, {r["lon"]:.7f} · heading {r["heading"]}° · {html.escape(record["status"])}</p><p>Panorama location: {html.escape(str(pose.get("lat","unknown")))}, {html.escape(str(pose.get("lon","unknown")))}</p><p>{html.escape(nearby)}</p><a href="{html.escape(record["final_url"])}">Open original view</a></article>')
    (output/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>HITEC City reference atlas</title><style>body{font:15px system-ui;background:#13202a;color:#e4ebef;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:20px}article{background:#21323e;padding:14px}img{width:100%;height:auto}a{color:#99d4e6}p{line-height:1.5}</style><h1>HITEC City reference atlas</h1><p>Original viewer screenshots retain attribution. Nearby buildings are review candidates, not automatic facade identifications.</p><main>'+''.join(cards)+'</main>',encoding='utf8')
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--coords',help='CSV with lat,lon,label columns; defaults to the supplied HITEC City–Raidurg reference route')
    parser.add_argument('--output',type=Path,default=ROOT/'hyd-images/auto-streetview')
    parser.add_argument('--headings',default='0,90,180,270')
    parser.add_argument('--pitch',type=float,default=10)
    parser.add_argument('--fov',type=float,default=75)
    parser.add_argument('--spacing',type=float,help='Optional sampling interval in metres between route coordinates')
    parser.add_argument('--limit',type=int,default=28,help='Maximum captures this run; zero means all planned views')
    parser.add_argument('--settle',type=float,default=5,help='Seconds for panorama imagery to finish loading')
    parser.add_argument('--headless',action='store_true')
    parser.add_argument('--plan-only',action='store_true')
    parser.add_argument('--browser',choices=['chrome','msedge'],default='chrome')
    parser.add_argument('--max-gb',type=float,default=1.5,help='Capture folder storage ceiling')
    args=parser.parse_args()
    if args.spacing is not None and args.spacing<10:parser.error('--spacing must be at least 10 m')
    if not -90<=args.pitch<=90 or not 10<=args.fov<=100:parser.error('Pitch must be -90..90, fov 10..100')
    headings=[float(v)%360 for v in args.headings.split(',')]
    points=route_points(args);output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    plan=[]
    for point in points:
        for heading in headings:
            request={**point,'heading':heading,'pitch':args.pitch,'fov':args.fov}
            plan.append({'requested':request,'url':maps_url(point['lat'],point['lon'],heading,args.pitch,args.fov)})
    atomic_json(output/'capture-plan.json',plan)
    print(f'Planned {len(plan)} views in {output}',flush=True)
    if args.plan_only:return
    from playwright.sync_api import sync_playwright,TimeoutError as BrowserTimeout
    buildings=json.loads((ROOT/'game/data/hitec-city.render.json').read_text())['buildings']
    manifest_path=output/'manifest.json'
    manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'format_version':1,'purpose':'local visual modelling references, not exported game textures','records':[]}
    records=manifest['records'];done={r['requested_url'] for r in records if r.get('status')=='captured' and (output/r.get('file','missing')).is_file()}
    count=0
    with sync_playwright() as pw:
        browser=pw.chromium.launch(channel=args.browser,headless=args.headless)
        context=browser.new_context(viewport={'width':1920,'height':1080},device_scale_factor=1,locale='en-IN')
        page=context.new_page()
        for task in plan:
            if task['url'] in done:continue
            if args.limit and count>=args.limit:break
            if sum(p.stat().st_size for p in output.rglob('*') if p.is_file())>args.max_gb*1e9:print('Capture storage ceiling reached',flush=True);break
            requested=task['requested'];folder=output/f"{requested['lat']:.7f}_{requested['lon']:.7f}";folder.mkdir(exist_ok=True)
            record={'requested':requested,'label':requested['label'],'requested_url':task['url'],'captured_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'viewport':{'width':1920,'height':1080,'device_scale_factor':1},'status':'pending'}
            try:
                page.goto(task['url'],wait_until='domcontentloaded',timeout=45000)
                # Consent/login/security barriers are left for the user; never bypass them.
                page.wait_for_timeout(max(1,args.settle)*1000)
                body=page.locator('body').inner_text(timeout=5000)
                if any(s in page.url for s in ['consent.google','accounts.google','/sorry/']):
                    record['status']='needs_user_attention';record['reason']='Google displayed consent, sign-in or an access challenge. No bypass attempted.'
                else:
                    try:page.wait_for_url(re.compile(r'.*/@-?\d+\.\d+,-?\d+\.\d+,\d+a,.*'),timeout=15000)
                    except BrowserTimeout:pass
                    resolved=resolved_pose(page.url);record['resolved']=resolved
                    canvases=page.locator('canvas').count()
                    visual_ready=False
                    for retry in range(4):
                        visual_ready=rendered_image(page.screenshot(full_page=False))
                        if visual_ready:break
                        page.wait_for_timeout(3000)
                    record['visual_frame_check']='passed' if visual_ready else 'blank_or_unloaded'
                    record['status']='captured' if resolved and canvases and visual_ready else 'unverified_view'
                    if record['status']!='captured':record['reason']='A Street View address-bar pose and rendered canvas could not both be confirmed. Do not use for automatic alignment.'
                    location=resolved or requested
                    record['panorama_offset_m']=round(math.dist(project(requested['lat'],requested['lon']),project(location['lat'],location['lon'])),2) if resolved else None
                    record['osm_candidates']=candidate_buildings(buildings,location['lat'],location['lon'],location.get('heading') if location.get('heading') is not None else requested['heading'],requested['fov'])
                    record['alignment_status']='review_required' if not resolved or record['panorama_offset_m']>25 else 'public_pose_available_review_facade_identity'
                    record['visible_capture_date']=re.findall(r'(?:Image capture|Imagery date|Captured)\s*:?\s*([^\n]+)',body,re.I)[:2]
                filename=f"heading_{requested['heading']:06.1f}_pitch_{requested['pitch']:+05.1f}.png"
                if record['status']!='captured':filename='CHECK_'+filename
                path=folder/filename;page.screenshot(path=str(path),full_page=False,animations='disabled')
                record['file']=path.relative_to(output).as_posix()
            except Exception as error:
                record['status']='failed';record['reason']=str(error)[:600]
            record['final_url']=page.url;records.append(record);count+=1
            atomic_json(manifest_path,manifest);write_index(output,records)
            print(f"{count}: {record['status']} · {record['label']} · heading {requested['heading']}",flush=True)
            if record['status']=='needs_user_attention':break
            page.wait_for_timeout(2000)
        context.close();browser.close()
    print('Saved manifest and review atlas:',output/'index.html',flush=True)
    if count and all(r['status']!='captured' for r in records[-count:]):sys.exit(2)
if __name__=='__main__':main()
