class_name HitecCity
extends Node3D
signal build_progress(percent: int)

const ORIGIN_LAT := 17.4485
const ORIGIN_LON := 78.3825
const M_LAT := 111320.0
const M_LON := 106195.0
const CELL := 250.0
const METRO_PRIMARY := [611277269,678467538,722495017,755364263]
var roads: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var chunks: Dictionary = {}
var batches: Dictionary = {}
var solid_faces: Dictionary = {}
var collision_bodies: Array[StaticBody3D] = []
var collision_triangles := 0
var materials: Dictionary = {}
var bounds := Rect2(Vector2(-1858,-2282),Vector2(4355,4899))
var source_features := 0
var mapped_buildings := 0
var landmark_names: Array[String] = []
var facade_materials: Array[ShaderMaterial] = []
var decor_cells: Dictionary = {}
var data: Dictionary = {}
var places: Array[Dictionary] = []
var pillar_cells: Dictionary = {}
var detailed_buildings := 0
var metro_segments: Array[Dictionary] = []
var metro_frames: Dictionary = {}
var pillar_positions: Array[Vector3] = []
var signs: Array[Dictionary] = []
var cache_signature := ""
const CACHE_PATH := "user://city-detail-cache.bin"

static func project(lat: float, lon: float) -> Vector3:
	# WGS84 ECEF -> local east/north. Keep ECEF arithmetic in scalar doubles:
	# a Vector3 at Earth-radius magnitudes would lose sub-metre precision.
	var phi := deg_to_rad(lat)
	var lambda := deg_to_rad(lon)
	var phi0 := deg_to_rad(ORIGIN_LAT)
	var lambda0 := deg_to_rad(ORIGIN_LON)
	var n := 6378137.0/sqrt(1.0-0.0066943799901413165*pow(sin(phi),2))
	var dx := n*cos(phi)*cos(lambda)-1225679.9044351634
	var dy := n*cos(phi)*sin(lambda)-5961801.667157124
	var dz := n*(1.0-0.0066943799901413165)*sin(phi)-1900243.5170219126
	return Vector3(-sin(lambda0)*dx+cos(lambda0)*dy,0,sin(phi0)*cos(lambda0)*dx+sin(phi0)*sin(lambda0)*dy-cos(phi0)*dz)

