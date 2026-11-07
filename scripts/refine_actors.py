from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'game/scripts/geometry.gd'
s=p.read_text().replace('mesh.radial_segments = 10','mesh.radial_segments = 24')
s=s.replace('box(root, Vector3(0,0.73,0), Vector3(1.84,0.65,4.1), paint)','''car_shell(root,[Vector4(-2.15,0.73,0.52,0.83),Vector4(-1.9,0.90,0.46,0.99),Vector4(-0.9,0.94,0.45,1.01),Vector4(1.35,0.94,0.46,1.04),Vector4(2.05,0.81,0.54,0.91)],paint)''')
s=s.replace('box(root, Vector3(0,1.25,0.1), Vector3(1.62,0.68,2.05), glass)','''car_shell(root,[Vector4(-1.05,0.80,0.97,1.02),Vector4(-0.45,0.73,0.98,1.58),Vector4(0.9,0.75,0.99,1.58),Vector4(1.50,0.81,0.97,1.06)],glass)''')
s=s.replace('Vector3(0,1.62,0.13), Vector3(1.68,0.10,1.9)','Vector3(0,1.60,0.23), Vector3(1.48,0.055,1.32)')
a=s.index('static func person(')
s=s[:a]+'''static func car_shell(parent: Node3D,sections: Array,mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for sec: Vector4 in sections:
		var ring := PackedVector3Array([
			Vector3(-sec.y*0.88,sec.z,sec.x),Vector3(sec.y*0.88,sec.z,sec.x),
			Vector3(sec.y,sec.z+0.12,sec.x),Vector3(sec.y,sec.w-0.10,sec.x),
			Vector3(sec.y*0.88,sec.w,sec.x),Vector3(-sec.y*0.88,sec.w,sec.x),
			Vector3(-sec.y,sec.w-0.10,sec.x),Vector3(-sec.y,sec.z+0.12,sec.x)])
		rings.append(ring)
	for j in rings.size()-1:
		for i in 8:
			var n := (i+1)%8
			for vertex: Vector3 in [rings[j][i],rings[j+1][n],rings[j+1][i],rings[j][i],rings[j][n],rings[j+1][n]]:
				st.add_vertex(vertex)
	for ring_index in [0,rings.size()-1]:
		var ring: PackedVector3Array = rings[ring_index]
		for i in range(1,7):
			st.add_vertex(ring[0])
			st.add_vertex(ring[i])
			st.add_vertex(ring[i+1])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var material_copy: StandardMaterial3D = mat.duplicate()
	material_copy.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material_copy
	parent.add_child(mesh)

static func capsule(parent: Node3D,pos: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

static func person(color: Color) -> Node3D:
	var root := Node3D.new()
	var cloth := material(color,0,0.95)
	var skin := material(Color("987258"),0,0.85)
	var pants := material(Color("263441"),0,0.95)
	var hair := material(Color("232320"))
	var shoes := material(Color("c5c5b9"))
	var torso := capsule(root,Vector3(0,1.20,0),0.25,0.68,cloth)
	torso.scale.z = 0.66
	capsule(root,Vector3(0,1.55,0),0.075,0.18,skin)
	var head := capsule(root,Vector3(0,1.72,-0.015),0.145,0.36,skin)
	head.scale.z = 0.92
	var hair_cap := capsule(root,Vector3(0,1.83,0.015),0.15,0.19,hair)
	hair_cap.scale.z = 0.94
	capsule(root,Vector3(0,1.70,-0.15),0.035,0.075,skin)
	for sign_side: float in [-1.0,1.0]:
		capsule(root,Vector3(sign_side*0.055,1.75,-0.143),0.014,0.022,hair)
		var leg := Node3D.new()
		leg.name = "LegL" if sign_side < 0 else "LegR"
		root.add_child(leg)
		leg.position = Vector3(sign_side*0.13,0.91,0)
		capsule(leg,Vector3(0,-0.20,0),0.11,0.48,pants)
		capsule(leg,Vector3(0,-0.60,0),0.085,0.45,pants)
		var shoe := capsule(leg,Vector3(0,-0.82,-0.065),0.09,0.31,shoes)
		shoe.rotation.x = PI/2
		var arm := Node3D.new()
		arm.name = "ArmL" if sign_side < 0 else "ArmR"
		root.add_child(arm)
		arm.position = Vector3(sign_side*0.29,1.43,0)
		capsule(arm,Vector3(sign_side*0.025,-0.14,0),0.085,0.39,cloth)
		capsule(arm,Vector3(sign_side*0.03,-0.43,-0.01),0.065,0.32,skin)
		capsule(arm,Vector3(sign_side*0.03,-0.60,-0.02),0.06,0.16,skin)
	# Jacket seam and collar are geometry, so they stay clear close to the camera.
	box(root,Vector3(0,1.23,-0.168),Vector3(0.018,0.50,0.008),pants)
	return root
'''
p.write_text(s)
p=root/'game/scripts/actor.gd'
s=p.read_text()
s=s.replace('var main: Node3D','''var main: Node3D
var citizen_id := 0
var activity := "commuting"
var activity_time := 0.0
var activity_cycle := 0
var danger := Vector3.ZERO
var fear_time := 0.0''')
s=s.replace('kind = type','kind = type\n\tactivity_time = 4.0+float(citizen_id%11)\n\tactivity = ["commuting","waiting","phone","shopping"][citizen_id%4]')
s=s.replace('''		if velocity.length() > 0.5:
			model.rotation.z = sin(anim_time*11)*0.035
			model.position.y = absf(sin(anim_time*11))*0.045''','''		var motion := Vector2(velocity.x,velocity.z).length()
		var stride := sin(anim_time*(8.0 if motion < 5 else 12.0))*minf(motion/4.0,1.0)*0.65
		model.get_node("LegL").rotation.x = stride
		model.get_node("LegR").rotation.x = -stride
		model.get_node("ArmL").rotation.x = -stride*0.8
		model.get_node("ArmR").rotation.x = stride*0.8
		if not controlled and activity == "phone": model.get_node("ArmR").rotation.x = -2.2
		model.position.y = absf(stride)*0.035''')
s=s.replace('func _ai(_dt: float) -> void:\n','''func _ai(_dt: float) -> void:
	if kind == "person":
		activity_time -= _dt
		fear_time = maxf(0,fear_time-_dt)
		if fear_time > 0:
			var flee := (global_position-danger).normalized()
			velocity.x = flee.x*5.8
			velocity.z = flee.z*5.8
			rotation.y = atan2(-flee.x,-flee.z)
			return
		if activity_time <= 0:
			activity_cycle += 1
			activity = ["commuting","phone","commuting","waiting","shopping"][(citizen_id+activity_cycle)%5]
			activity_time = 5.0+float((citizen_id*7+activity_cycle*3)%14)
		if activity in ["waiting","phone","shopping"]:
			velocity.x = 0
			velocity.z = 0
			return
''')
s += '''
func react_to_danger(pos: Vector3) -> void:
	if kind == "person" and not controlled and position.distance_squared_to(pos) < 70*70:
		danger = pos
		fear_time = 5.0+citizen_id%5
'''
p.write_text(s)
p=root/'game/scripts/main.gd'
s=p.read_text().replace('actor.main = self','actor.main = self\n\tactor.citizen_id = actors.size()')
s=s.replace('\tammo -= 1\n\tadd_heat(1)','\tammo -= 1\n\tfor citizen in actors: citizen.react_to_danger(focus_position())\n\tadd_heat(1)')
p.write_text(s)
print('Articulated people, independent routines and sculpted vehicle bodies updated.')
