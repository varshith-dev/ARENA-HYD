class_name ArenaActor
extends CharacterBody3D

var kind := "car"
var speed := 0.0
var health := 100.0
var steering := 0.0
var throttle := 0.0
var brake := false
var controlled := false
var police := false
var model: Node3D
var path := PackedVector3Array()
var path_index := 1
var path_direction := 1
var target: Vector3
var cruising_speed := 11.0
var impact_cooldown := 0.0
var anim_time := 0.0
var chase := false
var main: Node3D
var citizen_id := 0
var activity := "commuting"
var activity_time := 0.0
var activity_cycle := 0
var danger := Vector3.ZERO
var fear_time := 0.0
var vehicle_variant := "sedan"
var lane_offset := 1.8
var road_id := -1
var one_way := false
var route_wait := 0.0
var body_shape: CollisionShape3D

func setup(type: String, color: Color, is_police: bool = false) -> void:
	kind = type
	activity_time = 4.0+float(citizen_id%11)
	activity = ["commuting","waiting","looking around","shopping"][citizen_id%4]
	police = is_police
	vehicle_variant = ["sedan","hatchback","suv","auto","bus"][(citizen_id/2)%5]
	if citizen_id==0:vehicle_variant="suv"
	model = CityGeometry.person(color,0 if citizen_id==1 else citizen_id%5) if kind == "person" else CityGeometry.vehicle(color,police,vehicle_variant)
	add_child(model)
	var shape := CollisionShape3D.new()
	if kind == "person":
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.9
		capsule.radius = 0.32
		shape.shape = capsule
		shape.position.y = 0.95
	else:
		var box := BoxShape3D.new()
		box.size = model.dimensions*Vector3(0.96,0.90,0.96)
		shape.shape = box
		shape.position.y = model.dimensions.y*0.5
	add_child(shape)
	body_shape=shape
	floor_snap_length = 0.5
	safe_margin = 0.015
	visibility_range()

func visibility_range() -> void:
	for child in model.find_children("*","GeometryInstance3D",true,false):
		if child is GeometryInstance3D: child.visibility_range_end = 240

func tick(dt: float) -> void:
	impact_cooldown = maxf(0,impact_cooldown-dt)
	anim_time += dt
	if health <= 0:
		speed = move_toward(speed,0,dt*15)
		if kind=="person":model.animate(dt,0.0,true,activity,health)
		return
	if not controlled:
		_ai(dt)
	if kind == "person":
		velocity.y -= 25*dt
		move_and_slide()
		var motion := Vector2(velocity.x,velocity.z).length()
		model.animate(dt,motion,is_on_floor(),activity if not controlled else "player",health)
		return
	var acceleration := 8.6 if throttle >= 0 else 5.0
	if brake:
		speed = move_toward(speed,0,dt*23)
	elif absf(throttle) > 0.01:
		speed += throttle*acceleration*dt
	else:
		speed = move_toward(speed,0,dt*(1.3+absf(speed)*0.035))
	var maximum := 18.0 if vehicle_variant=="auto" else 25.0 if vehicle_variant=="bus" else 38.0
	speed = clampf(speed,-7.0,maximum if controlled else minf(maximum,23.0))
	var steer_strength := clampf(absf(speed)/5.0,0,1)/(1+absf(speed)*0.025)
	var next_yaw:=rotation.y-steering*1.15*steer_strength*signf(speed)*dt
	if absf(next_yaw-rotation.y)>0.0001:
		if WorldRules.clear_for(self,global_position,[],next_yaw):rotation.y=next_yaw
		else:speed=move_toward(speed,0,25*dt)
	var forward := -global_basis.z
	velocity = forward*speed+Vector3(0,velocity.y-25*dt,0)
	var old_speed := speed
	move_and_slide()
	# Resolve speed from blocked horizontal motion so holding the accelerator
	# cannot keep a vehicle at full speed while it is pressed against a wall.
	if get_slide_collision_count()>0:
		for index in get_slide_collision_count():
			var contact:=get_slide_collision(index)
			if absf(contact.get_normal().y)<0.55 and forward.dot(contact.get_normal())*signf(speed)<-0.25:
				speed=0.0;break
	model.rotation.z = lerpf(model.rotation.z,steering*speed*0.0018,dt*5)
	model.rotation.x = lerpf(model.rotation.x,-throttle*0.025,dt*5)
	model.animate(dt,speed,steering)
	if get_slide_collision_count() > 0 and absf(old_speed) > 5:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			if absf(collision.get_normal().y) > 0.6: continue
			speed *= 0.8
			if impact_cooldown <= 0:
				impact_cooldown = 1.0
				health -= absf(old_speed)*0.35
				if main != null: main.actor_impact(self,collision.get_collider(),absf(old_speed))
			break
	if police:
		var red := model.get_node_or_null("BeaconRed")
		var blue := model.get_node_or_null("BeaconBlue")
		if red != null:
			red.visible = fmod(anim_time,0.6) < 0.3
			blue.visible = not red.visible