func build() -> void:
	_prepare_materials()
	_ground()
	cache_signature = "hyderabad-solid-city-v5"+FileAccess.get_sha256("res://data/hitec-city.osm.json")+FileAccess.get_sha256("res://data/hitec-city.render.json")
	if FileAccess.file_exists("res://scripts/city.gd"):
		cache_signature += FileAccess.get_sha256("res://scripts/city.gd")+FileAccess.get_sha256("res://scripts/cyber_towers.gd")
		cache_signature += FileAccess.get_sha256("res://scripts/hyderabad_buildings.gd")
	if _read_cache():
		build_progress.emit(90)
		await get_tree().process_frame
		_commit_batches()
		print("OSM city restored from mesh cache: ",mapped_buildings," buildings")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/hitec-city.osm.json"))
	if not parsed is Dictionary or not parsed.has("elements"):
		push_error("A complete OpenStreetMap snapshot is required. Run scripts/fetch-map.ps1.")
		return
	data = parsed
	source_features = data.elements.size()
	var elements: Array = data.elements.duplicate()
	for element in data.elements:
		if element.get("tags",{}).get("railway","") == "subway" and element.has("geometry"):
			var points: Array = element.geometry
			for i in points.size()-1:
				metro_segments.append({"id":int(element.id),"a":project(points[i].lat,points[i].lon),"b":project(points[i+1].lat,points[i+1].lon)})
	# Shared tangent frames close the inside and outside of each curved deck joint.
	for segment in metro_segments:
		if segment.id not in METRO_PRIMARY: continue
		var pa: Vector3 = _pair_point(segment.a,segment.id).position
		var pb: Vector3 = _pair_point(segment.b,segment.id).position
		var tangent := (pb-pa).normalized()
		for point: Vector3 in [segment.a,segment.b]:
			var frame_key := Vector2i(roundi(point.x*100),roundi(point.z*100))
			metro_frames[frame_key] = metro_frames.get(frame_key,Vector3.ZERO)+tangent
	for element in data.elements:
		if element.get("type","") == "node" and element.has("tags") and element.tags.has("name"):
			places.append({"name":str(element.tags.name),"center":project(float(element.lat),float(element.lon))})
		if element.get("type","") == "relation" and element.has("members") and element.has("tags") and not element.tags.has("building") and not element.tags.has("building:part"):
			for member in element.members:
				if member.get("role","") in ["outer",""] and member.has("geometry"):
					elements.append({"id":int(element.id),"geometry":member.geometry,"tags":element.tags})
	var processed := 0
	for element in elements:
		processed += 1
		if processed%350 == 0:
			build_progress.emit(int(float(processed)/elements.size()*35))
			await get_tree().process_frame
		if not element.has("geometry") or not element.has("tags"):
			continue
		var tags: Dictionary = element.tags
		var pts := PackedVector3Array()
		for p in element.geometry:
			if p.has("lat"):
				pts.append(project(float(p.lat),float(p.lon)))
		if pts.size() < 2:
			continue
		var center := Vector3.ZERO
		for p in pts: center += p
		center /= pts.size()
		if not bounds.grow(150).has_point(Vector2(center.x,center.z)):
			var intersects := false
			if tags.has("railway") or tags.has("highway"):
				for point in pts:
					if bounds.has_point(Vector2(point.x,point.z)): intersects = true; break
			if not intersects: continue
		if tags.has("building") or tags.has("building:part"):
			continue # Cleaned, hole-aware footprints are rendered below.
		elif tags.has("highway"):
			_road(pts,tags,int(element.id))
		elif tags.get("natural","") == "water":
			_polygon(pts,0.035,"water")
		elif tags.get("leisure","") in ["park","garden","recreation_ground"] or tags.get("landuse","") in ["grass","forest","recreation_ground","meadow"]:
			_polygon(pts,0.025,"park")
		elif tags.get("landuse","") in ["commercial","retail","industrial","residential"]:
			_polygon(pts,0.024,"paving")
		elif tags.has("railway"):
			_rail(pts,tags,int(element.id))
	var prepared = JSON.parse_string(FileAccess.get_file_as_string("res://data/hitec-city.render.json"))
	if not prepared is Dictionary or not prepared.has("buildings"):
		push_error("Prepared OSM geometry is missing. Run scripts/prepare_map.py.")
		return
	processed = 0
	for feature: Dictionary in prepared.buildings:
		preload("res://scripts/hyderabad_buildings.gd").build(self,feature)
		_building_solid(feature)
		processed += 1
		if processed%200==0:
			build_progress.emit(35+int(float(processed)/prepared.buildings.size()*54))
			await get_tree().process_frame
	_station(project(17.4490055,78.3831376),Vector3(0.72,0,-0.69),"HITEC CITY")
	_station(project(17.44218,78.37718),Vector3(0,0,-1),"RAIDURG")
	_write_cache()
	build_progress.emit(90)
	await get_tree().process_frame
	_commit_batches()
	print("OSM city: %d features, %d roads, %d mapped buildings, %d chunks" % [source_features,roads.size(),mapped_buildings,chunks.size()])

func _write_cache() -> void:
	var file := FileAccess.open(CACHE_PATH,FileAccess.WRITE)
	if file == null: return
	file.store_var({"signature":cache_signature,"batches":batches,"solid_faces":solid_faces,"roads":roads,"buildings":buildings,"places":places,"source_features":source_features,"mapped_buildings":mapped_buildings,"detailed_buildings":detailed_buildings,"landmark_names":landmark_names,"signs":signs})

func _read_cache() -> bool:
	if not FileAccess.file_exists(CACHE_PATH): return false
	var file := FileAccess.open(CACHE_PATH,FileAccess.READ)
	if file == null: return false
	var cached = file.get_var()
	if not cached is Dictionary or cached.get("signature","") != cache_signature: return false
	batches = cached.batches
	solid_faces=cached.solid_faces
	roads.assign(cached.roads)
	buildings.assign(cached.buildings)
	places.assign(cached.places)
	source_features = cached.source_features
	mapped_buildings = cached.mapped_buildings
	detailed_buildings = cached.detailed_buildings
	landmark_names.assign(cached.landmark_names)
	for sign_data in cached.signs:
		_sign(sign_data.text,sign_data.position,sign_data.yaw,sign_data.pixel,sign_data.get("color",Color("23353d")))
	return true

