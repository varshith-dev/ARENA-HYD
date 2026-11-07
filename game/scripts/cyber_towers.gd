extends RefCounted
## Reference reconstruction of OSM way 68883448, in metres.
## Footprint: OSM. Facade arrangement: supplied Street View. Heights estimated.

static func build(city: Node3D, pts: PackedVector3Array, height: float) -> void:
	var center: Vector3 = city.project(17.450482,78.381117)
	var key: Vector2i = city._key(center)
	city.detailed_buildings += 1
	city._polygon(pts,height-0.15,"roof")
	# Two recessed entrance slots interrupt the circular sandstone shell.
	for edge in [5,7,18,20]:
		var a := pts[edge]
		var b := pts[(edge+1)%pts.size()]
		var normal := (b-a).cross(Vector3.UP).normalized()
		if normal.dot((a+b)*0.5-center) < 0: normal = -normal
		city._quad(key,"ochre",a,b,b+Vector3.UP*height,a+Vector3.UP*height)
		var dir := (b-a).normalized()
		for floor_index in 10:
			var p := a.lerp(b,0.14)+normal*0.025+Vector3.UP*(floor_index*3.4+1.3)
			city._quad(key,"glass_dark",p-dir*0.14,p+dir*0.14,p+dir*0.14+Vector3.UP*1.15,p-dir*0.14+Vector3.UP*1.15)
		city._beam(a+Vector3.UP*height,b+Vector3.UP*height,0.16,0.20,"ochre")
	for edge in [6,19]:
		_glazed_slot(city,pts[edge],pts[edge+1],height,center)
	# Interpolate the two convex arcs at sub-metre spacing, preserving OSM endpoints.
	for interval in [Vector2i(8,18),Vector2i(21,31)]:
		var curve := PackedVector3Array()
		for j in range(interval.x,interval.y):
			var a := pts[j%pts.size()]-center
			var b := pts[(j+1)%pts.size()]-center
			var angle_a := atan2(a.z,a.x)
			var delta := angle_difference(angle_a,atan2(b.z,b.x))
			var steps := maxi(2,ceili(a.distance_to(b)/0.8))
			for s in steps:
				var t := float(s)/steps
				var angle := angle_a+delta*t
				curve.append(center+Vector3(cos(angle),0,sin(angle))*lerpf(a.length(),b.length(),t))
		curve.append(pts[interval.y%pts.size()])
		_arc(city,curve,center,height)
	# The entrance lintels are opaque metal cladding, not glass or a solid roof crown.
	for edge in [6,19]:
		var a := pts[edge]
		var b := pts[edge+1]
		var outward := ((a+b)*0.5-center).normalized()
		city._beam(a+Vector3.UP*(height-1.2),b+Vector3.UP*(height-1.2),0.55,2.4,"trim")
		for j in range(1,ceili(a.distance_to(b)/0.6)):
			var p := a.lerp(b,float(j)/ceili(a.distance_to(b)/0.6))+outward*0.29
			city._beam(p+Vector3.UP*(height-2.4),p+Vector3.UP*height,0.012,0.018,"seam")
		city._sign("CYBER TOWERS",(a+b)*0.5+outward*0.4+Vector3.UP*(height-0.95),atan2(outward.x,outward.z),0.009)
	# Small rooftop plant remains below the open crown from the street.
	city._decor_box(key,"roof",center+Vector3.UP*height,Vector3(18,1.0,12))
	city._decor_box(key,"trim",center+Vector3(8,height+1,0),Vector3(5,1.3,3))
	_landscape(city,center)

static func _landscape(city: Node3D,center: Vector3) -> void:
	var key: Vector2i = city._key(center)
	# Frontage planting and footpath proportions are estimated from the supplied image.
	for i in 80:
		var angle_a := deg_to_rad(-110.0+i*2)
		var angle_b := angle_a+deg_to_rad(2)
		var a := Vector3(cos(angle_a),0,sin(angle_a))
		var b := Vector3(cos(angle_b),0,sin(angle_b))
		city._quad(key,"paving",center+a*49+Vector3.UP*0.06,center+b*49+Vector3.UP*0.06,center+b*52+Vector3.UP*0.06,center+a*52+Vector3.UP*0.06)
		city._beam(center+a*53+Vector3.UP*0.45,center+b*53+Vector3.UP*0.45,0.25,0.9,"rail")
		city._beam(center+a*53+Vector3.UP*1.7,center+b*53+Vector3.UP*1.7,0.045,0.045,"dark")
		for j in 3:
			var p := center+(a*53).lerp(b*53,float(j)/3)
			city._beam(p+Vector3.UP*0.9,p+Vector3.UP*1.72,0.025,0.025,"dark")
	for i in 15:
		var angle := deg_to_rad(-100.0+i*10.5)
		var p := center+Vector3(cos(angle),0,sin(angle))*46.5
		city._beam(p,p+Vector3(0.25,5.2,0),0.22,0.24,"trunk")
		for j in 3:
			var branch := Vector3(cos(j*TAU/3+i)*1.8,5.2+float(j)*0.5,sin(j*TAU/3+i)*1.8)
			city._beam(p+Vector3.UP*3.2,p+branch,0.075,0.08,"trunk")
			city._canopy(key,p+branch,Vector3(2.4,1.8,2.4))

