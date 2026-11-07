extends RefCounted
## Facade families grounded in the supplied Hyderabad corridor references.
## Exact OSM outlines are retained; inferred detail remains marked in the manifest.

static func materials(city: Node3D) -> void:
	city.materials.building_plaster = city._surface("plaster",3.0,Color("d6d3c8"),0.14)
	city.materials.building_cream = city._surface("plaster",3.0,Color("cbbca0"),0.14)
	city.materials.building_brick = city._surface("brick",3.2,Color("f0c7ad"),0.26)
	city.materials.building_cladding = city._surface("concrete",5.0,Color("a2a8aa"),0.12)
	city.materials.building_window = CityGeometry.material(Color("526e78"),0.55,0.23)
	city.materials.building_blueglass = CityGeometry.material(Color("6e9db4"),0.55,0.20)
	city.materials.building_steel = CityGeometry.material(Color("748082"),0.65,0.3)
	city.materials.building_slab = city._surface("concrete",4,Color("cdcbc1"),0.12)
	city.materials.tank = CityGeometry.material(Color("42545c"),0.1,0.72)
	for style in ["residential","office","campus","retail","service","hotel"]:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/hyderabad_facade.gdshader")
		mat.set_shader_parameter("office",style in ["office","hotel"])
		mat.set_shader_parameter("wall_color",Color("cec6b4") if style == "residential" else Color("c1c8c8"))
		mat.set_shader_parameter("wall_tex",load("res://assets/materials/plaster_albedo.jpg"))
		city.materials["building_local_"+style] = mat
		city.facade_materials.append(mat)
	for name in city.materials:
		if str(name).begins_with("building_") and city.materials[name] is StandardMaterial3D:
			city.materials[name].cull_mode = BaseMaterial3D.CULL_DISABLED

static func build(city: Node3D,feature: Dictionary) -> void:
	var center := Vector3(feature.center[0],0,feature.center[1])
	var key: Vector2i = city._key(center)
	var height: float = feature.height
	var base: float = feature.min_height
	var style: String = feature.style
	var footprint := PackedVector3Array()
	for p in feature.rings[0]: footprint.append(Vector3(p[0],0,p[1]))
	if style == "cyber_towers":
		# Keep the existing landmark model and its original OSM ordering intact.
		for source in city.data.elements:
			if int(source.id) == 68883448 and source.has("geometry"):
				footprint.clear()
				for p in source.geometry: footprint.append(city.project(p.lat,p.lon))
				if footprint[0].distance_to(footprint[-1])<0.1:footprint.remove_at(footprint.size()-1)
				break
		preload("res://scripts/cyber_towers.gd").build(city,footprint,34.0)
		height = 34.0
	else:
		var near_corridor := _corridor_distance(center)<105
		var detailed: bool = near_corridor or style in ["deccan_park","trident","pearl","retail_glass"]
		if detailed: city.detailed_buildings += 1
		_roof(city,feature,height)
		for source_ring in feature.rings:
			var ring := PackedVector3Array()
			for p in source_ring: ring.append(Vector3(p[0],0,p[1]))
			if style=="deccan_park":_deccan_crown(city,ring,height)
			for i in ring.size():
				var a := ring[i]
				var b := ring[(i+1)%ring.size()]
				if style == "construction":
					_construction(city,a,b,height)
				elif style == "canopy":
					city._beam(a+Vector3.UP*height,b+Vector3.UP*height,0.25,0.3,"building_slab")
					city._beam(a,a+Vector3.UP*height,0.18,0.18,"building_steel")
				elif detailed and style in ["office","hotel","pearl","trident","retail_glass","deccan_park"]:
					_office(city,a,b,base,height,style)
				elif detailed:
					_residential(city,a,b,base,height,style,feature.levels)
				else:
					var material := "building_local_"+(style if style in ["residential","office","campus","retail","service","hotel"] else "office")
					city._quad(key,material,a+Vector3.UP*base,b+Vector3.UP*base,b+Vector3.UP*height,a+Vector3.UP*height,a.distance_to(b),height-base)
				if detailed and style != "construction":
					city._beam(a+Vector3.UP*(height+0.38),b+Vector3.UP*(height+0.38),0.16,0.75,"building_plaster")
		if detailed and style in ["residential","retail"] and feature.area>70:
			city._decor_box(key,"building_slab",center+Vector3.UP*height,Vector3(2.2,0.35,2.2))
			_tank(city,center+Vector3.UP*(height+0.35))
		if feature.shop_sign != "":
			_sign_on_street(city,footprint,center,feature.shop_sign,4.7,Color("e1e4e7"),"sign")
		elif style in ["trident","pearl","deccan_park"]:
			_sign_on_street(city,footprint,center,feature.name,minf(height-1.5,7.5),Color("e1e4e7"),"dark")
		if style in ["trident","pearl","deccan_park"]:_frontage(city,footprint,style)
	city.mapped_buildings += 1
	city.buildings.append({"id":int(feature.id),"osm_type":feature.osm_type,"center":center,"height":height,"measured":feature.height_source=="osm_height","height_source":feature.height_source,"name":feature.name,"style":style})
	if feature.name != "":city.landmark_names.append(feature.name)

