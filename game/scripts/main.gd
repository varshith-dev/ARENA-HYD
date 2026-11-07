extends Node3D

const ActorScript = preload("res://scripts/actor.gd")
const CityScript = preload("res://scripts/city.gd")
const HudScript = preload("res://scripts/hud.gd")
var city: HitecCity
var hud: Control
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var player: ArenaActor
var vehicle: ArenaActor
var actors: Array[ArenaActor] = []
var cops: Array[ArenaActor] = []
var started := false
var paused := true
var high_quality := true
var night := false
var health := 100.0
var money := 2500
var wanted := 0
var ammo := 36
var mission_index := 0
var mission_active := false
var mission_stage := 0
var mission_target := Vector3.ZERO
var mission_locations: Array[Dictionary] = []
var mission_marker: Node3D
var toast := ""
var toast_time := 0.0
var street_name := "HITEC City"
var camera_yaw := 0.0
var camera_pitch := -0.18
var camera_mode := 0
var camera_manual := 0.0
var elapsed := 0.0
var hud_clock := 0.0
var road_clock := 0.0
var shoot_clock := 0.0
var shot_flash := 0.0
var escape_timer := 0.0
var arrest_timer := 0.0
var siren: AudioStreamPlayer
var engine_audio: AudioStreamPlayer
var sound_enabled := true
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0
var rng := RandomNumberGenerator.new()
var graph := AStar3D.new()
var graph_nodes: Dictionary = {}
var route := PackedVector3Array()
var route_mesh: MeshInstance3D
var smoke_test := false
var test_clock := 0.0
var test_world_passed := false
var test_gameplay_passed := false
var show_performance := false
var mouse_sensitivity := 0.0024
var ignore_mouse_frames := 0
var screen_capture := false
var capture_clock := 0.0
var reference_view := -1
const REFERENCE_VIEWS := [
	{"name":"Cyber Towers / northeast", "lat":17.4509238,"lon":78.3818386,"heading":240.88,"tilt":115.26},
	{"name":"Cyber Towers / north", "lat":17.4512037,"lon":78.3815924,"heading":206.22,"tilt":109.83},
	{"name":"Trident / toward Raidurg", "lat":17.4500177,"lon":78.3795362,"heading":209.98,"tilt":110.01,"fov":90},
	{"name":"Cyber Pearl / HDFC Bank", "lat":17.446125,"lon":78.377562,"heading":193.46,"tilt":99.5,"fov":90},
	{"name":"TCS Deccan Park", "lat":17.4447356,"lon":78.3772674,"heading":93.99,"tilt":110.47,"fov":75}
]

func _ready() -> void:
	smoke_test = "--test" in OS.get_cmdline_user_args()
	rng.seed = 20261107
	_input_setup()
	_load_save()
	high_quality = not OS.has_feature("mobile")
	_setup_environment()
	city = CityScript.new()
	add_child(city)
	var loading := Label.new()
	loading.text = "Preparing HITEC City…"
	loading.add_theme_font_size_override("font_size",26)
	loading.position = Vector2(42,42)
	var loading_layer := CanvasLayer.new()
	add_child(loading_layer)
	loading_layer.add_child(loading)
	city.build_progress.connect(func(percent: int): loading.text = "Preparing HITEC City… %d%%" % percent)
	await city.build()
	loading_layer.queue_free()
	if city.roads.is_empty():
		push_error("City data missing; the game cannot start.")
		return
	_setup_navigation()
	_setup_missions()
	_spawn_player()
	_spawn_population()
	_setup_camera()
	_setup_hud()
	_setup_audio()
	apply_quality()
	mission_target = mission_locations[0].position
	_create_marker()
	var args := OS.get_cmdline_user_args()
	smoke_test = "--test" in args
	screen_capture = "--capture" in args
	if smoke_test or screen_capture: start_game()
	if smoke_test: _assert_world()
	if screen_capture:
		camera_yaw = focus_yaw()+0.2
		camera_manual = 100
		if vehicle != null: vehicle.speed = 0
	if "--reference" in args:
		set_reference_view(0)
	for arg in args:
		if arg.begins_with("--reference="):set_reference_view(clampi(arg.get_slice("=",1).to_int(),0,REFERENCE_VIEWS.size()-1))
	print("ARENA ready. Native Android + WebGL 2.0 + desktop. OSM snapshot loaded offline.")