func _ai(_dt: float) -> void:
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
			activity = ["commuting","looking around","commuting","waiting","shopping"][(citizen_id+activity_cycle)%5]
			activity_time = 5.0+float((citizen_id*7+activity_cycle*3)%14)
		if activity in ["waiting","looking around","shopping"]:
			velocity.x = 0
			velocity.z = 0
			if activity=="looking around":rotation.y+=sin(anim_time*0.7)*_dt*0.25
			return
	if chase and main != null:
		target = main.focus_position()
	elif path.size() > 1:
		var previous := clampi(path_index-path_direction,0,path.size()-1)
		var tangent := (path[path_index]-path[previous]).normalized()
		var point := path[path_index]+Vector3(tangent.z,0,-tangent.x)*lane_offset
		if global_position.distance_to(point) < (1.1 if kind=="person" else 5.5):
			path_index += path_direction
			if path_index >= path.size() or path_index < 0:
				if kind=="car" and main!=null:
					var next: Dictionary=main.next_traffic_road(path[-1] if path_direction>0 else path[0],road_id)
					if not next.is_empty():
						path=next.points;path_direction=1;path_index=1;road_id=next.id;one_way=next.oneway;lane_offset=clampf(next.width*0.25,1.5,3.3)
						return
					if one_way:
						path_index=clampi(path_index,0,path.size()-1);throttle=0;brake=true
						return
				path_direction *= -1
				path_index = clampi(path_index+path_direction*2,0,path.size()-1)
				if kind=="person":lane_offset*=-1
			previous=clampi(path_index-path_direction,0,path.size()-1)
			tangent=(path[path_index]-path[previous]).normalized()
			point=path[path_index]+Vector3(tangent.z,0,-tangent.x)*lane_offset
		target = point
	else:
		throttle = 0
		return
	var to := target-global_position
	to.y = 0
	if kind == "person":
		velocity.x = to.normalized().x*cruising_speed
		velocity.z = to.normalized().z*cruising_speed
		if to.length() > 0.5: rotation.y = lerp_angle(rotation.y,atan2(-to.x,-to.z),0.12)
	else:
		var desired := atan2(-to.x,-to.z)
		var difference := angle_difference(rotation.y,desired)
		steering = clampf(-difference*2.5,-1,1)
		var desired_speed := cruising_speed*(1.0-clampf(absf(difference)*0.45,0,0.78))
		if chase: desired_speed = 22.0
		throttle = 1.0 if speed < desired_speed else 0.0
		brake = speed > desired_speed+2.0
		# Stop for vehicles and walls immediately ahead.
		var origin := global_position+Vector3.UP
		var query := PhysicsRayQueryParameters3D.create(origin,origin-global_basis.z*(5+maxf(speed,0)*0.6))
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and not chase:
			brake = true
			throttle = 0

func hit(damage: float) -> void:
	health = maxf(0,health-damage)
	if health <= 0:
		if kind == "person":
			collision_layer = 0
			collision_mask = 0
		else:
			var smoke := GPUParticles3D.new()
			# Disabled cars remain physical obstacles; there is no graphic injury.
			if smoke != null: smoke.free()

func react_to_danger(pos: Vector3) -> void:
	if kind == "person" and not controlled and position.distance_squared_to(pos) < 70*70:
		danger = pos
		fear_time = 5.0+citizen_id%5