func _prepare_materials() -> void:
	materials.road = _surface("asphalt",4.0,Color("b9bec3"),0.22)
	materials.paving = _surface("paving",3.0,Color("c0b7a6"),0.20)
	materials.curb = _surface("concrete",2.0,Color("b4b3ad"),0.18)
	materials.line = CityGeometry.material(Color("bdbdb3"))
	materials.park = _grain(Color("53604a"))
	materials.water = CityGeometry.material(Color("325b65"),0.45,0.18)
	materials.rail = _surface("concrete",3.0,Color("cbc9c0"),0.24)
	materials.ochre = _surface("stone",4.0,Color("d5b184"),0.12)
	materials.roof = _surface("concrete",4.0,Color("7d7f7d"),0.15)
	materials.ivory = CityGeometry.material(Color("e5e5df"),0.1,0.46)
	materials.mullion = CityGeometry.material(Color("465556"),0.65,0.3)
	materials.seam = CityGeometry.material(Color("7b8584"),0.1,0.65)
	materials.hero_glass = CityGeometry.material(Color("608e91"),0.68,0.17)
	materials.hero_glass_alt = CityGeometry.material(Color("628e8c"),0.68,0.19)
	materials.glass_dark = CityGeometry.material(Color("354448"),0.45,0.22)
	materials.trim = CityGeometry.material(Color("c7c9c4"),0.15,0.5)
	materials.glass = CityGeometry.material(Color("426b78"),0.5,0.22)
	materials.dark = CityGeometry.material(Color("31393c"),0.3,0.6)
	materials.green = CityGeometry.material(Color("487660"))
	materials.sign = CityGeometry.material(Color("204e6e"))
	materials.leaf = CityGeometry.material(Color("405f3c"))
	materials.trunk = StandardMaterial3D.new()
	materials.trunk.albedo_texture = load("res://assets/foliage/branch.png")
	materials.trunk.uv1_triplanar = true
	materials.trunk.uv1_world_triplanar = true
	materials.trunk.roughness = 0.95
	materials.foliage = ShaderMaterial.new()
	materials.foliage.shader = preload("res://shaders/foliage.gdshader")
	materials.foliage.set_shader_parameter("leaves",load("res://assets/foliage/leaves.png"))
	materials.foliage.set_shader_parameter("mask",load("res://assets/foliage/leaves_alpha.png"))
	for name in ["rail","trim","glass","dark","ochre","ivory","mullion","hero_glass","hero_glass_alt","glass_dark","roof","seam"]:
		if materials[name] is StandardMaterial3D: materials[name].cull_mode = BaseMaterial3D.CULL_DISABLED
	materials.pole = CityGeometry.material(Color("707879"),0.4)
	preload("res://scripts/hyderabad_buildings.gd").materials(self)

func _surface(asset: String,metres: float,tint: Color,normal_strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/materials/"+asset+"_albedo.jpg")
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/materials/"+asset+"_normal.jpg")
	mat.normal_scale = normal_strength
	mat.roughness_texture = load("res://assets/materials/"+asset+"_rough.jpg")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE/metres
	return mat

func _grain(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("color_a",color)
	return mat

func _ground() -> void:
	# Unclassified urban ground is neutral soil/paving; only mapped green areas get grass.
	CityGeometry.box(self,Vector3(250,-0.4,200),Vector3(8500,0.6,8500),_surface("paving",7.0,Color("918e84"),0.12))
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8500,1,8500)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)
	floor_body.position = Vector3(250,-0.5,200)

func _key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x/CELL),floori(pos.z/CELL))