func _input_setup() -> void:
	var actions := {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"enter":[KEY_E],"brake":[KEY_SPACE],"pause":[KEY_ESCAPE,KEY_P],"camera":[KEY_C],"recover":[KEY_R],"map":[KEY_M],"mission":[KEY_N],"night":[KEY_T],"horn":[KEY_H],"sprint":[KEY_SHIFT]}
	for action in actions:
		InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = preload("res://assets/materials/deccan_sky.hdr")
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color("adbdba")
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.00005
	environment.fog_sky_affect = 0.4
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,125,0)
	sun.light_color = Color("fff4e5")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240
	sun.shadow_bias = 0.05
	add_child(sun)

func _setup_navigation() -> void:
	for road in city.roads:
		var previous := -1
		for p: Vector3 in road.points:
			var key := Vector2i(roundi(p.x*2),roundi(p.z*2))
			if not graph_nodes.has(key):
				var id := graph_nodes.size()
				graph_nodes[key] = id
				graph.add_point(id,p)
			var point_id: int = graph_nodes[key]
			if previous >= 0 and previous != point_id and not graph.are_points_connected(previous,point_id):
				graph.connect_points(previous,point_id,not road.oneway)
			previous = point_id

func _landmark(pattern: String,fallback: Vector3,title: String) -> Dictionary:
	var center := fallback
	var mapped := false
	for b in city.buildings:
		if str(b.name).to_lower().contains(pattern.to_lower()):
			center = b.center
			mapped = true
			break
	if not mapped:
		for place in city.places:
			if str(place.name).to_lower().contains(pattern.to_lower()):
				center = place.center
				mapped = true
				break
	var road: Dictionary = city.nearest_road(center)
	return {"name":title,"position":road.position,"mapped":mapped}

func _setup_missions() -> void:
	mission_locations.append(_landmark("cyber towers",HitecCity.project(17.4501,78.3809),"Cyber Towers"))
	mission_locations.append(_landmark("mindspace",HitecCity.project(17.4410,78.3775),"Mindspace"))
	mission_locations.append(_landmark("cyber gateway",HitecCity.project(17.4467,78.3764),"Cyber Gateway"))

func _spawn_player() -> void:
	var start := city.nearest_road(HitecCity.project(17.4500177,78.3795362))
	spawn_position = start.position+Vector3.UP*0.12
	var direction: Vector3 = start.direction
	spawn_yaw = atan2(-direction.x,-direction.z)
	vehicle = _new_actor("car",Color("9bac93"),spawn_position)
	vehicle.rotation.y = spawn_yaw
	vehicle.controlled = true
	player = _new_actor("person",Color("d4c8b3"),spawn_position)
	player.visible = false
	player.controlled = true
	player.collision_layer = 0
	player.collision_mask = 0

func _new_actor(kind: String,color: Color,pos: Vector3,police: bool=false) -> ArenaActor:
	var actor: ArenaActor = ActorScript.new()
	actor.main = self
	actor.citizen_id = actors.size()
	add_child(actor)
	actor.setup(kind,color,police)
	actor.position = pos
	actors.append(actor)
	return actor

func _spawn_population() -> void:
	var traffic_roads: Array[Dictionary] = []
	for road in city.roads:
		if road.length > 70 and road.width > 7: traffic_roads.append(road)
	traffic_roads.sort_custom(func(a: Dictionary,b: Dictionary): return a.points[0].distance_squared_to(spawn_position) < b.points[0].distance_squared_to(spawn_position))
	var colors := [Color("e1ded0"),Color("8898a2"),Color("333c41"),Color("c8b174"),Color("a65846"),Color("718487")]
	for i in mini(100,traffic_roads.size()):
		var road: Dictionary = traffic_roads[i]
		var pts: PackedVector3Array = road.points
		var index := mini(1,pts.size()-1)
		var p: Vector3 = pts[0].lerp(pts[index],0.45)
		if p.distance_to(spawn_position) < 20: continue
		var tangent: Vector3 = (pts[index]-pts[0]).normalized()
		var lane := clampf(road.width*0.25,1.5,3.3)
		var side := Vector3(tangent.z,0,-tangent.x)
		var center := p
		p += side*lane
		var car := _new_actor("car",colors[i%colors.size()],p+Vector3.UP*0.1)
		car.path = pts
		car.lane_offset=lane;car.road_id=road.id;car.one_way=road.oneway
		car.rotation.y = atan2(-tangent.x,-tangent.z)
		car.cruising_speed = rng.randf_range(6,13)
		if i < 65:
			var sidewalk: float=road.width*0.5+0.45
			var person := _new_actor("person",colors[(i+3)%colors.size()],center+side*sidewalk+Vector3.UP*0.1)
			person.path = pts
			person.lane_offset=sidewalk
			person.cruising_speed = rng.randf_range(0.8,1.7)

