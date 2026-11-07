extends Node3D
## Original metre-scale street vehicles. Shared body meshes and rotating wheels.
var variant := "sedan"
var paint_color := Color("bbc5ca")
var police := false
var dimensions := Vector3(1.86,1.62,4.48)
var wheel_radius := 0.35
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var buckets: Dictionary = {}
var mats: Dictionary = {}
static var mesh_cache: Dictionary = {}
static var tire_mesh: TorusMesh
static var rim_mesh: CylinderMesh

func _ready() -> void:
	if police:variant="suv"
	if variant=="suv":dimensions=Vector3(1.94,1.88,4.65);wheel_radius=0.39
	elif variant=="hatchback":dimensions=Vector3(1.76,1.56,3.82);wheel_radius=0.33
	elif variant=="auto":dimensions=Vector3(1.40,1.90,2.68);wheel_radius=0.25
	elif variant=="bus":dimensions=Vector3(2.45,3.15,9.0);wheel_radius=0.50
	_materials()
	if not mesh_cache.has(variant):
		if variant=="auto":_auto_body()
		elif variant=="bus":_bus_body()
		else:_car_body()
		var cached: Dictionary = {}
		for name in buckets:
			var st: SurfaceTool = buckets[name]
			st.index()
			cached[name]=st.commit()
		mesh_cache[variant]=cached
	for material_name in mesh_cache[variant]:
		var mesh := MeshInstance3D.new()
		mesh.mesh=mesh_cache[variant][material_name]
		mesh.material_override=mats[material_name]
		mesh.visibility_range_end=240
		add_child(mesh)
	_make_wheels()
	if police:
		CityGeometry.box(self,Vector3(0,dimensions.y+0.05,0.2),Vector3(1.05,0.08,0.24),mats.rubber)
		for side in [-1,1]:
			var beacon:=CityGeometry.box(self,Vector3(side*0.31,dimensions.y+0.16,0.2),Vector3(0.35,0.14,0.22),CityGeometry.material(Color("d43835") if side<0 else Color("367de0")))
			beacon.name="BeaconRed" if side<0 else "BeaconBlue"
	if variant=="bus":
		var label:=Label3D.new();label.text="RAIDURG  ·  HITEC CITY";label.font_size=42;label.pixel_size=0.0018;label.outline_size=0;label.modulate=Color("f4cd79");label.rotation.y=PI;label.position=Vector3(0,2.9,-4.52);label.visibility_range_end=45;add_child(label)

func _materials() -> void:
	mats.paint=CityGeometry.material(Color("e4e5e1") if police else paint_color,0.5,0.27)
	mats.paint.clearcoat_enabled=true;mats.paint.clearcoat=0.65;mats.paint.clearcoat_roughness=0.16
	mats.rubber=CityGeometry.material(Color("202327"),0.02,0.9)
	mats.interior=CityGeometry.material(Color("384047"),0.0,0.88)
	mats.chrome=CityGeometry.material(Color("aeb6bb"),0.8,0.23)
	mats.glass=CityGeometry.material(Color(0.23,0.34,0.40,0.44),0.3,0.16)
	mats.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mats.glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	mats.head=CityGeometry.material(Color("e8e9d9"),0.25,0.19)
	mats.tail=CityGeometry.material(Color("a62d28"),0.25,0.23)
	mats.yellow=CityGeometry.material(Color("d99d29"),0.3,0.32)
	mats.green=CityGeometry.material(Color("4c7467"),0.3,0.35)
	mats.plate=CityGeometry.material(Color("d6dad7"),0,0.65)

func _quad(mat: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	if not buckets.has(mat):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);buckets[mat]=st
	var st: SurfaceTool=buckets[mat]
	var normal: Vector3=(b-a).cross(c-a).normalized()
	for point in [a,c,b,a,d,c]:st.set_normal(normal);st.add_vertex(point)

