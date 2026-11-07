class_name CityGeometry
extends RefCounted

static func material(color: Color, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

static func vehicle(color: Color,police: bool=false,variant: String="sedan") -> Node3D:
	var visual := preload("res://scripts/vehicle_visual.gd").new()
	visual.paint_color=color
	visual.police=police
	visual.variant=variant
	return visual

static func person(color: Color,variant: int=0) -> Node3D:
	var citizen := preload("res://scripts/citizen_visual.gd").new()
	citizen.variant = variant
	citizen.clothing_color = color
	return citizen