static func _corridor_distance(p: Vector3) -> float:
	var anchors := [HitecCity.project(17.4490055,78.3831376),HitecCity.project(17.4511,78.38095),HitecCity.project(17.4495,78.37905),HitecCity.project(17.4474,78.3777),HitecCity.project(17.4418,78.3772)]
	var distance := INF
	for i in anchors.size()-1:distance=minf(distance,p.distance_to(Geometry3D.get_closest_point_to_segment(p,anchors[i],anchors[i+1])))
	return distance

static func _frontage(city: Node3D,ring: PackedVector3Array,style: String) -> void:
	# Street-view-observed planting and compound walls; setback is estimated.
	for i in ring.size():
		var a:=ring[i];var b:=ring[(i+1)%ring.size()]
		var length:=a.distance_to(b)
		if length<8:continue
		var normal:=(b-a).normalized().cross(Vector3.UP)
		var middle:=(a+b)*0.5
		var road: Dictionary=city.nearest_road(middle)
		var distance: float=middle.distance_to(road.position)
		if distance<7 or distance>48 or (road.position-middle).dot(normal)<0:continue
		var setback:=minf(5.5,maxf(1.0,distance-road.road.width/2-1.4))
		var offset:=normal*setback
		var wall_height:=0.65 if style=="trident" else 1.35
		city._beam(a+offset+Vector3.UP*wall_height/2,b+offset+Vector3.UP*wall_height/2,0.40,wall_height,"building_cladding")
		for j in range(2,int(length)-2,8):
			var p:=a.lerp(b,float(j)/length)+offset-normal*1.4
			city._canopy(city._key(p),p+Vector3.UP*1.5,Vector3(2.5,0.8,1.1))
			if style=="deccan_park" or j%3==2:
				city._beam(p,p+Vector3.UP*4.5,0.22,0.22,"trunk")
				city._canopy(city._key(p),p+Vector3.UP*5.3,Vector3(3.4,2.5,2.8))

static func _roof(city: Node3D,f: Dictionary,y: float) -> void:
	var key: Vector2i = city._key(Vector3(f.center[0],0,f.center[1]))
	for triangle in f.roof:
		var a := Vector3(triangle[0][0],y,triangle[0][1])
		var b := Vector3(triangle[1][0],y,triangle[1][1])
		var c := Vector3(triangle[2][0],y,triangle[2][1])
		if (b-a).cross(c-a).y<0:var swap:=b;b=c;c=swap
		city._tri(key,"roof",a,b,c)

static func _office(city: Node3D,a: Vector3,b: Vector3,base: float,height: float,style: String) -> void:
	var length := a.distance_to(b)
	if length<0.1:return
	var direction := (b-a)/length
	var normal := direction.cross(Vector3.UP)
	var key: Vector2i = city._key((a+b)*0.5)
	var glass := "building_blueglass" if style in ["trident","pearl"] else "building_window"
	city._quad(key,glass,a+Vector3.UP*base,b+Vector3.UP*base,b+Vector3.UP*height,a+Vector3.UP*height,length,height-base)
	if style=="trident":
		_trident_podium(city,a,b,normal,base,height)
	var pitch := 3.2
	var floors := maxi(1,ceili((height-base)/pitch))
	for level in floors+1:
		var y := minf(height,base+level*pitch)
		var band := 0.16
		if style == "pearl": band=0.85
		elif style == "retail_glass": band=0.48
		city._beam(a+normal*0.10+Vector3.UP*y,b+normal*0.10+Vector3.UP*y,0.20,band,"building_plaster" if style in ["pearl","retail_glass"] else "building_steel")
	var bays := maxi(1,ceili(length/(4.1 if style=="deccan_park" else 1.5)))
	for i in bays+1:
		var p := a.lerp(b,float(i)/bays)
		if style=="deccan_park":
			# The distinctive red-brick fins stand proud of the recessed glazing.
			var top := height-(3.0 if i%2==0 else 0.0)
			city._beam(p+normal*0.55+Vector3.UP*base,p+normal*0.55+Vector3.UP*top,0.8,1.2,"building_brick")
			if i<bays:
				for sub in [0.33,0.66]:
					var mullion:=a.lerp(b,(i+sub)/bays)+normal*0.04
					city._beam(mullion+Vector3.UP*base,mullion+Vector3.UP*height,0.045,0.05,"building_steel")
		else:
			city._beam(p+normal*0.035+Vector3.UP*base,p+normal*0.035+Vector3.UP*height,0.045,0.06,"building_steel")
	if style=="retail_glass":
		city._beam(a+normal*0.5+Vector3.UP*3.5,b+normal*0.5+Vector3.UP*3.5,1.4,0.16,"building_slab")