func _shell_quad(mat: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	if (b-a).cross(c-a).dot((a+b+c+d)*0.25-Vector3(0,0.8,0))<0:_quad(mat,a,d,c,b)
	else:_quad(mat,a,b,c,d)

func _box(mat: String,p: Vector3,s: Vector3) -> void:
	var x:=Vector3(s.x/2,0,0);var y:=Vector3(0,s.y/2,0);var z:=Vector3(0,0,s.z/2)
	_quad(mat,p+x-z-y,p-x-z-y,p-x-z+y,p+x-z+y)
	_quad(mat,p-x+z-y,p+x+z-y,p+x+z+y,p-x+z+y)
	_quad(mat,p-x-z-y,p-x+z-y,p-x+z+y,p-x-z+y)
	_quad(mat,p+x+z-y,p+x-z-y,p+x-z+y,p+x+z+y)
	_quad(mat,p-x+z+y,p+x+z+y,p+x-z+y,p-x-z+y)
	_quad(mat,p-x-z-y,p+x-z-y,p+x+z-y,p-x+z-y)

func _beam(mat: String,a: Vector3,b: Vector3,width: float,depth: float) -> void:
	var forward:=(b-a).normalized()
	var side:=forward.cross(Vector3.UP).normalized()
	if side.length_squared()<0.01:side=Vector3.RIGHT
	var up:=side.cross(forward).normalized()*depth/2
	side*=width/2
	_quad(mat,a-side-up,b-side-up,b+side-up,a+side-up)
	_quad(mat,a+side+up,b+side+up,b-side+up,a-side+up)
	_quad(mat,a-side+up,b-side+up,b-side-up,a-side-up)
	_quad(mat,a+side-up,b+side-up,b+side+up,a+side+up)

func _car_body() -> void:
	var half:=dimensions.z/2
	var width:=dimensions.x/2
	var shoulder:=1.08 if variant=="suv" else 0.98
	var axle:=dimensions.z*0.29
	_box("interior",Vector3(0,0.48,0),Vector3(dimensions.x-0.32,0.22,dimensions.z-0.3))
	# Curved side panels are cut above the wheel openings instead of covering them.
	for i in 72:
		var za:=lerpf(-half,half,float(i)/72)
		var zb:=lerpf(-half,half,float(i+1)/72)
		var wa:=width*(0.91+0.09*sin((za+half)/dimensions.z*PI))
		var wb:=width*(0.91+0.09*sin((zb+half)/dimensions.z*PI))
		var ya:=shoulder-0.13*pow(absf(za)/half,5)
		var yb:=shoulder-0.13*pow(absf(zb)/half,5)
		var ba:=_arch_bottom(za,axle)
		var bb:=_arch_bottom(zb,axle)
		for side in [-1.0,1.0]:
			_shell_quad("paint",Vector3(side*wa,ba,za),Vector3(side*wb,bb,zb),Vector3(side*wb,yb-0.07,zb),Vector3(side*wa,ya-0.07,za))
			_shell_quad("paint",Vector3(side*wa,ya-0.07,za),Vector3(side*wb,yb-0.07,zb),Vector3(side*wb*0.94,yb,zb),Vector3(side*wa*0.94,ya,za))
		_shell_quad("paint",Vector3(-wa*0.94,ya,za),Vector3(wa*0.94,ya,za),Vector3(wb*0.94,yb,zb),Vector3(-wb*0.94,yb,zb))
	for z in [-half,half]:
		_box("paint",Vector3(0,0.65,z),Vector3(width*1.8,0.47,0.10))
		_box("rubber",Vector3(0,0.43,z),Vector3(width*1.65,0.12,0.12))
	var front_base:=-dimensions.z*0.20
	var front_top:=-dimensions.z*0.08
	var rear_top:=dimensions.z*(0.24 if variant in ["suv","hatchback"] else 0.20)
	var rear_base:=dimensions.z*(0.40 if variant in ["suv","hatchback"] else 0.34)
	var roof_y:=dimensions.y-0.04
	var roof_w:=width*0.77
	for i in 12:
		var xa:=lerpf(-roof_w,roof_w,float(i)/12)
		var xb:=lerpf(-roof_w,roof_w,float(i+1)/12)
		var ya:=roof_y-0.055*pow(xa/roof_w,4)
		var yb:=roof_y-0.055*pow(xb/roof_w,4)
		_shell_quad("paint",Vector3(xa,ya,front_top),Vector3(xb,yb,front_top),Vector3(xb,yb,rear_top),Vector3(xa,ya,rear_top))
	_shell_quad("glass",Vector3(-width*0.88,shoulder,front_base),Vector3(width*0.88,shoulder,front_base),Vector3(roof_w,roof_y-0.05,front_top),Vector3(-roof_w,roof_y-0.05,front_top))
	_shell_quad("glass",Vector3(-roof_w,roof_y-0.05,rear_top),Vector3(roof_w,roof_y-0.05,rear_top),Vector3(width*0.88,shoulder,rear_base),Vector3(-width*0.88,shoulder,rear_base))
	for side in [-1.0,1.0]:
		var a:=Vector3(side*width*0.88,shoulder,front_base)
		var b:=Vector3(side*roof_w,roof_y-0.05,front_top)
		var c:=Vector3(side*roof_w,roof_y-0.05,rear_top)
		var d:=Vector3(side*width*0.88,shoulder,rear_base)
		_shell_quad("glass",a,b,c,d)
		_beam("paint",a,b,0.075,0.075);_beam("paint",c,d,0.11,0.10)
		_beam("rubber",a,d,0.045,0.045)
		_beam("paint",b,c,0.055,0.055)
		var divider:=lerpf(front_top,rear_top,0.48)
		_beam("rubber",Vector3(side*width*0.88,shoulder,divider),Vector3(side*roof_w,roof_y-0.05,divider),0.08,0.08)
		for door in [front_base,divider,rear_base]:_beam("rubber",Vector3(side*width*1.002,0.48,door),Vector3(side*width*1.002,shoulder-0.1,door),0.012,0.012)
		for handle_z in [divider-0.18,rear_base-0.17]:_box("chrome",Vector3(side*width*1.01,shoulder-0.12,handle_z),Vector3(0.035,0.035,0.15))
		_box("paint",Vector3(side*(width+0.085),shoulder+0.13,front_base+0.05),Vector3(0.22,0.11,0.24))
		_box("chrome",Vector3(side*(width+0.09),shoulder+0.13,front_base+0.16),Vector3(0.16,0.075,0.012))
		_box("head",Vector3(side*width*0.64,0.87,-half-0.065),Vector3(0.45,0.115,0.025))
		_box("tail",Vector3(side*width*0.68,0.84,half+0.06),Vector3(0.38,0.14,0.025))
		_box("yellow",Vector3(side*width*0.87,0.86,-half-0.08),Vector3(0.065,0.06,0.025))
		_box("interior",Vector3(side*0.43,0.85,0.15),Vector3(0.55,0.18,0.62))
		_box("interior",Vector3(side*0.43,1.08,0.45),Vector3(0.55,0.65,0.13))
		_box("interior",Vector3(side*0.43,1.44,0.45),Vector3(0.28,0.20,0.12))
		if variant=="suv":_beam("chrome",Vector3(side*roof_w*0.9,roof_y+0.07,front_top+0.1),Vector3(side*roof_w*0.9,roof_y+0.07,rear_top-0.1),0.045,0.05)
	_box("rubber",Vector3(0,0.66,-half-0.06),Vector3(0.84,0.24,0.035))
	for i in 7:_box("chrome",Vector3(-0.34+i*0.114,0.66,-half-0.085),Vector3(0.025,0.20,0.025))
	_box("plate",Vector3(0,0.46,-half-0.09),Vector3(0.45,0.09,0.012))
	_box("plate",Vector3(0,0.58,half+0.07),Vector3(0.43,0.10,0.012))
	_box("interior",Vector3(0,0.98,front_base+0.08),Vector3(width*1.6,0.12,0.22))
	_box("interior",Vector3(0,0.91,0.95),Vector3(width*1.5,0.2,0.45))
	for x in [-0.35,0.35]:_beam("rubber",Vector3(x,shoulder+0.025,front_base-0.02),Vector3(x+0.2,shoulder+0.045,front_base+0.13),0.015,0.015)

func _arch_bottom(z: float,axle: float) -> float:
	var value:=0.42
	for wheel_z in [-axle,axle]:
		var distance:=absf(z-wheel_z)
		var arch:=wheel_radius+0.075
		if distance<arch:value=maxf(value,wheel_radius+sqrt(arch*arch-distance*distance))
	return value

func _auto_body() -> void:
	_box("yellow",Vector3(0,0.55,0.25),Vector3(1.35,0.45,2.10))
	_box("green",Vector3(0,0.93,1.08),Vector3(1.35,0.55,0.24))
	_box("interior",Vector3(0,0.78,0.65),Vector3(1.15,0.18,0.45))
	_box("interior",Vector3(0,1.02,0.89),Vector3(1.15,0.48,0.12))
	_box("interior",Vector3(0,0.82,-0.36),Vector3(0.42,0.18,0.45))
	_box("interior",Vector3(0,1.03,-0.12),Vector3(0.42,0.42,0.12))
	for side in [-1.0,1.0]:
		_beam("rubber",Vector3(side*0.60,0.76,-0.9),Vector3(side*0.53,1.76,-0.67),0.045,0.045)
		_beam("rubber",Vector3(side*0.60,0.78,1.05),Vector3(side*0.54,1.79,1.05),0.055,0.055)
		_beam("chrome",Vector3(side*0.67,0.57,0.1),Vector3(side*0.67,0.57,0.9),0.045,0.045)
		_box("tail",Vector3(side*0.49,0.69,1.22),Vector3(0.12,0.13,0.02))
	_shell_quad("glass",Vector3(-0.58,0.96,-0.92),Vector3(0.58,0.96,-0.92),Vector3(0.53,1.72,-0.68),Vector3(-0.53,1.72,-0.68))
	_box("yellow",Vector3(0,0.77,-0.94),Vector3(1.18,0.32,0.12))
	_box("head",Vector3(0,0.78,-1.02),Vector3(0.22,0.18,0.025))
	for i in 16:
		var xa:=lerpf(-0.66,0.66,float(i)/16)
		var xb:=lerpf(-0.66,0.66,float(i+1)/16)
		var ya:=1.76+0.14*cos(xa/0.66*PI/2)
		var yb:=1.76+0.14*cos(xb/0.66*PI/2)
		_shell_quad("rubber",Vector3(xa,ya,-0.77),Vector3(xb,yb,-0.77),Vector3(xb,yb,1.15),Vector3(xa,ya,1.15))
	_box("rubber",Vector3(0,1.35,1.14),Vector3(1.30,0.7,0.04))
	_box("glass",Vector3(0,1.42,1.17),Vector3(0.8,0.34,0.015))
	_beam("chrome",Vector3(-0.2,1.16,-0.55),Vector3(0.2,1.16,-0.55),0.035,0.035)

func _bus_body() -> void:
	_box("green",Vector3(0,0.78,0),Vector3(2.4,0.72,8.9))
	_box("paint",Vector3(0,1.32,0),Vector3(2.42,0.34,8.93))
	_box("paint",Vector3(0,2.96,0),Vector3(2.4,0.27,8.9))
	_box("interior",Vector3(0,1.08,0),Vector3(2.25,0.15,8.8))
	for side in [-1.0,1.0]:
		for i in 8:
			var z:=-3.75+i*1.02
			_box("glass",Vector3(side*1.205,2.13,z),Vector3(0.015,1.3,0.96))
			_box("paint",Vector3(side*1.215,2.13,z-0.51),Vector3(0.05,1.45,0.065))
			_box("interior",Vector3(side*0.68,1.37,z+0.15),Vector3(0.70,0.15,0.5))
			_box("interior",Vector3(side*0.68,1.70,z+0.38),Vector3(0.70,0.65,0.10))
		_box("head",Vector3(side*0.85,0.92,-4.51),Vector3(0.48,0.17,0.025))
		_box("tail",Vector3(side*0.92,0.94,4.51),Vector3(0.16,0.37,0.025))
		_beam("rubber",Vector3(side*1.18,2.6,-4.2),Vector3(side*1.4,2.4,-4.5),0.05,0.05)
		_box("rubber",Vector3(side*1.4,2.3,-4.5),Vector3(0.12,0.32,0.18))
	_box("glass",Vector3(0,2.15,-4.46),Vector3(2.24,1.35,0.025))
	_box("glass",Vector3(0,2.1,4.46),Vector3(2.22,1.3,0.025))
	_box("rubber",Vector3(0,2.92,-4.49),Vector3(1.96,0.23,0.025))
	_box("rubber",Vector3(0,0.63,-4.52),Vector3(2.32,0.16,0.10))
	_box("rubber",Vector3(0,0.63,4.52),Vector3(2.32,0.16,0.10))
	for i in 8:_box("rubber",Vector3(-0.38+i*0.108,0.9,-4.51),Vector3(0.045,0.25,0.03))
	# Passenger door glazing is on the left for Indian left-hand traffic.
	_box("rubber",Vector3(-1.23,1.65,-2.95),Vector3(0.025,2.1,1.05))
	_box("glass",Vector3(-1.25,1.85,-2.95),Vector3(0.012,1.5,0.9))
	_beam("chrome",Vector3(-1.26,0.7,-2.95),Vector3(-1.26,2.7,-2.95),0.035,0.035)

func _make_wheels() -> void:
	if tire_mesh==null:
		tire_mesh=TorusMesh.new();tire_mesh.inner_radius=0.63;tire_mesh.outer_radius=1.0;tire_mesh.rings=32;tire_mesh.ring_segments=12
		rim_mesh=CylinderMesh.new();rim_mesh.top_radius=0.64;rim_mesh.bottom_radius=0.64;rim_mesh.height=0.12;rim_mesh.radial_segments=24
	var axle:=dimensions.z*(0.31 if variant=="bus" else 0.29)
	var positions: Array[Vector3] = []
	if variant=="auto":positions=[Vector3(0,wheel_radius,-1.0),Vector3(-0.64,wheel_radius,0.83),Vector3(0.64,wheel_radius,0.83)]
	else:
		for side in [-1.0,1.0]:
			for z in [-axle,axle]:positions.append(Vector3(side*(dimensions.x/2-0.06),wheel_radius,z))
	for p in positions:
		var pivot:=Node3D.new();pivot.position=p;add_child(pivot)
		if p.z<0:front_wheels.append(pivot)
		var spin:=Node3D.new();pivot.add_child(spin);wheels.append(spin)
		var tire:=MeshInstance3D.new();tire.mesh=tire_mesh;tire.material_override=mats.rubber;tire.rotation.z=PI/2;tire.scale=Vector3.ONE*wheel_radius;tire.visibility_range_end=180;spin.add_child(tire)
		for side in [-1.0,1.0]:
			var rim:=MeshInstance3D.new();rim.mesh=rim_mesh;rim.material_override=mats.chrome;rim.rotation.z=PI/2;rim.scale=Vector3.ONE*wheel_radius;rim.position.x=side*wheel_radius*0.26;rim.visibility_range_end=120;spin.add_child(rim)
		# Thin spoke inserts give the wheel a readable rotating shape close up.
		var spokes:=MultiMeshInstance3D.new();var instances:=MultiMesh.new()
		var spoke_mesh:=BoxMesh.new();spoke_mesh.size=Vector3(0.02,0.045,wheel_radius*0.72)
		instances.mesh=spoke_mesh;instances.transform_format=MultiMesh.TRANSFORM_3D;instances.instance_count=6
		for spoke in 6:
			var at:=Vector3(signf(p.x)*wheel_radius*0.34,sin(spoke*TAU/6)*wheel_radius*0.38,cos(spoke*TAU/6)*wheel_radius*0.38)
			instances.set_instance_transform(spoke,Transform3D(Basis(Vector3.RIGHT,-spoke*TAU/6),at))
		spokes.multimesh=instances;spokes.material_override=mats.rubber;spokes.visibility_range_end=45;spin.add_child(spokes)

func animate(dt: float,speed: float,steering: float) -> void:
	for wheel in wheels:wheel.rotation.x-=speed/wheel_radius*dt
	for wheel in front_wheels:wheel.rotation.y=-steering*0.48