func _tri(key: Vector2i, mat: String, a: Vector3,b: Vector3,c: Vector3, ua: Vector2=Vector2.ZERO,ub: Vector2=Vector2.ZERO,uc: Vector2=Vector2.ZERO) -> void:
	var id := "%d,%d/%s" % [key.x,key.y,mat]
	if not batches.has(id):
		batches[id] = {"key":key,"mat":mat,"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array()}
	var batch: Dictionary = batches[id]
	var normal := (b-a).cross(c-a).normalized()
	# Godot front faces use clockwise winding.
	for p in [a,c,b]: batch.v.append(p)
	for i in 3: batch.n.append(normal)
	for uv in [ua,uc,ub]: batch.uv.append(uv)
	batches[id] = batch
	if mat in ["rail","trim","dark","ochre","ivory","hero_glass","hero_glass_alt","glass_dark","glass","trunk","pole","roof","building_slab","building_cladding","tank"]:
		_solid_tri(key,a,c,b)
	elif mat=="curb" and maxf(a.y,maxf(b.y,c.y))>0.09:
		_solid_tri(key,a,c,b)

func _solid_tri(key: Vector2i,a: Vector3,b: Vector3,c: Vector3) -> void:
	if not solid_faces.has(key):solid_faces[key]=PackedVector3Array()
	var faces: PackedVector3Array=solid_faces[key]
	faces.append(a);faces.append(b);faces.append(c);solid_faces[key]=faces

func _building_solid(feature: Dictionary) -> void:
	# Continuous collision envelope is independent of decorative window recesses.
	# Inner rings remain open courtyards; elevated canopies keep their clearance.
	if feature.style in ["canopy","construction"]:return
	var top: float=34.0 if feature.style=="cyber_towers" else feature.height
	for ring in feature.rings:
		for i in ring.size():
			var p=ring[i];var q=ring[(i+1)%ring.size()]
			var a:=Vector3(p[0],feature.min_height,p[1]);var b:=Vector3(q[0],feature.min_height,q[1])
			var c:=Vector3(q[0],top,q[1]);var d:=Vector3(p[0],top,p[1]);var key:=_key((a+b)*0.5)
			_solid_tri(key,a,c,b);_solid_tri(key,a,d,c)
	for triangle in feature.roof:
		var a:=Vector3(triangle[0][0],top,triangle[0][1]);var b:=Vector3(triangle[1][0],top,triangle[1][1]);var c:=Vector3(triangle[2][0],top,triangle[2][1])
		_solid_tri(_key((a+b+c)/3),a,b,c)

func _quad(key: Vector2i,mat: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,width: float=1.0,height: float=1.0) -> void:
	_tri(key,mat,a,b,c,Vector2(0,0),Vector2(width,0),Vector2(width,height))
	_tri(key,mat,a,c,d,Vector2(0,0),Vector2(width,height),Vector2(0,height))

func _strip(a: Vector3,b: Vector3,width: float,y: float,mat: String) -> void:
	var dir := (b-a).normalized()
	var side := Vector3(-dir.z,0,dir.x)*width*0.5
	a.y = y
	b.y = y
	_quad(_key((a+b)*0.5),mat,a+side,b+side,b-side,a-side)

func _polygon(points: PackedVector3Array,y: float,mat: String) -> void:
	var polygon := PackedVector2Array()
	for p in points: polygon.append(Vector2(p.x,p.z))
	if polygon.size() > 2 and polygon[0].distance_to(polygon[-1]) < 0.1: polygon.remove_at(polygon.size()-1)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0,indices.size(),3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i+1]]
		var c := polygon[indices[i+2]]
		_tri(_key(Vector3(a.x,y,a.y)),mat,Vector3(a.x,y,a.y),Vector3(c.x,y,c.y),Vector3(b.x,y,b.y))

func _road(points: PackedVector3Array,tags: Dictionary,id: int) -> void:
	var kind := str(tags.highway)
	if kind in ["steps","construction","proposed"]: return
	var widths := {"motorway":16.0,"trunk":15.0,"primary":13.0,"secondary":11.0,"tertiary":9.0,"residential":7.0,"unclassified":7.0,"service":5.5,"footway":2.4,"path":2.0,"pedestrian":4.0,"cycleway":2.0}
	var width: float = widths.get(kind,7.0)
	if tags.has("lanes"):
		width = str(tags.lanes).to_float()*3.25+0.6
	if tags.has("width") and str(tags.width).to_float() > 0: width = str(tags.width).to_float()
	width = clampf(width,2.0,30.0)
	var oneway := str(tags.get("oneway","no")) in ["yes","1","true","-1"] or str(tags.get("junction",""))=="roundabout"
	if str(tags.get("oneway",""))=="-1":points.reverse()
	var drivable := width > 4.0 and kind not in ["footway","path","cycleway","pedestrian"]
	var length := 0.0
	_ribbon(points,width+1.5,0.018,"curb")
	_ribbon(points,width,0.045,"road" if drivable else "curb")
	for i in points.size()-1:
		var a := points[i]
		var b := points[i+1]
		if a.distance_to(b) > 500: continue
		length += a.distance_to(b)
		if width > 8:
			var dir := (b-a).normalized()
			var side := Vector3(-dir.z,0,dir.x)
			for s in [-1.0,1.0]: _strip(a+side*(width*0.5-0.4)*s,b+side*(width*0.5-0.4)*s,0.11,0.055,"line")
			var seg_length := a.distance_to(b)
			for t in range(0,int(seg_length)-3,13): _strip(a+dir*t,a+dir*minf(t+4,seg_length),0.14,0.057,"line")
		if width >= 9.0:
			_decorate_road(a,b,width,id+i)
	if drivable and length > 12:
		roads.append({"id":id,"name":str(tags.get("name","Local road")),"points":points,"width":width,"length":length,"oneway":oneway})

