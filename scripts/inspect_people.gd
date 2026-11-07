extends SceneTree
func _initialize() -> void:
	call_deferred("inspect")
func inspect() -> void:
	for filename in ["casual-male","casual-female","casual-2-male","casual-2-female"]:
		var model = load("res://assets/characters/"+filename+".glb").instantiate()
		root.add_child(model)
		print("MODEL ",filename)
		for child in model.find_children("*","MeshInstance3D",true,false):
			print("MESH ",child.name," world AABB ",child.global_transform*child.get_aabb())
		for child in model.find_children("*","AnimationPlayer",true,false):print("ANIMS ",child.get_animation_list())
		for child in model.find_children("*","Skeleton3D",true,false):print("SKELETON ",child.get_bone_count())
		model.queue_free()
	quit()
