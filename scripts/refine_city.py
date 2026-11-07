from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'game/scripts/city.gd'
s=p.read_text()
s=s.replace('var places: Array[Dictionary] = []','var places: Array[Dictionary] = []\nvar pillar_cells: Dictionary = {}\nvar detailed_buildings := 0')
s=s.replace('\t_commit_batches()','\t_station(project(17.4490055,78.3831376),Vector3(0.72,0,-0.69),"HITEC CITY")\n\t_station(project(17.44218,78.37718),Vector3(0,0,-1),"RAIDURG")\n\t_commit_batches()',1)
s=s.replace('materials.curb = CityGeometry.material(Color("bab7a6"))','materials.curb = CityGeometry.material(Color("92958e"))')
s=s.replace('materials.line = CityGeometry.material(Color("d4d1bd"))','materials.line = CityGeometry.material(Color("bdbdb3"))')
s=s.replace('materials.rail = CityGeometry.material(Color("9b9c90"))','''materials.rail = ShaderMaterial.new()
	materials.rail.shader = preload("res://shaders/concrete.gdshader")
	materials.ochre = CityGeometry.material(Color("b89b73"))
	materials.trim = CityGeometry.material(Color("c7c9c4"),0.15,0.5)
	materials.glass = CityGeometry.material(Color("426b78"),0.5,0.22)
	materials.dark = CityGeometry.material(Color("31393c"),0.3,0.6)
	materials.green = CityGeometry.material(Color("487660"))
	materials.sign = CityGeometry.material(Color("204e6e"))
	materials.leaf = CityGeometry.material(Color("405f3c"))''')
s=s.replace('Color("6d705d")','Color("767c6c")')
s=s.replace('var mat := "building%d" % posmod(id,6)','''var mat := "building%d" % posmod(id,6)
	if id == 68883448: mat = "ochre"''')
s=s.replace('\tmapped_buildings += 1','''	if id == 68883448:
		_cyber_towers(pts,height,center)
	elif center.x > -900 and center.x < 200 and center.z > -400 and center.z < 1700:
		_facade_details(pts,height,center,tags)
	mapped_buildings += 1''')