func _ribbon(points: PackedVector3Array,width: float,y: float,mat: String) -> void:
	# Shared miter vertices close the gaps between consecutive OSM road segments.
	var left:=PackedVector3Array();var right:=PackedVector3Array()
	for i in points.size():
		var before:=(points[i]-points[maxi(0,i-1)]).normalized()
		var after:=(points[mini(points.size()-1,i+1)]-points[i]).normalized()
		if before.length_squared()<0.01:before=after
		if after.length_squared()<0.01:after=before
		var n1:=Vector3(-before.z,0,before.x)
		var n2:=Vector3(-after.z,0,after.x)
		var normal:=(n1+n2).normalized()
		if normal.length_squared()<0.01:normal=n2
		var offset:=normal*minf(width,width*0.5/maxf(absf(normal.dot(n2)),0.5))
		left.append(points[i]+offset+Vector3.UP*y);right.append(points[i]-offset+Vector3.UP*y)
	for i in points.size()-1:
		if points[i].distance_to(points[i+1])>500:continue
		_quad(_key((points[i]+points[i+1])*0.5),mat,left[i],left[i+1],right[i+1],right[i],width,points[i].distance_to(points[i+1]))

func _decor_box(key: Vector2i,mat: String,p: Vector3,s: Vector3) -> void:
	var x := Vector3(s.x/2,0,0)
	var z := Vector3(0,0,s.z/2)
	var y := Vector3(0,s.y,0)
	_quad(key,mat,p+x-z,p-x-z,p-x-z+y,p+x-z+y)
	_quad(key,mat,p-x+z,p+x+z,p+x+z+y,p-x+z+y)
	_quad(key,mat,p-x-z,p-x+z,p-x+z+y,p-x-z+y)
	_quad(key,mat,p+x+z,p+x-z,p+x-z+y,p+x+z+y)
	_quad(key,mat,p-x+z+y,p+x+z+y,p+x-z+y,p-x-z+y)

func _decorate_road(a: Vector3,b: Vector3,width: float,seed_id: int) -> void:
	var dir := (b-a).normalized()
	var side := Vector3(-dir.z,0,dir.x)
	for distance in range(20,int(a.distance_to(b)),75):
		for sign_side in [-1.0,1.0]:
			var p: Vector3 = a+dir*distance+side*(width/2+2.2)*sign_side
			var cell := Vector2i(floori(p.x/12),floori(p.z/12))
			if decor_cells.has(cell): continue
			decor_cells[cell] = true
			var key := _key(p)
			if posmod(seed_id+distance,3) == 0:
				_decor_box(key,"pole",p,Vector3(0.14,7.0,0.14))
				_decor_box(key,"pole",p+Vector3(0,7,-0.6),Vector3(0.5,0.12,1.6))
			else:
				_decor_box(key,"trunk",p,Vector3(0.32,4.4,0.32))
				_canopy(key,p+Vector3(0,5.3,0),Vector3(3.0,2.2,2.8))
				_canopy(key,p+Vector3(1.6,4.7,0.6),Vector3(2.2,1.8,2.0))
				_canopy(key,p+Vector3(-1.4,5.5,-0.5),Vector3(2.0,2.0,2.0))