static func _trident_podium(city: Node3D,a: Vector3,b: Vector3,normal: Vector3,base: float,height: float) -> void:
	# Grey stone podium and broad piers alternate with recessed tall glazing.
	# Upper hotel floors retain the narrow blue glazing visible in the photograph.
	var key: Vector2i=city._key((a+b)*0.5)
	var length:=a.distance_to(b)
	var direction:=(b-a).normalized()
	var bays:=maxi(1,roundi(length/14.0))
	var pitch:=length/bays
	var plinth:=minf(height*0.17,7.0)
	var podium:=height*0.63
	city._quad(key,"building_cladding",a+normal*0.50+Vector3.UP*base,b+normal*0.50+Vector3.UP*base,b+normal*0.50+Vector3.UP*plinth,a+normal*0.50+Vector3.UP*plinth,length,plinth)
	for i in bays:
		var p:=a+direction*(pitch*i)
		var q:=p+direction*pitch*0.52
		city._quad(key,"building_cladding",p+normal*0.65+Vector3.UP*plinth,q+normal*0.65+Vector3.UP*plinth,q+normal*0.65+Vector3.UP*podium,p+normal*0.65+Vector3.UP*podium,p.distance_to(q),podium-plinth)
		for y in range(ceili(plinth),int(podium),1):city._beam(p+normal*0.67+Vector3.UP*y,q+normal*0.67+Vector3.UP*y,0.02,0.018,"building_steel")
		city._beam(p+normal*0.65+Vector3.UP*podium,p+direction*pitch+normal*0.65+Vector3.UP*podium,1.3,0.7,"building_cladding")
	for y in [podium+3.2,podium+6.4]:
		city._beam(a+normal*0.30+Vector3.UP*y,b+normal*0.30+Vector3.UP*y,0.8,0.48,"building_cladding")

static func _deccan_crown(city: Node3D,ring: PackedVector3Array,height: float) -> void:
	var outside:=PackedVector3Array()
	for i in ring.size():
		var previous:=(ring[i]-ring[posmod(i-1,ring.size())]).normalized().cross(Vector3.UP)
		var next:=(ring[(i+1)%ring.size()]-ring[i]).normalized().cross(Vector3.UP)
		var normal:=(previous+next).normalized()
		outside.append(ring[i]+normal*minf(4.0,2.6/maxf(absf(normal.dot(next)),0.65))+Vector3.UP*(height+0.5))
	for i in ring.size():
		var j:=(i+1)%ring.size()
		var a:=ring[i]+Vector3.UP*(height+0.5);var b:=ring[j]+Vector3.UP*(height+0.5)
		city._quad(city._key((a+b)*0.5),"building_steel",a,b,outside[j],outside[i])
		city._beam(outside[i],outside[j],0.06,0.16,"building_steel")

