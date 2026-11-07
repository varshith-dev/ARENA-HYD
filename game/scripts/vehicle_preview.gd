extends SceneTree
var cars: Array[Node3D]=[]
var time:=0.0
func _initialize() -> void:call_deferred("setup")
func setup() -> void:
	root.msaa_3d=Viewport.MSAA_4X
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("526778")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("d2dae4");settings.ambient_light_energy=0.6
	env.environment=settings;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);sun.light_energy=1.1;sun.shadow_enabled=true;world.add_child(sun)
	CityGeometry.box(world,Vector3(0,-0.09,0),Vector3(60,0.1,50),CityGeometry.material(Color("687680")))
	var variants:=["sedan","hatchback","suv","auto","bus"]
	for i in variants.size():
		var car:=CityGeometry.vehicle([Color("b9c6cd"),Color("7a9299"),Color("997c68"),Color("cbb672"),Color("cbd0c8")][i],false,variants[i])
		world.add_child(car);car.position=Vector3(-6+i*3.6,0,0);cars.append(car)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(-11,8,-15);camera.look_at(Vector3(1,0.8,0));camera.fov=56;camera.current=true
func _process(dt: float) -> bool:
	time+=dt
	for car in cars:car.animate(dt,1.0,0.1)
	if time>3 and not cars.is_empty():
		root.get_texture().get_image().save_png("res://../build/vehicle-preview.png");print("Vehicle preview saved");quit()
	return false