func _canopy(key: Vector2i,center: Vector3,radius: Vector3) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = int(center.x*731+center.z*191+center.y*47)
	var nearby := center.distance_to(project(17.45048,78.3811)) < 240
	for i in (100 if nearby else 32):
		var theta := random.randf()*TAU
		var elevation := random.randf_range(-1,1)
		var ring := sqrt(1-elevation*elevation)
		var p := center+Vector3(cos(theta)*ring,elevation,sin(theta)*ring)*radius*pow(random.randf(),0.33)
		var basis := Basis.from_euler(Vector3(random.randf_range(-0.7,0.7),random.randf()*TAU,random.randf_range(-0.4,0.4)))
		var card_scale := clampf(radius.length()/4.5,0.22,1.0)
		var x := basis.x*random.randf_range(0.4,0.7)*card_scale
		var y := basis.y*random.randf_range(0.7,1.1)*card_scale
		_quad(key,"foliage",p-x-y,p+x-y,p+x+y,p-x+y)

func _pair_point(p: Vector3,id: int) -> Dictionary:
	var best := 8.0*8.0
	var other := p
	var other_id := id
	for segment in metro_segments:
		if segment.id == id: continue
		if segment.id in METRO_PRIMARY or int(segment.id) >= 1188691922: continue
		if p.distance_squared_to((segment.a+segment.b)*0.5) > 40000: continue
		var tangent: Vector3 = segment.b-segment.a
		var projection: float = (p-segment.a).dot(tangent)/maxf(tangent.length_squared(),0.001)
		if projection < -0.02 or projection > 1.02: continue
		var q := Geometry3D.get_closest_point_to_segment(p,segment.a,segment.b)
		var d := p.distance_squared_to(q)
		if d < best and d > 0.8*0.8:
			best = d
			other = q
			other_id = segment.id
	return {"position":(p+other)*0.5,"id":other_id}

func _rail(points: PackedVector3Array,tags: Dictionary,id: int) -> void:
	if tags.get("railway","") not in ["rail","light_rail","subway"]: return
	var elevated: bool = tags.get("bridge","") not in ["","no"]
	var metro: bool = tags.get("railway","") == "subway"
	# These connected ways form one complete track through this offline snapshot.
	# The opposite track supplies midpoints, never a second overlapping viaduct.
	if metro and id not in METRO_PRIMARY: return
	var run := 10.0
	for i in points.size()-1:
		var a := points[i]
		var b := points[i+1]
		if a.distance_to(b) > 500: continue
		if not bounds.grow(150).has_point(Vector2(a.x,a.z)) and not bounds.grow(150).has_point(Vector2(b.x,b.z)): continue
		var tangent_a: Vector3 = metro_frames.get(Vector2i(roundi(a.x*100),roundi(a.z*100)),(b-a).normalized())
		var tangent_b: Vector3 = metro_frames.get(Vector2i(roundi(b.x*100),roundi(b.z*100)),(b-a).normalized())
		if metro:
			a = _pair_point(a,id).position
			b = _pair_point(b,id).position
		var dir := (b-a).normalized()
		var side := Vector3(-dir.z,0,dir.x)
		var side_a := Vector3(-tangent_a.z,0,tangent_a.x).normalized()
		var side_b := Vector3(-tangent_b.z,0,tangent_b.x).normalized()
		side_a /= maxf(side_a.dot(side),0.7)
		side_b /= maxf(side_b.dot(side),0.7)
		var key := _key((a+b)*0.5)
		if elevated:
			# Single paired-track box girder: broad top flange, tapered underside.
			var profile := [Vector2(-4.7,11.8),Vector2(4.7,11.8),Vector2(4.7,11.45),Vector2(3.1,11.15),Vector2(2.55,9.65),Vector2(-2.55,9.65),Vector2(-3.1,11.15),Vector2(-4.7,11.45)]
			for j in profile.size():
				var u: Vector2 = profile[j]
				var v: Vector2 = profile[(j+1)%profile.size()]
				_quad(key,"rail",a+side_a*v.x+Vector3.UP*v.y,b+side_b*v.x+Vector3.UP*v.y,b+side_b*u.x+Vector3.UP*u.y,a+side_a*u.x+Vector3.UP*u.y)
			for sign_side in [-1.0,1.0]:
				_beam(a+side_a*4.6*sign_side+Vector3.UP*12.25,b+side_b*4.6*sign_side+Vector3.UP*12.25,0.22,0.9,"rail")
		else: _strip(a,b,8.5,0.18,"rail")
		var rail_y := 11.98 if elevated else 0.36
		for track in [-2.0,2.0]:
			for sign_side in [-1.0,1.0]:
				_beam(a+side_a*(track+sign_side*0.72)+Vector3.UP*rail_y,b+side_b*(track+sign_side*0.72)+Vector3.UP*rail_y,0.07,0.12,"dark")
		var length := a.distance_to(b)
		while run < length:
			var pos := a+dir*run
			var clear := true
			for existing in pillar_positions:
				if pos.distance_squared_to(existing)<20*20: clear=false; break
			if elevated and clear:
				pillar_positions.append(pos)
				_pier(pos,dir,side)
				# Expansion joints lie across the girder, at each precast span.
				_beam(pos-side*2.6+Vector3.UP*9.63,pos+side*2.6+Vector3.UP*9.63,0.025,0.025,"seam")
				_beam(pos-dir*13+Vector3.UP*0.22,pos+dir*13+Vector3.UP*0.22,2.65,0.38,"curb")
				for d in range(-12,13,2):
					for sign_side in [-1.0,1.0]:
						_beam(pos+dir*d+side*1.34*sign_side+Vector3.UP*0.24,pos+dir*(d+0.95)+side*1.34*sign_side+Vector3.UP*0.24,0.12,0.35,"dark")
					if pos.distance_to(project(17.45048,78.3811)) < 500:
						_canopy(key,pos+dir*d+Vector3.UP*0.65,Vector3(0.6,0.42,0.55))
			run += 28
		run -= length

