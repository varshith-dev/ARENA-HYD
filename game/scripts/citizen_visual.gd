extends Node3D

const MODELS := [preload("res://assets/characters/casual-character.glb"),preload("res://assets/characters/woman-casual.glb"),preload("res://assets/characters/business-man.glb"),preload("res://assets/characters/worker.glb"),preload("res://assets/characters/hoodie-character.glb")]
var variant := 0
var clothing_color := Color("536c7d")
var animation: AnimationPlayer
var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var avatar: Node3D
var current_state := ""
var previous_activity := ""
var action_time := 0.0
var height_metres := 1.76
var fire_time := 0.0

func _ready() -> void:
	avatar = MODELS[posmod(variant,MODELS.size())].instantiate()
	avatar.name = "Avatar"
	add_child(avatar)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in avatar.find_children("*","MeshInstance3D",true,false):
		var box: AABB = global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		mesh.visibility_range_end = 180
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var mat: StandardMaterial3D = original.duplicate()
				mat.roughness = 0.88
				var material_name := mat.resource_name.to_lower()
				if material_name in ["shirt","white","purple","suit"]:mat.albedo_color = clothing_color
				if material_name in ["skin","skin_darker"]:
					mat.albedo_color = [Color("a97959"),Color("b68b6b"),Color("885b42"),Color("c19473"),Color("9c6c50")][posmod(variant,5)]
				if material_name in ["hair","hairbase","eyebrows","moustache"]:mat.albedo_color=Color("29241f")
				mesh.set_surface_override_material(surface,mat)
	var factor := height_metres/maxf(bounds.size.y,0.01)
	avatar.scale *= factor
	avatar.position.y -= bounds.position.y*factor
	avatar.rotation.y = PI
	animation = avatar.find_children("*","AnimationPlayer",true,false)[0]
	# The two author packs use different clip prefixes. Normalize without retargeting.
	var library := AnimationLibrary.new()
	var aliases := {"Idle":["Idle","Female_Idle"],"Walk":["Walk","Female_Walk"],"Run":["Run","Female_Run"],"Jump":["Female_Jump","Idle"],"PickUp":["Interact","Female_Standing"],"Death":["Death","Female_Death"],"Shoot_OneHanded":["Gun_Shoot","Female_Punch"]}
	for state in aliases:
		for suffix in aliases[state]:
			var found := false
			for clip in animation.get_animation_list():
				if str(clip).get_slice("|",1)==suffix or str(clip)==suffix:
					var copy: Animation=animation.get_animation(clip).duplicate()
					copy.loop_mode=Animation.LOOP_LINEAR if state in ["Idle","Walk","Run"] else Animation.LOOP_NONE
					library.add_animation(state,copy);found=true;break
			if found:break
	animation.add_animation_library("Locomotion",library)
	animation_tree = AnimationTree.new()
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation)
	var machine := AnimationNodeStateMachine.new()
	var states := ["Idle","Walk","Run","Jump","PickUp","Death","Shoot_OneHanded"]
	for i in states.size():
		var state := AnimationNodeAnimation.new()
		state.animation = "Locomotion/"+states[i]
		machine.add_node(states[i],state,Vector2((i%3)*180,(i/3)*120))
	for a in states:
		for b in states:
			if a==b:continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.18
			machine.add_transition(a,b,transition)
	animation_tree.tree_root = machine
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true
	playback = animation_tree.get("parameters/playback")
	playback.start("Idle")
	animation_tree.advance(0)

func animate(dt: float,speed: float,grounded: bool,activity: String,health: float) -> void:
	if animation_tree==null:return
	if activity!=previous_activity and activity=="shopping":action_time=1.3
	previous_activity=activity
	action_time=maxf(0,action_time-dt)
	fire_time=maxf(0,fire_time-dt)
	var state := "Run" if speed>3.0 else "Walk" if speed>0.15 else "Idle"
	if not grounded and speed>0.1:state="Jump"
	if action_time>0.0 and speed<0.15:state="PickUp"
	if fire_time>0:state="Shoot_OneHanded"
	if health<=0:state="Death"
	if state!=current_state:
		playback.travel(state)
		current_state=state
	var rate := clampf(speed/1.5,0.6,1.6) if state=="Walk" else clampf(speed/5.2,0.85,1.25) if state=="Run" else 1.0
	animation_tree.advance(dt*rate)

func fire() -> void:
	if playback!=null:
		fire_time=0.4
