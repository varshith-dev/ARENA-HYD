from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'game/scripts/city.gd'
s=p.read_text(encoding='utf-8')
start=s.index('func _canopy(')
end=s.index('func _beam(',start)
s=s[:start]+'''func _canopy(key: Vector2i,center: Vector3,radius: Vector3) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = int(center.x*731+center.z*191+center.y*47)
	for i in 110:
		var theta := random.randf()*TAU
		var elevation := random.randf_range(-1,1)
		var ring := sqrt(1-elevation*elevation)
		var p := center+Vector3(cos(theta)*ring,elevation,sin(theta)*ring)*radius*pow(random.randf(),0.33)
		var basis := Basis.from_euler(Vector3(random.randf_range(-0.7,0.7),random.randf()*TAU,random.randf_range(-0.4,0.4)))
		var x := basis.x*random.randf_range(0.4,0.7)
		var y := basis.y*random.randf_range(0.7,1.1)
		_quad(key,"foliage",p-x-y,p+x-y,p+x+y,p-x+y)

func _pair_point(p: Vector3,id: int) -> Dictionary:
	var best := 8.0*8.0
	var other := p
	var other_id := id
	for segment in metro_segments:
		if segment.id == id: continue
		if p.distance_squared_to((segment.a+segment.b)*0.5) > 40000: continue
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
	var run := 10.0
	for i in points.size()-1:
		var a := points[i]
		var b := points[i+1]
		if a.distance_to(b) > 500: continue
		if metro:
			var pair := _pair_point((a+b)*0.5,id)
			if int(pair.id) < id: continue
			a = _pair_point(a,id).position
			b = _pair_point(b,id).position
		var dir := (b-a).normalized()
		var side := Vector3(-dir.z,0,dir.x)
		var key := _key((a+b)*0.5)
		if elevated:
			# Single paired-track box girder: broad top flange, tapered underside.
			var profile := [Vector2(-4.7,11.8),Vector2(4.7,11.8),Vector2(4.7,11.45),Vector2(3.1,11.15),Vector2(2.55,9.65),Vector2(-2.55,9.65),Vector2(-3.1,11.15),Vector2(-4.7,11.45)]
			for j in profile.size():
				var u: Vector2 = profile[j]
				var v: Vector2 = profile[(j+1)%profile.size()]
				_quad(key,"rail",a+side*u.x+Vector3.UP*u.y,b+side*u.x+Vector3.UP*u.y,b+side*v.x+Vector3.UP*v.y,a+side*v.x+Vector3.UP*v.y)
			for sign_side in [-1.0,1.0]:
				_beam(a+side*4.6*sign_side+Vector3.UP*12.25,b+side*4.6*sign_side+Vector3.UP*12.25,0.22,0.9,"rail")
		else: _strip(a,b,8.5,0.18,"rail")
		var rail_y := 11.98 if elevated else 0.36
		for track in [-2.0,2.0]:
			for sign_side in [-1.0,1.0]:
				_beam(a+side*(track+sign_side*0.72)+Vector3.UP*rail_y,b+side*(track+sign_side*0.72)+Vector3.UP*rail_y,0.07,0.12,"dark")
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

'''+s[end:]
start=s.index('func _cyber_towers(')
end=s.index('func _facade_details(',start)
s=s[:start]+s[end:]
# Physical trim proportions outside the hand-modelled landmark.
s=s.replace('0.25,0.14,"trim"','0.09,0.10,"trim"').replace('0.16,0.16,"trim"','0.07,0.07,"trim"')
s=s.replace('instance.visibility_range_end = 1100','instance.visibility_range_end = 360 if batch.mat == "foliage" else 950')
s=s.replace('child.visibility_range_end = 1400 if high else 650','child.visibility_range_end = (360 if high else 240) if child.material_override == materials.foliage else (950 if high else 650)')
p.write_text(s,encoding='utf-8')
