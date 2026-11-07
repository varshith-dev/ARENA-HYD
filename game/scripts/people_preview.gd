extends SceneTree
var people: Array[Node3D] = []
var time := 0.0
func _initialize() -> void:call_deferred("setup")
func setup() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,800))
	DisplayServer.window_set_title("ARENA — character model check")
	root.msaa_3d=Viewport.MSAA_4X
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("536575");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("c6d3df");settings.ambient_light_energy=0.7
	environment.environment=settings;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.1;sun.shadow_enabled=true;world.add_child(sun)
	CityGeometry.box(world,Vector3(0,-0.08,0),Vector3(30,0.1,20),CityGeometry.material(Color("717a7e")))
	for i in 5:
		var person:=CityGeometry.person([Color("53697d"),Color("a68870"),Color("557969"),Color("946d69"),Color("545e72")][i],i)
		world.add_child(person);person.position=Vector3(-2.4+i*1.6,0,0);person.rotation.y=PI
		people.append(person)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(4.4,2.9,7.6);camera.look_at(Vector3(0,1,0));camera.fov=44;camera.current=true
func _process(dt: float) -> bool:
	time+=dt
	for i in people.size():people[i].animate(dt,[0.0,1.5,5.4,0.0,1.5][i],true,"shopping" if i==3 else "commuting",100.0)
	if time>4 and not people.is_empty():
		root.get_texture().get_image().save_png("res://../build/people-preview.png")
		print("Character preview saved")
		quit()
	return false