# No floating billboard names; put signage on actual street-level facades.
a=s.index('\tif title.length() > 3')
b=s.index('\nfunc _road(',a)
s=s[:a]+'''\tif title.length() > 3: landmark_names.append(title)
'''+s[b:]
# Give each roadway a narrow sidewalk rather than the huge white border.
s=s.replace('_strip(a,b,width+2.4,0.018,"curb")','_strip(a,b,width+1.5,0.018,"curb")')
# Avoid planting a symmetrical avenue through every junction and car park.
s=s.replace('range(12,int(a.distance_to(b)),42)','range(20,int(a.distance_to(b)),75)')
s=s.replace('p[3],p[2],p[1],p[0]','p[0],p[1],p[2],p[3]')
a=s.index('func _rail(')
b=s.index('\nfunc _commit_batches',a)
s=s[:a]+'''func _rail(points: PackedVector3Array,tags: Dictionary) -> void:
	if tags.get("railway","") not in ["rail","light_rail","subway"]: return
	var elevated := tags.get("bridge","") not in ["","no"]
	var elevation := 11.5 if elevated else 0.18
	var run := 0.0
	for i in points.size()-1:
		var a := points[i]
		var b := points[i+1]
		if a.distance_to(b) > 500: continue
		var dir := (b-a).normalized()
		var side := Vector3(-dir.z,0,dir.x)
		if elevated:
			_beam(a+Vector3.UP*10.6,b+Vector3.UP*10.6,4.9,1.8,"rail")
			for sign_side: float in [-1.0,1.0]:
				_beam(a+side*2.55*sign_side+Vector3.UP*11.8,b+side*2.55*sign_side+Vector3.UP*11.8,0.25,1.0,"rail")
		else: _strip(a,b,5.5,elevation,"rail")
		for sign_side: float in [-1.0,1.0]:
			_beam(a+side*0.72*sign_side+Vector3.UP*(elevation+0.15),b+side*0.72*sign_side+Vector3.UP*(elevation+0.15),0.09,0.12,"dark")
		var length := a.distance_to(b)
		while run < length:
			var pos := a+dir*run
			var cell := Vector2i(roundi(pos.x/14),roundi(pos.z/14))
			if elevated and not pillar_cells.has(cell):
				pillar_cells[cell] = true
				_decor_box(_key(pos),"rail",pos,Vector3(1.5,8.2,1.5))
				_beam(pos+Vector3.UP*8,pos+Vector3.UP*9.8,3.8,2.0,"rail")
				# Concrete base, narrow planted median and green/white kerb blocks.
				_decor_box(_key(pos),"rail",pos,Vector3(2.1,0.45,2.1))
				_beam(pos-dir*13+Vector3.UP*0.22,pos+dir*13+Vector3.UP*0.22,2.7,0.4,"curb")
				_beam(pos-dir*12+Vector3.UP*0.6,pos+dir*12+Vector3.UP*0.6,1.9,0.55,"leaf")
				for d in range(-12,13,2):
					for sign_side: float in [-1.0,1.0]:
						_beam(pos+dir*d+side*1.4*sign_side+Vector3.UP*0.25,pos+dir*(d+1)+side*1.4*sign_side+Vector3.UP*0.25,0.16,0.35,"green")
				if pos.distance_to(project(17.4509,78.3818)) < 500:
					_decor_box(_key(pos),"sign",pos+Vector3(-0.85,2.3,0),Vector3(0.08,2.3,1.05))
			run += 28
		run -= length

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

func _cyber_towers(pts: PackedVector3Array,height: float,center: Vector3) -> void:
	detailed_buildings += 1
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i+1)%pts.size()]
		var outward := ((a+b)*0.5-center).normalized()*0.18
		a += outward
		b += outward
		var dir := (b-a).normalized()
		var length := a.distance_to(b)
		var glazing := i in [5,6,7,18,19,20]
		if glazing:
			_quad(_key(center),"glass",a,b,b+Vector3.UP*(height-2),a+Vector3.UP*(height-2))
			for x in range(0,int(length),2):
				_beam(a+dir*x,a+dir*x+Vector3.UP*(height-2),0.055,0.055,"trim")
		else:
			for floor_index in range(1,10):
				var y := floor_index*height/10.0
				_quad(_key(center),"glass",a+Vector3.UP*(y+0.7),b+Vector3.UP*(y+0.7),b+Vector3.UP*(y+2.3),a+Vector3.UP*(y+2.3))
				_beam(a+Vector3.UP*y,b+Vector3.UP*y,0.4,0.20,"ochre")
			for level in range(0,10,2):
				var y := level*height/10.0
				_beam(a+outward+Vector3.UP*y,b+outward+Vector3.UP*(y+height/5),0.32,0.32,"trim")
				_beam(b+outward+Vector3.UP*y,a+outward+Vector3.UP*(y+height/5),0.32,0.32,"trim")
		_beam(a+Vector3.UP*(height+0.5),b+Vector3.UP*(height+0.5),0.45,0.32,"trim")
		for x in range(0,int(length),4):
			var base := a+dir*x+Vector3.UP*(height+0.5)
			_beam(base,base+outward.normalized()*2.4,0.14,0.14,"trim")
	_sign("CYBER TOWERS",project(17.45072,78.38138)+Vector3.UP*(height-0.9),0.62,0.07)

func _facade_details(pts: PackedVector3Array,height: float,center: Vector3,tags: Dictionary) -> void:
	detailed_buildings += 1
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i+1)%pts.size()]
		var length := a.distance_to(b)
		if length < 4: continue
		var outward := ((a+b)*0.5-center).normalized()*0.13
		a += outward
		b += outward
		for level in range(1,int(height/3.4)+1):
			_beam(a+Vector3.UP*(level*3.4),b+Vector3.UP*(level*3.4),0.25,0.14,"trim")
		if tags.get("building","") in ["commercial","office"] or tags.has("name"):
			var dir := (b-a).normalized()
			for x in range(0,int(length),4):
				_beam(a+dir*x,a+dir*x+Vector3.UP*height,0.16,0.16,"trim")
			_beam(a+Vector3.UP*3.3,b+Vector3.UP*3.3,1.4,0.22,"dark")
		_beam(a+Vector3.UP*height,b+Vector3.UP*height,0.25,0.6,"trim")
	# Rooftop service plant; dimensions are architectural estimates.
	_decor_box(_key(center),"dark",center+Vector3.UP*height,Vector3(3.8,1.0,2.0))

func _sign(text: String,pos: Vector3,yaw: float,pixel: float=0.035) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = Color("23353d")
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

'''+s[b:]
# Structural surfaces should be visible from under the viaduct as well as above it.
s=s.replace('materials.pole = CityGeometry.material', 'for name in ["rail","trim","glass","dark","ochre"]:\n\t\tif materials[name] is StandardMaterial3D: materials[name].cull_mode = BaseMaterial3D.CULL_DISABLED\n\tmaterials.pole = CityGeometry.material')
s=s.replace('if str(batch.mat).begins_with("building"):', 'if str(batch.mat).begins_with("building") or batch.mat == "ochre":')
p.write_text(s)
print('Reference-based Cyber Towers, metro structures and corridor facades generated.')