static func _glazed_slot(city: Node3D,a: Vector3,b: Vector3,height: float,center: Vector3) -> void:
	var outward := ((a+b)*0.5-center).normalized()
	var count := ceili(a.distance_to(b)/1.15)
	var curve := PackedVector3Array()
	for i in count+1:
		var t := float(i)/count
		curve.append(a.lerp(b,t)+outward*(sin(t*PI)*1.6))
	for i in count:
		var p := curve[i]
		var q := curve[i+1]
		for floor_index in 20:
			var y := floor_index*(height-2.4)/20
			var top := (floor_index+1)*(height-2.4)/20
			city._quad(city._key(center),"hero_glass" if (i+floor_index)%7 else "hero_glass_alt",p+Vector3.UP*y,q+Vector3.UP*y,q+Vector3.UP*top,p+Vector3.UP*top)
			city._beam(p+outward*0.035+Vector3.UP*y,q+outward*0.035+Vector3.UP*y,0.035,0.035,"mullion")
		city._beam(p+outward*0.04,p+outward*0.04+Vector3.UP*(height-2.4),0.045,0.045,"mullion")

static func _arc(city: Node3D,curve: PackedVector3Array,center: Vector3,height: float) -> void:
	var key: Vector2i = city._key(center)
	var distances := PackedFloat32Array([0.0])
	for i in curve.size()-1:
		var a := curve[i]
		var b := curve[i+1]
		var na := (a-center).normalized()
		var nb := (b-center).normalized()
		distances.append(distances[-1]+a.distance_to(b))
		for floor_index in 10:
			var y := floor_index*height/10.0
			var next := (floor_index+1)*height/10.0
			# Bands and returns give real depth; windows sit 30 cm behind the stone.
			city._quad(key,"ochre",a+Vector3.UP*y,b+Vector3.UP*y,b+Vector3.UP*(y+1.12),a+Vector3.UP*(y+1.12))
			city._quad(key,"glass_dark",a-na*0.3+Vector3.UP*(y+1.12),b-nb*0.3+Vector3.UP*(y+1.12),b-nb*0.3+Vector3.UP*next,a-na*0.3+Vector3.UP*next)
			city._quad(key,"ochre",a+Vector3.UP*(y+1.12),b+Vector3.UP*(y+1.12),b-nb*0.32+Vector3.UP*(y+1.12),a-na*0.32+Vector3.UP*(y+1.12))
			city._quad(key,"ochre",a-na*0.32+Vector3.UP*next,b-nb*0.32+Vector3.UP*next,b+Vector3.UP*next,a+Vector3.UP*next)
			if i%3 == 0: city._beam(a-na*0.24+Vector3.UP*(y+1.12),a-na*0.24+Vector3.UP*next,0.045,0.045,"mullion")
		# Continuous outer and inner crown rings, with an open space between them.
		city._beam(a+na*1.6+Vector3.UP*(height+1.55),b+nb*1.6+Vector3.UP*(height+1.55),0.17,0.24,"ivory")
		city._beam(a-na*0.7+Vector3.UP*(height+1.55),b-nb*0.7+Vector3.UP*(height+1.55),0.17,0.24,"ivory")
	var total := distances[-1]
	var bays := maxi(1,roundi(total/7.2))
	var bay_width := total/bays
	for bay in bays:
		for floor_index in range(0,10,2):
			for sign_dir in [-1,1]:
				for part in 8:
					var u := float(part)/8
					var v := float(part+1)/8
					var a := _sample(curve,distances,(bay+u)*bay_width)
					var b := _sample(curve,distances,(bay+v)*bay_width)
					var ya := (floor_index+(u if sign_dir>0 else 1-u)*2)*height/10
					var yb := (floor_index+(v if sign_dir>0 else 1-v)*2)*height/10
					city._beam(a+(a-center).normalized()*0.18+Vector3.UP*ya,b+(b-center).normalized()*0.18+Vector3.UP*yb,0.22,0.24,"ivory")
	for i in range(0,ceili(total/2.2)):
		var p := _sample(curve,distances,i*2.2)
		var n := (p-center).normalized()
		city._beam(p-n*0.7+Vector3.UP*(height+1.55),p+n*1.6+Vector3.UP*(height+1.55),0.13,0.16,"ivory")
		city._beam(p+Vector3.UP*height,p+n*1.6+Vector3.UP*(height+1.55),0.13,0.13,"ivory")

static func _sample(curve: PackedVector3Array,distances: PackedFloat32Array,d: float) -> Vector3:
	for i in curve.size()-1:
		if distances[i+1] >= d:
			return curve[i].lerp(curve[i+1],clampf((d-distances[i])/(distances[i+1]-distances[i]),0,1))
	return curve[-1]