func next_traffic_road(endpoint: Vector3,previous_id: int) -> Dictionary:
	var candidates: Array[Dictionary]=[]
	for road in city.roads:
		if road.id==previous_id or road.width<6:continue
		var pts: PackedVector3Array=road.points
		if pts[0].distance_squared_to(endpoint)<4:
			candidates.append(road)
		elif not road.oneway and pts[-1].distance_squared_to(endpoint)<4:
			var reverse: Dictionary=road.duplicate();pts=pts.duplicate();pts.reverse();reverse.points=pts;candidates.append(reverse)
	return {} if candidates.is_empty() else candidates[rng.randi_range(0,candidates.size()-1)]

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.15
	camera.far = 2200
	add_child(camera)
	camera.current = true
	camera_yaw = spawn_yaw
	camera.position = focus_position()+Vector3(15,9,20)
	camera.look_at(focus_position()+Vector3.UP*1.2)

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_audio() -> void:
	engine_audio = AudioStreamPlayer.new()
	engine_audio.stream = _tone(1.0,55,false)
	engine_audio.volume_db = -28
	add_child(engine_audio)
	siren = AudioStreamPlayer.new()
	siren.stream = _tone(2.0,650,true)
	siren.volume_db = -31
	add_child(siren)

func _tone(seconds: float,hz: float,warble: bool) -> AudioStreamWAV:
	var samples := int(22050*seconds)
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	var phase := 0.0
	for i in samples:
		var t := float(i)/22050
		var freq := hz*(1+0.30*sin(t*TAU)) if warble else hz
		phase += TAU*freq/22050
		var value := sin(phase)*0.4+sin(phase*2)*0.2+sin(phase*4)*0.1
		bytes.encode_s16(i*2,int(value*15000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	stream.data = bytes
	return stream

func start_game() -> void:
	var first_entry := not started
	if reference_view >= 0:
		reference_view = -1
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 68
	started = true
	paused = false
	hud.set_menu(false)
	if first_entry and not smoke_test: _enter_exit()
	if not hud.touch_enabled: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ignore_mouse_frames = 3
	engine_audio.stream_paused = false
	siren.stream_paused = false
	if not engine_audio.playing: engine_audio.play()
	notify("Welcome to HITEC City. Press N for a contract.")

func _input(event: InputEvent) -> void:
	if camera == null or hud == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F6 or event.keycode == KEY_F6:
			set_reference_view(reference_view+1 if reference_view < REFERENCE_VIEWS.size()-1 else -1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F11 or event.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			if started:
				if paused and hud.menu.current_page != 0: hud.menu.show_page(0)
				elif paused: start_game()
				else: pause_game()
			get_viewport().set_input_as_handled()

func pause_game() -> void:
	paused = true
	hud.set_menu(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	engine_audio.stream_paused = true
	siren.stream_paused = true

func set_reference_view(index: int) -> void:
	if paused: start_game()
	reference_view = index
	if index < 0:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 68
		player.model.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		player.model.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_reference_camera()
	hud.queue_redraw()

func _reference_camera() -> void:
	var reference: Dictionary = REFERENCE_VIEWS[reference_view]
	camera.position = HitecCity.project(reference.lat,reference.lon)+Vector3.UP*2.5
	camera.rotation_degrees = Vector3(reference.tilt-90.0,-reference.heading,0)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = reference.get("fov",75)

func _capture_tick(dt: float) -> void:
	if not screen_capture: return
	capture_clock += dt
	if capture_clock > 5:
		var filename := "reference-%d.png"%reference_view if reference_view >= 0 else "capture.png"
		get_viewport().get_texture().get_image().save_png("res://../build/"+filename)
		print("Capture saved: ",filename," FPS=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," resolution=",get_viewport().get_visible_rect().size)
		get_tree().quit()

func toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func quit_game() -> void:
	_save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused and not screen_capture and not smoke_test:
		pause_game()

func _unhandled_input(event: InputEvent) -> void:
	if paused: return
	if reference_view >= 0: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta(event.screen_relative)
	if event.is_action_pressed("enter"): _enter_exit()
	if event.is_action_pressed("recover"): recover()
	if event.is_action_pressed("camera"): camera_mode = (camera_mode+1)%3
	if event.is_action_pressed("map"):
		hud.map_expanded = not hud.map_expanded
		hud.queue_redraw()
	if event.is_action_pressed("night"): toggle_night()
	if event.is_action_pressed("mission"): _mission_action()
	if event.is_action_pressed("horn"): notify("Move through traffic carefully.")

func touch_action(action: String) -> void:
	match action:
		"enter": _enter_exit()
		"pause": pause_game()
		"mission": _mission_action()
		"recover": recover()

func look_delta(relative: Vector2) -> void:
	if ignore_mouse_frames > 0:
		ignore_mouse_frames -= 1
		return
	camera_yaw -= relative.x*mouse_sensitivity
	camera_pitch = clampf(camera_pitch-relative.y*mouse_sensitivity,-1.2,1.2)
	camera_manual = 2.4

func focus_position() -> Vector3:
	if vehicle != null: return vehicle.global_position
	if player != null: return player.global_position
	return spawn_position

func focus_yaw() -> float:
	return vehicle.rotation.y if vehicle != null else player.rotation.y

func _physics_process(dt: float) -> void:
	if city == null or camera == null: return
	elapsed += dt
	if paused:
		_camera_tick(dt,true)
		return
	if reference_view >= 0:
		_reference_camera()
		_capture_tick(dt)
		return
	toast_time = maxf(0,toast_time-dt)
	shoot_clock = maxf(0,shoot_clock-dt)
	shot_flash = maxf(0,shot_flash-dt)
	camera_manual = maxf(0,camera_manual-dt)
	var horizontal: float = Input.get_axis("left","right")+hud.stick.x
	var vertical: float = Input.get_axis("back","forward")-hud.stick.y
	if vehicle != null:
		vehicle.steering = clampf(horizontal,-1,1)
		vehicle.throttle = clampf(vertical+float(hud.held("accelerate")),-1,1)
		vehicle.brake = Input.is_action_pressed("brake") or hud.held("brake")
	else:
		var forward := Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
		var right := Vector3(cos(camera_yaw),0,-sin(camera_yaw))
		var move: Vector3 = (forward*vertical+right*horizontal).limit_length()
		var sprint: bool = Input.is_action_pressed("sprint") or hud.held("accelerate")
		var walk_speed := 5.8 if sprint else 2.3
		player.velocity.x = move.x*walk_speed
		player.velocity.z = move.z*walk_speed
		if move.length() > 0.05: player.rotation.y = lerp_angle(player.rotation.y,atan2(-move.x,-move.z),1-exp(-12*dt))
		if (Input.is_action_just_pressed("brake") or hud.held("brake")) and player.is_on_floor(): player.velocity.y = 7.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or hud.held("fire"): _shoot()
	var focus := focus_position()
	for actor in actors:
		if actor == player and vehicle != null: continue
		if actor.controlled or actor.police or actor.position.distance_squared_to(focus) < 320*320:
			actor.tick(dt)
		if actor.police and actor.health > 0 and actor.position.distance_to(focus) > 450:
			var near := city.nearest_road(focus+Vector3(rng.randf_range(-160,160),0,rng.randf_range(-160,160)))
			actor.position = near.position+Vector3.UP*0.2
	_update_wanted(dt)
	_update_mission(dt)
	_camera_tick(dt,false)
	if not city.bounds.grow(30).has_point(Vector2(focus.x,focus.z)):
		notify("District boundary. Returning to the nearest captured road.")
		var safe := Vector2(focus.x,focus.z).clamp(city.bounds.position+Vector2(20,20),city.bounds.end-Vector2(20,20))
		var road := city.nearest_road(Vector3(safe.x,0,safe.y))
		_teleport(road.position)
	if focus.y < -10: recover()
	if health <= 0: _respawn("WASTED  /  hospital fee ₹ 500")
	road_clock += dt
	if road_clock > 1.5:
		road_clock = 0
		var nearest := city.nearest_road(focus)
		street_name = nearest.road.name if nearest.road.name != "Local road" else "HITEC City · Madhapur"
		_update_route()
	hud_clock += dt
	if hud_clock > 0.10:
		hud_clock = 0
		hud.queue_redraw()
	if engine_audio != null:
		engine_audio.volume_db = -28 if vehicle != null else -65
		engine_audio.pitch_scale = 0.7+absf(vehicle.speed)*0.045 if vehicle != null else 0.8
	if smoke_test: _test_tick(dt)
	_capture_tick(dt)

func _camera_tick(dt: float,attract: bool) -> void:
	if reference_view >= 0:
		_reference_camera()
		return
	player.model.visible = vehicle == null and camera_mode != 2
	var focus := focus_position()+Vector3.UP*(1.1 if vehicle != null else 1.45)
	var distance := 10.0 if vehicle != null else 5.2
	var height := 3.3 if vehicle != null else 1.5
	if attract:
		camera_yaw = spawn_yaw+0.45+sin(elapsed*0.06)*0.18
		distance = 15
		height = 6.2
	elif vehicle != null and camera_manual <= 0 and absf(vehicle.speed) > 1:
		camera_yaw = lerp_angle(camera_yaw,vehicle.rotation.y,1-exp(-2.5*dt))
	if camera_mode == 1:
		distance *= 1.65
		height *= 1.5
	if camera_mode == 2:
		if vehicle != null:
			focus=vehicle.global_position+Vector3.UP*(vehicle.model.dimensions.y-0.28)-vehicle.global_basis.z*vehicle.model.dimensions.z*(0.39 if vehicle.vehicle_variant=="bus" else 0.12)+vehicle.global_basis.x*0.37
		else: focus = player.global_position+Vector3.UP*1.72
		camera.global_position = focus
		camera.rotation = Vector3(camera_pitch,camera_yaw,0)
		return
	var offset := Vector3(sin(camera_yaw)*distance,height-camera_pitch*distance,cos(camera_yaw)*distance)
	var desired := focus+offset
	if not attract:
		var query := PhysicsRayQueryParameters3D.create(focus,desired)
		query.exclude = [player.get_rid()]
		if vehicle != null: query.exclude.append(vehicle.get_rid())
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position+hit.normal*0.4
	camera.position = camera.position.lerp(desired,1-exp(-7.5*dt))
	if camera.position.distance_to(focus) > 0.15: camera.look_at(focus)
	camera.fov = lerpf(camera.fov,68+minf(absf(vehicle.speed)*0.23,10) if vehicle != null else 68,1-exp(-3*dt))

func _enter_exit() -> void:
	if vehicle != null:
		if absf(vehicle.speed) > 4:
			notify("Slow down before leaving the vehicle.")
			return
		var exit:=WorldRules.safe_exit(player,vehicle)
		if exit.is_empty():notify("Both exits are blocked. Move the vehicle first.");return
		player.position = exit.position
		player.rotation.y = vehicle.rotation.y
		player.visible = true
		player.collision_layer = 1
		player.collision_mask = 1
		player.velocity = Vector3.ZERO
		vehicle.controlled = false
		vehicle.throttle = 0
		vehicle.brake = true
		vehicle.path = PackedVector3Array()
		vehicle = null
		notify("On foot. E to enter a nearby vehicle.")
	else:
		var nearest: ArenaActor
		var distance := 6.0
		for actor in actors:
			if actor.kind != "car" or actor.health <= 0: continue
			var d := actor.position.distance_to(player.position)
			if d < distance:
				distance = d
				nearest = actor
		if nearest == null:
			notify("Get closer to a vehicle to enter it.")
			return
		if absf(nearest.speed)>2.5:notify("Wait for the vehicle to stop.");return
		if not WorldRules.line_clear(player,player.global_position+Vector3.UP,nearest.global_position+Vector3.UP,[nearest.get_rid()]):
			notify("The vehicle is behind an obstacle.");return
		vehicle = nearest
		vehicle.controlled = true
		vehicle.chase = false
		vehicle.brake = false
		player.visible = false
		player.collision_layer = 0
		player.collision_mask = 0
		camera_yaw = vehicle.rotation.y
		if vehicle.police: add_heat(2)
		notify("Vehicle acquired. Drive on the left.")

func actor_impact(actor: ArenaActor,other: Object,force: float) -> void:
	if actor != vehicle and actor != player: return
	if other is ArenaActor:
		other.hit(force*1.2)
		add_heat(2 if other.police else 1)
		notify("Collision reported. Lose the police.")
	if force > 18: health = maxf(0,health-force*0.13)

func _shoot() -> void:
	if shoot_clock > 0: return
	if ammo <= 0:
		notify("Out of ammo. R to reload on foot.")
		shoot_clock = 1
		return
	shoot_clock = 0.23
	ammo -= 1
	for citizen in actors: citizen.react_to_danger(focus_position())
	add_heat(1)
	var origin := camera.global_position
	var destination := origin-camera.global_basis.z*110
	var query := PhysicsRayQueryParameters3D.create(origin,destination)
	query.exclude = [player.get_rid()]
	if vehicle != null: query.exclude.append(vehicle.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		destination = hit.position
		if hit.collider is ArenaActor: hit.collider.hit(30)
	var line := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var mat := CityGeometry.material(Color("f1e3ac"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	mesh.surface_add_vertex(focus_position()+Vector3.UP*1.2-camera.global_basis.x*0.25)
	mesh.surface_add_vertex(destination)
	mesh.surface_end()
	line.mesh = mesh
	add_child(line)
	get_tree().create_timer(0.06).timeout.connect(line.queue_free)

func add_heat(amount: int) -> void:
	wanted = clampi(maxi(wanted,amount),1,5)
	escape_timer = 0
	if not siren.playing: siren.play()
	while cops.size() < mini(wanted+1,5):
		var angle := rng.randf()*TAU
		var point := focus_position()+Vector3(cos(angle)*150,0,sin(angle)*150)
		var road := city.nearest_road(point)
		var cop := _new_actor("car",Color("e4e4d8"),road.position+Vector3.UP*0.1,true)
		cop.chase = true
		cop.cruising_speed = 22
		var direction: Vector3 = focus_position()-cop.position
		cop.rotation.y = atan2(-direction.x,-direction.z)
		cops.append(cop)

func _update_wanted(dt: float) -> void:
	if wanted == 0: return
	var nearest := INF
	for cop in cops:
		if cop.health > 0: nearest = minf(nearest,cop.position.distance_to(focus_position()))
	if nearest > 100:
		escape_timer += dt
	else:
		escape_timer = 0
	if nearest < 8 and (vehicle == null or absf(vehicle.speed) < 3):
		arrest_timer += dt
		health -= dt*1.4
	else:
		arrest_timer = maxf(0,arrest_timer-dt)
	if arrest_timer > 4:
		_respawn("BUSTED  /  fine ₹ 500")
	if escape_timer >= 12:
		_clear_heat()
		notify("You lost the heat. Keep a low profile.")

func _clear_heat() -> void:
	wanted = 0
	escape_timer = 0
	arrest_timer = 0
	siren.stop()
	for cop in cops:
		actors.erase(cop)
		if cop == vehicle:
			cop.police = false
			continue
		cop.queue_free()
	cops.clear()

func _create_marker() -> void:
	mission_marker = Node3D.new()
	add_child(mission_marker)
	var mat := CityGeometry.material(Color("d4ee92"),0.2,0.3)
	mat.emission_enabled = true
	mat.emission = Color("91b85a")
	var torus := TorusMesh.new()
	torus.inner_radius = 4.1
	torus.outer_radius = 4.5
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	mission_marker.add_child(ring)
	ring.position.y = 0.25
	var label := Label3D.new()
	label.name = "Title"
	label.text = "CONTRACT"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 70
	label.pixel_size = 0.035
	label.position.y = 8
	label.modulate = Color("e0f6ae")
	mission_marker.add_child(label)

func _mission_action() -> void:
	if mission_index >= 3:
		mission_index = 0
		mission_stage = 0
		mission_active = false
	if not mission_active:
		mission_active = true
		mission_stage = 0
		mission_target = mission_locations[mission_index].position
		notify("Contract accepted. Follow the green route.")
	else:
		notify("Reach the marker and stop inside the ring.")
	_update_route()

func _update_mission(_dt: float) -> void:
	mission_marker.position = mission_target
	mission_marker.visible = mission_index < 3
	mission_marker.get_node("Title").text = mission_locations[mini(mission_index,2)].name.to_upper() if not mission_active else ("PICKUP" if mission_stage == 0 else "DROP-OFF")
	if not mission_active: return
	if focus_position().distance_to(mission_target) < 12 and (vehicle == null or absf(vehicle.speed) < 4):
		if mission_stage == 0:
			mission_stage = 1
			mission_target = mission_locations[(mission_index+1)%3].position
			if mission_index == 2:
				add_heat(2)
				notify("The pickup was flagged. Lose the heat, then deliver.")
			else: notify("Package collected. Head to the drop-off.")
			_update_route()
		elif wanted == 0:
			var reward := 1500+mission_index*750
			money += reward
			mission_index += 1
			mission_active = false
			mission_stage = 0
			mission_target = mission_locations[mini(mission_index,2)].position
			health = minf(100,health+25)
			_save()
			notify("CONTRACT COMPLETE  /  + ₹ %d" % reward)
		else: notify("Lose the police before the drop-off.")

func mission_title() -> String:
	if mission_index >= 3: return "The city is yours"
	return ["The first connection","Across the district","A little heat"][mission_index]

func objective_text() -> String:
	if mission_index >= 3: return "Free roam · N to replay contracts"
	if not mission_active: return "Press N or tap CONTRACT to accept"
	var distance := focus_position().distance_to(mission_target)
	return "%s  ·  %d m%s" % ["Collect" if mission_stage == 0 else "Deliver",int(distance)," · lose heat" if wanted > 0 else ""]

func _update_route() -> void:
	if route_mesh != null: route_mesh.queue_free()
	route = PackedVector3Array()
	if not mission_active: return
	var start := graph.get_closest_point(focus_position())
	var end := graph.get_closest_point(mission_target)
	if start < 0 or end < 0: return
	route = graph.get_point_path(start,end)
	if route.size() < 2: return
	var mesh := ImmediateMesh.new()
	var mat := CityGeometry.material(Color("a6cb7b"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
	for i in route.size()-1:
		var a := route[i]+Vector3.UP*0.085
		var b := route[i+1]+Vector3.UP*0.085
		if a.distance_to(focus_position()) > 300: continue
		var dir := (b-a).normalized()
		var side := Vector3(-dir.z,0,dir.x)*0.5
		for p in [a-side,b-side,b+side,a-side,b+side,a+side]: mesh.surface_add_vertex(p)
	mesh.surface_end()
	route_mesh = MeshInstance3D.new()
	route_mesh.mesh = mesh
	add_child(route_mesh)

func recover() -> void:
	if vehicle == null:
		ammo = 36
		notify("Reloaded. 36 rounds.")
		return
	var road := city.nearest_road(focus_position())
	_teleport(road.position)
	vehicle.health = 100
	notify("Vehicle recovered to the nearest road.")

func _teleport(pos: Vector3) -> void:
	var actor := vehicle if vehicle != null else player
	var safe:=WorldRules.safe_road_position(actor,city,pos)
	if safe.is_empty():notify("No clear recovery position here.");return
	actor.global_position = safe.position
	actor.velocity = Vector3.ZERO
	actor.speed = 0
	camera.position = actor.position+Vector3(sin(camera_yaw)*10,5,cos(camera_yaw)*10)

func _respawn(message: String) -> void:
	_clear_heat()
	health = 100
	ammo = 36
	money = maxi(0,money-500)
	_teleport(spawn_position)
	if vehicle != null: vehicle.health = 100
	_save()
	notify(message)

func notify(message: String) -> void:
	toast = message
	toast_time = 4
	if hud != null: hud.queue_redraw()

func toggle_night() -> void:
	night = not night
	sun.light_energy = 0.13 if night else 1.25
	sun.light_color = Color("9db9d3") if night else Color("fff4e5")
	environment.ambient_light_energy = 0.2 if night else 0.9
	environment.ambient_light_color = Color("506880") if night else Color("afc4c8")
	environment.fog_light_color = Color("233740") if night else Color("adbdba")
	environment.background_energy_multiplier = 0.08 if night else 1.0
	city.set_night(1.0 if night else 0.0)
	notify("Nightfall in HITEC City" if night else "Daylight in HITEC City")

func apply_quality() -> void:
	city.set_detail(high_quality)
	sun.shadow_enabled = high_quality
	get_viewport().msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().use_taa = false

func _load_save() -> void:
	if smoke_test: return
	var config := ConfigFile.new()
	if config.load("user://arena-save.cfg") == OK:
		money = int(config.get_value("progress","money",2500))
		mission_index = clampi(int(config.get_value("progress","mission",0)),0,3)

func _save() -> void:
	if smoke_test: return
	var config := ConfigFile.new()
	config.set_value("progress","money",money)
	config.set_value("progress","mission",mission_index)
	config.save("user://arena-save.cfg")

func _assert_world() -> void:
	assert(city.source_features > 1000,"Actual OSM data must be present")
	assert(city.mapped_buildings > 100,"Building footprints must load")
	assert(city.roads.size() > 100,"Roads must load")
	assert(graph.get_point_count() > 500,"Road navigation must be connected")
	assert(vehicle != null and player != null,"Player modes must exist")
	assert(actors.size() > 30,"Traffic and pedestrians must exist")
	print("TEST world generation PASS")
	var fleet: Dictionary={};var people: Dictionary={}
	for actor in actors:
		if actor.kind=="car":
			fleet[actor.vehicle_variant]=true
			assert(actor.model.wheels.size()==(3 if actor.vehicle_variant=="auto" else 4),"Wheel layout")
			assert(actor.model.dimensions.y>1.4,"Metre-scale vehicles")
		else:
			people[actor.model.variant]=true
			for clip in ["Idle","Walk","Run","Death","PickUp"]:assert(actor.model.animation.has_animation("Locomotion/"+clip),"Rigged animation missing")
	assert(fleet.size()==5,"All five street vehicle types spawn")
	assert(people.size()==5,"All five citizen variants spawn")
	var reference: Vector3=HitecCity.project(17.4447356,78.3772674)
	var prepared=JSON.parse_string(FileAccess.get_file_as_string("res://data/hitec-city.render.json"))
	assert(prepared.metadata.statistics.courtyards_preserved==68,"Open mapped courtyards")
	assert(reference.x<0 and reference.z>0,"World axes east and south")
	print("TEST mapped courtyards, diverse fleet and rigged citizens PASS")
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		assert(not hud.touch_enabled,"Desktop must not display touch controls")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	_input(escape)
	assert(paused and hud.menu.visible,"Escape opens the pause menu")
	_input(escape)
	assert(not paused and not hud.menu.visible,"Escape resumes")
	set_reference_view(0)
	assert(camera.position.distance_to(HitecCity.project(17.4509238,78.3818386)+Vector3.UP*2.5)<0.01,"Reference camera coordinates")
	pause_game()
	start_game()
	assert(reference_view == -1,"Resume exits reference inspection")
	assert(is_equal_approx(get_viewport().scaling_3d_scale,1.0),"Native render scale")
	print("TEST desktop menu, reference camera and native resolution PASS")
	test_world_passed = true

func _test_tick(dt: float) -> void:
	test_clock += dt
	if test_clock > 0.5 and test_clock < 0.5+dt:
		_enter_exit()
		assert(vehicle == null and player.visible,"Exit vehicle")
		_enter_exit()
		assert(vehicle != null and not player.visible,"Enter vehicle: "+toast)
		print("TEST vehicle enter/exit PASS")
		_mission_action()
		assert(mission_active,"Mission accepted")
		_teleport(mission_target)
		_update_mission(0)
		assert(mission_stage == 1,"Pickup registered")
		_teleport(mission_target)
		_update_mission(0)
		assert(mission_index == 1 and money >= 4000,"Delivery rewards")
		print("TEST pickup/delivery/reward PASS")
		add_heat(2)
		assert(wanted == 2 and cops.size() == 3,"Police dispatch")
		for cop in cops: cop.position = focus_position()+Vector3(300,0,300)
		escape_timer = 11.99
		_update_wanted(0.02)
		assert(wanted == 0,"Pursuit escape")
		print("TEST pursuit/escape PASS")
		toggle_night()
		assert(night,"Night lighting")
		toggle_night()
		high_quality = false
		apply_quality()
		print("TEST graphics presets PASS")
		test_gameplay_passed = true
	if test_clock > 1.2:
		var passed:=test_world_passed and test_gameplay_passed
		print("ALL TESTS PASSED" if passed else "GAMEPLAY TESTS FAILED")
		get_tree().quit(0 if passed else 1)