static func _residential(city: Node3D,a: Vector3,b: Vector3,base: float,height: float,style: String,levels: int) -> void:
	var length := a.distance_to(b)
	if length<0.1:return
	var dir := (b-a)/length
	var normal := dir.cross(Vector3.UP)
	var key: Vector2i = city._key((a+b)*0.5)
	var wall := "building_cream" if style=="residential" else "building_plaster"
	var count := maxi(1,roundi(length/3.1))
	var span := length/count
	var pitch := (height-base)/maxi(levels,1)
	for floor_index in maxi(levels,1):
		var y := base+floor_index*pitch
		for bay in count:
			var left := a+dir*bay*span
			var right := a+dir*(bay+1)*span
			var inset := minf(span*0.20,0.55)
			var p := left+dir*inset
			var q := right-dir*inset
			var sill := y+minf(0.85,pitch*0.24)
			var top := minf(y+pitch-0.45,sill+1.6)
			city._quad(key,wall,left+Vector3.UP*y,right+Vector3.UP*y,right+Vector3.UP*sill,left+Vector3.UP*sill)
			city._quad(key,wall,left+Vector3.UP*top,right+Vector3.UP*top,right+Vector3.UP*(y+pitch),left+Vector3.UP*(y+pitch))
			city._quad(key,wall,left+Vector3.UP*sill,p+Vector3.UP*sill,p+Vector3.UP*top,left+Vector3.UP*top)
			city._quad(key,wall,q+Vector3.UP*sill,right+Vector3.UP*sill,right+Vector3.UP*top,q+Vector3.UP*top)
			city._quad(key,"building_window",p-normal*0.14+Vector3.UP*sill,q-normal*0.14+Vector3.UP*sill,q-normal*0.14+Vector3.UP*top,p-normal*0.14+Vector3.UP*top)
			for point in [p,q,(p+q)*0.5]:city._beam(point+Vector3.UP*sill,point+Vector3.UP*top,0.045,0.06,"building_steel")
			city._beam(p+Vector3.UP*top,q+Vector3.UP*top,0.07,0.05,"building_steel")
			city._beam(p+Vector3.UP*sill,q+Vector3.UP*sill,0.25,0.08,"building_slab")
			if style=="residential" and floor_index>0 and bay%3==1 and span>2.5:
				# Slab, thin metal handrail and vertical balusters; no thick solid boxes.
				city._beam(left+normal*0.45+Vector3.UP*y,right+normal*0.45+Vector3.UP*y,1.0,0.15,"building_slab")
				city._beam(left+normal*0.9+Vector3.UP*(y+1),right+normal*0.9+Vector3.UP*(y+1),0.035,0.035,"building_steel")
				for rail in 7:
					var v: Vector3 = left.lerp(right,float(rail)/6)+normal*0.9
					city._beam(v+Vector3.UP*y,v+Vector3.UP*(y+1),0.022,0.022,"building_steel")

static func _construction(city: Node3D,a: Vector3,b: Vector3,height: float) -> void:
	var bays := maxi(1,ceili(a.distance_to(b)/5))
	for i in bays+1:
		var p := a.lerp(b,float(i)/bays)
		city._beam(p,p+Vector3.UP*height,0.36,0.36,"building_slab")
	for level in ceili(height/3.2)+1:
		city._beam(a+Vector3.UP*minf(height,level*3.2),b+Vector3.UP*minf(height,level*3.2),0.5,0.28,"building_slab")

static func _tank(city: Node3D,p: Vector3) -> void:
	for i in 16:
		var a := Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*0.65
		var b := Vector3(cos((i+1)*TAU/16),0,sin((i+1)*TAU/16))*0.65
		city._quad(city._key(p),"tank",p+a,p+b,p+b+Vector3.UP*1.3,p+a+Vector3.UP*1.3)
		city._tri(city._key(p),"tank",p+Vector3.UP*1.3,p+b+Vector3.UP*1.3,p+a+Vector3.UP*1.3)

static func _sign_on_street(city: Node3D,points: PackedVector3Array,center: Vector3,title: String,y: float,color: Color,mat: String) -> void:
	var road: Dictionary = city.nearest_road(center)
	if road.is_empty():return
	var best := INF
	var a := points[0]
	var b := points[1]
	for i in points.size():
		var p := points[i]
		var q := points[(i+1)%points.size()]
		var distance: float = ((p+q)*0.5).distance_squared_to(road.position)
		if distance<best and p.distance_to(q)>5:best=distance;a=p;b=q
	var normal := (b-a).normalized().cross(Vector3.UP)
	var midpoint := (a+b)*0.5+normal*0.35+Vector3.UP*y
	var dir := (b-a).normalized()
	city._beam(midpoint-dir*minf(5,a.distance_to(b)*0.43),midpoint+dir*minf(5,a.distance_to(b)*0.43),0.1,0.85,mat)
	city._sign(title.to_upper(),midpoint+normal*0.08,atan2(normal.x,normal.z),0.012,color)