func _pier(pos: Vector3,dir: Vector3,side: Vector3) -> void:
	var key := _key(pos)
	var profiles := [Vector3(0.0,0.9,0.85),Vector3(0.45,0.9,0.85),Vector3(0.52,0.68,0.65),Vector3(7.5,0.68,0.65),Vector3(8.3,1.1,0.72),Vector3(9.15,2.2,0.85),Vector3(9.5,2.65,0.9)]
	var ring := [Vector2(-1,-0.78),Vector2(-0.78,-1),Vector2(0.78,-1),Vector2(1,-0.78),Vector2(1,0.78),Vector2(0.78,1),Vector2(-0.78,1),Vector2(-1,0.78)]
	for level in profiles.size()-1:
		var lo: Vector3 = profiles[level]
		var hi: Vector3 = profiles[level+1]
		for j in ring.size():
			var u: Vector2 = ring[j]
			var v: Vector2 = ring[(j+1)%ring.size()]
			_quad(key,"rail",pos+side*u.x*lo.y+dir*u.y*lo.z+Vector3.UP*lo.x,pos+side*v.x*lo.y+dir*v.y*lo.z+Vector3.UP*lo.x,pos+side*v.x*hi.y+dir*v.y*hi.z+Vector3.UP*hi.x,pos+side*u.x*hi.y+dir*u.y*hi.z+Vector3.UP*hi.x)

func _beam(a: Vector3,b: Vector3,width: float,height: float,mat: String) -> void:
	if a.distance_squared_to(b) < 0.0001: return
	var forward := (b-a).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01: side = Vector3.RIGHT
	var up := side.cross(forward).normalized()*height*0.5
	side *= width*0.5
	var key := _key((a+b)*0.5)
	_quad(key,mat,a-side-up,b-side-up,b+side-up,a+side-up)
	_quad(key,mat,a+side+up,b+side+up,b-side+up,a-side+up)
	_quad(key,mat,a-side+up,b-side+up,b-side-up,a-side-up)
	_quad(key,mat,a+side-up,b+side-up,b+side+up,a+side+up)
	_quad(key,mat,a-side-up,a+side-up,a+side+up,a-side+up)
	_quad(key,mat,b+side-up,b-side-up,b-side+up,b+side+up)

func _sign(text: String,pos: Vector3,yaw: float,pixel: float=0.035,color: Color=Color("23353d")) -> void:
	signs.append({"text":text,"position":pos,"yaw":yaw,"pixel":pixel,"color":color})
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = color
	label.no_depth_test = false
	label.double_sided = true
	label.visibility_range_end = 350
	add_child(label)
	label.position = pos
	label.rotation.y = yaw

