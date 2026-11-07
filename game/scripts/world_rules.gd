class_name WorldRules
extends RefCounted

static func clear_for(actor: CharacterBody3D,at: Vector3,exclude: Array[RID]=[],yaw: float=NAN) -> bool:
	var collider: CollisionShape3D=actor.body_shape
	var pose:=actor.global_transform
	pose.origin=at
	if not is_nan(yaw):pose.basis=Basis(Vector3.UP,yaw)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=collider.shape;query.transform=pose*collider.transform
	var excluded: Array[RID]=exclude.duplicate()
	excluded.append(actor.get_rid())
	query.collision_mask=1;query.margin=0.025;query.exclude=excluded
	return actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

static func line_clear(actor: CharacterBody3D,a: Vector3,b: Vector3,exclude: Array[RID]=[]) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(a,b,1)
	var excluded: Array[RID]=exclude.duplicate()
	excluded.append(actor.get_rid())
	query.exclude=excluded;query.hit_back_faces=true
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func safe_exit(actor: CharacterBody3D,car: CharacterBody3D) -> Dictionary:
	var half: Vector3=car.model.dimensions*0.5
	for local in [Vector3(half.x+0.85,0.12,0),Vector3(-half.x-0.85,0.12,0),Vector3(half.x+0.85,0.12,half.z*0.55),Vector3(-half.x-0.85,0.12,half.z*0.55),Vector3(0,0.12,half.z+0.9)]:
		var p: Vector3=car.global_transform*local
		var ignore: Array[RID]=[car.get_rid()]
		if not clear_for(actor,p,ignore):continue
		if not line_clear(actor,car.global_position+Vector3.UP,p+Vector3.UP,ignore):continue
		var floor_query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p-Vector3.UP*1.2,1)
		floor_query.exclude=[actor.get_rid(),car.get_rid()]
		var ground:=actor.get_world_3d().direct_space_state.intersect_ray(floor_query)
		if ground.is_empty() or ground.normal.y<0.6:continue
		p.y=ground.position.y+0.06
		if clear_for(actor,p,ignore):return {"position":p}
	return {}

static func safe_road_position(actor: CharacterBody3D,city: Node3D,wanted: Vector3) -> Dictionary:
	var road: Dictionary=city.nearest_road(wanted)
	if road.is_empty():return {}
	var tangent: Vector3=road.direction
	var left:=Vector3(tangent.z,0,-tangent.x)
	for along in [0.0,6.0,-6.0,12.0,-12.0,20.0,-20.0,32.0,-32.0]:
		for side in [0.0,1.0,-1.0]:
			var p: Vector3=road.position+tangent*along+left*side*minf(road.road.width*0.25,3.0)+Vector3.UP*0.1
			if clear_for(actor,p):return {"position":p}
	return {}