func _station(center: Vector3,dir: Vector3,title: String) -> void:
	var side := Vector3(-dir.z,0,dir.x)
	var length := 65.0
	_beam(center-dir*length+Vector3.UP*8.0,center+dir*length+Vector3.UP*8.0,18.0,1.0,"rail")
	for sign_side: float in [-1.0,1.0]:
		var rim := center+side*8.8*sign_side
		_beam(rim-dir*length+Vector3.UP*11.1,rim+dir*length+Vector3.UP*11.1,0.6,4.5,"trim")
		_beam(rim-dir*length+Vector3.UP*12.0,rim+dir*length+Vector3.UP*12.0,0.7,1.4,"glass")
		_beam(rim-dir*length+Vector3.UP*14.0,rim+dir*length+Vector3.UP*14.0,1.2,0.18,"dark")
		for d in range(-60,61,6):
			var p := rim+dir*d
			_beam(p+Vector3.UP*8.5,p+Vector3.UP*14.2,0.20,0.20,"trim")
		for d: float in [-48,48]:
			var p := center+dir*d
			# Covered access footbridge, balustrades and individual stair treads.
			_beam(p+Vector3.UP*5.5,p+side*23*sign_side+Vector3.UP*5.5,3.4,0.5,"rail")
			_beam(p+Vector3.UP*8.5,p+side*23*sign_side+Vector3.UP*8.5,4.0,0.16,"dark")
			for r in range(0,24,3):
				for edge: float in [-1,1]:
					var post := p+side*r*sign_side+dir*1.65*edge
					_beam(post+Vector3.UP*5.6,post+Vector3.UP*8.4,0.10,0.10,"trim")
			var end := p+side*23*sign_side
			for step in 28:
				var q := end+dir*step*0.32
				_decor_box(_key(q),"rail",q+Vector3.UP*(5.3-step*0.19),Vector3(2.5,0.19,0.36))
			_beam(end+Vector3.UP*8.0,end+dir*9+Vector3.UP*2.7,3.1,0.14,"dark")
	# Curved barrel canopy, segmented finely enough to retain a rounded silhouette.
	for section in 20:
		var angle_a := PI*section/20
		var angle_b := PI*(section+1)/20
		var a := side*cos(angle_a)*9.5+Vector3.UP*(14.0+sin(angle_a)*4.1)
		var b := side*cos(angle_b)*9.5+Vector3.UP*(14.0+sin(angle_b)*4.1)
		_quad(_key(center),"trim",center-dir*length+a,center+dir*length+a,center+dir*length+b,center-dir*length+b)
	_sign(title+"  METRO",center-dir*(length+0.2)+Vector3.UP*12.7,atan2(dir.x,dir.z),0.045)


func _commit_batches() -> void:
	for id in batches:
		var batch: Dictionary = batches[id]
		var key: Vector2i = batch.key
		if not chunks.has(key):
			var chunk := Node3D.new()
			add_child(chunk)
			chunks[key] = chunk
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.v
		arrays[Mesh.ARRAY_NORMAL] = batch.n
		arrays[Mesh.ARRAY_TEX_UV] = batch.uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = materials[batch.mat]
		instance.visibility_range_end = 360 if batch.mat == "foliage" else 950
		instance.visibility_range_end_margin = 80
		chunks[key].add_child(instance)
	for key in solid_faces:
		var faces: PackedVector3Array=solid_faces[key]
		if faces.is_empty():continue
		var body:=StaticBody3D.new();body.name="SolidDistrict_%s_%s"%[key.x,key.y]
		body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();var surface:=ConcavePolygonShape3D.new()
		surface.backface_collision=true;surface.set_faces(faces);shape.shape=surface;body.add_child(shape);add_child(body)
		collision_bodies.append(body);collision_triangles+=faces.size()/3
	batches.clear()
	solid_faces.clear()
	data.clear()

func nearest_road(pos: Vector3) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	for road in roads:
		var pts: PackedVector3Array = road.points
		for i in pts.size()-1:
			var p := Geometry3D.get_closest_point_to_segment(pos,pts[i],pts[i+1])
			var distance := pos.distance_squared_to(p)
			if distance < best:
				best = distance
				result = {"position":p,"direction":(pts[i+1]-pts[i]).normalized(),"road":road}
	return result

func set_night(value: float) -> void:
	for mat in facade_materials: mat.set_shader_parameter("night",value)

func set_detail(high: bool) -> void:
	for chunk in chunks.values():
		for child in chunk.get_children():
			if child is MeshInstance3D: child.visibility_range_end = (360 if high else 240) if child.material_override == materials.foliage else (950 if high else 650)
