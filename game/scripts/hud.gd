extends Control

var game: Node3D
var minimap: Control
var menu: Control
var title_label: Label
var subtitle: Label
var start_button: Button
var info_label: Label
var touch_enabled := false
var stick := Vector2.ZERO
var stick_id := -1
var look_id := -1
var touches: Dictionary = {}
var touch_actions: Dictionary = {}
var map_expanded := false
var font: Font = ThemeDB.fallback_font
var ink := Color("f2f2e6")
var accent := Color("d4ee92")
var muted := Color("a9b7ad")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_enabled = OS.has_feature("android") or OS.has_feature("ios")
	if OS.has_feature("web"):
		touch_enabled = bool(JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches"))
	_make_menu()

func _make_menu() -> void:
	menu = preload("res://scripts/pause_menu.gd").new()
	menu.game = game
	add_child(menu)
	menu.open()

func set_menu(open: bool) -> void:
	menu.visible = open
	if open: menu.open()
	stick = Vector2.ZERO
	touch_actions.clear()
	touches.clear()
	stick_id = -1
	look_id = -1
	queue_redraw()

func _text(p: Vector2,text: String,size_px: int=18,color: Color=ink) -> void:
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _panel(rect: Rect2,color: Color=Color(0.025,0.06,0.065,0.86)) -> void:
	draw_style_box(_style(color),rect)

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	return style

func _draw() -> void:
	if game == null or game.city == null: return
	var w := size.x
	var h := size.y
	if game.reference_view >= 0 and not game.paused:
		_panel(Rect2(20,h-82,560,60))
		_text(Vector2(34,h-56),game.REFERENCE_VIEWS[game.reference_view].name+"  /  Reference camera",17,ink)
		_text(Vector2(34,h-33),"F6  Next view / return to game     Esc  Menu     OSM contributors · ODbL",13,muted)
		return
	_text(Vector2(30,h-14),"© OpenStreetMap contributors · ODbL  |  Procedural visual reconstruction",12,Color("a9b2a5"))
	if menu != null and menu.visible:
		_text(Vector2(w-405,h-56),"HITEC CITY  /  OPEN WORLD",18,accent)
		_text(Vector2(w-405,h-34),"%s mapped buildings · %.1f km² capture" % [game.city.mapped_buildings,21.3],15,ink)
		return
	_panel(Rect2(26,25,310,67))
	_text(Vector2(44,51),"ARENA   /   HYDERABAD",18,accent)
	_text(Vector2(44,77),game.street_name.left(32).to_upper(),15,ink)
	_panel(Rect2(w-295,25,269,112))
	_text(Vector2(w-275,54),"₹ %s" % game.money,25,ink)
	var heat := ""
	for i in 5: heat += "★ " if i < game.wanted else "☆ "
	_text(Vector2(w-275,83),heat,23,Color("edab6c") if game.wanted > 0 else muted)
	draw_rect(Rect2(w-275,102,226,5),Color("34423d"))
	draw_rect(Rect2(w-275,102,226*game.health/100.0,5),accent)
	_text(Vector2(w-275,126),"HEALTH  %d     /     AMMO  %d" % [game.health,game.ammo],13,muted)
	var card_y := 105.0
	_panel(Rect2(26,card_y,330,111))
	_text(Vector2(44,card_y+27),"CONTRACT  %02d / 03" % (mini(game.mission_index+1,3)),14,accent)
	_text(Vector2(44,card_y+54),game.mission_title(),20,ink)
	_text(Vector2(44,card_y+80),game.objective_text(),15,muted)
	_text(Vector2(44,card_y+100),"M  MAP     N  NEXT CONTRACT",12,muted)
	_draw_map(Rect2(26,h-245,240,204),false)
	if map_expanded:
		_panel(Rect2(w*0.15,h*0.12,w*0.7,h*0.76),Color(0.035,0.07,0.075,0.98))
		_draw_map(Rect2(w*0.15+20,h*0.12+52,w*0.7-40,h*0.76-75),true)
		_text(Vector2(w*0.15+22,h*0.12+32),"HITEC CITY  /  DISTRICT MAP        M TO CLOSE",19,accent)
	if game.vehicle != null:
		_panel(Rect2(w-169,h-105,143,63))
		_text(Vector2(w-154,h-65),"%03d" % int(absf(game.vehicle.speed)*3.6),32,ink)
		_text(Vector2(w-87,h-66),"km/h",14,muted)
	else:
		draw_line(Vector2(w/2-5,h/2),Vector2(w/2+5,h/2),Color(1,1,1,0.75),1,true)
		draw_line(Vector2(w/2,h/2-5),Vector2(w/2,h/2+5),Color(1,1,1,0.75),1,true)
	if game.show_performance:
		_text(Vector2(w-150,160),"%d FPS · Native" % Engine.get_frames_per_second(),14,ink)
	if game.toast_time > 0:
		var rect := Rect2(w/2-250,h-112,500,44)
		_panel(rect)
		_text(rect.position+Vector2(17,29),game.toast,18,accent)
	if not touch_enabled:
		_text(Vector2(290,h-48),"WASD  Move    E  Vehicle    Esc  Menu    F11  Fullscreen",14,ink)
		_text(Vector2(290,h-28),"Shift  Sprint    Space  Jump    M  Map    N  Contract",12,muted)
	else:
		_draw_touch()
	if game.wanted > 0:
		_text(Vector2(w/2-90,40),"LOSE THE HEAT" if game.escape_timer > 0 else "POLICE PURSUIT",16,Color("efb180"))

func _draw_map(rect: Rect2,expanded: bool) -> void:
	_panel(rect,Color("152b2b"))
	var center: Vector3 = game.focus_position()
	var scale_map := 0.22
	if expanded:
		center = Vector3(250,0,200)
		scale_map = minf(rect.size.x/4600,rect.size.y/5200)
	var origin := rect.get_center()
	for road in game.city.roads:
		var pts: PackedVector3Array = road.points
		var color := Color("66817c") if float(road.width) >= 10 else Color("395955")
		for i in pts.size()-1:
			var a := origin+Vector2(pts[i].x-center.x,pts[i].z-center.z)*scale_map
			var b := origin+Vector2(pts[i+1].x-center.x,pts[i+1].z-center.z)*scale_map
			if rect.has_point(a) and rect.has_point(b): draw_line(a,b,color,1.5 if expanded else 2.0,true)
	var objective: Vector3 = game.mission_target
	var target := origin+Vector2(objective.x-center.x,objective.z-center.z)*scale_map
	target = target.clamp(rect.position+Vector2(9,9),rect.end-Vector2(9,9))
	draw_circle(target,5,accent)
	for cop in game.cops:
		var p: Vector3 = cop.position
		var dot := origin+Vector2(p.x-center.x,p.z-center.z)*scale_map
		if rect.has_point(dot): draw_circle(dot,3,Color("ec7766"))
	var player_pos := origin+Vector2(game.focus_position().x-center.x,game.focus_position().z-center.z)*scale_map
	var yaw: float = game.focus_yaw()
	var f := Vector2(-sin(yaw),-cos(yaw))
	var s := Vector2(-f.y,f.x)
	if rect.has_point(player_pos): draw_colored_polygon(PackedVector2Array([player_pos+f*9,player_pos-f*6+s*5,player_pos-f*6-s*5]),ink)
	_text(rect.position+Vector2(10,20),"N ↑   HITEC CITY",12,muted)

func _stick_center() -> Vector2:
	return Vector2(120,size.y-120)

func _touch_buttons() -> Dictionary:
	return {"accelerate":Rect2(size.x-130,size.y-170,100,100),"brake":Rect2(size.x-245,size.y-130,88,75),"enter":Rect2(size.x-130,size.y-270,100,70),"fire":Rect2(size.x-245,size.y-225,88,70),"pause":Rect2(size.x/2-35,15,70,48),"mission":Rect2(26,224,160,45),"recover":Rect2(size.x-245,size.y-315,88,65)}

func _draw_touch() -> void:
	var center := _stick_center()
	draw_circle(center,77,Color(0.8,0.9,0.8,0.1))
	draw_arc(center,77,0,TAU,50,Color(0.85,0.95,0.85,0.4),2,true)
	draw_circle(center+stick*53,27,Color(0.8,0.9,0.8,0.4))
	var names := {"accelerate":"GO" if game.vehicle != null else "RUN","brake":"BRAKE" if game.vehicle != null else "JUMP","enter":"EXIT" if game.vehicle != null else "ENTER","fire":"FIRE","pause":"II","mission":"CONTRACT","recover":"RESET"}
	for key in _touch_buttons():
		var rect: Rect2 = _touch_buttons()[key]
		_panel(rect,Color(0.08,0.16,0.15,0.67))
		draw_rect(rect,Color(0.7,0.83,0.7,0.4),false,1)
		_text(rect.position+Vector2(10,rect.size.y/2+6),names[key],17,ink)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not (OS.has_feature("mobile") or OS.has_feature("web")): return
		touch_enabled = true
		if menu.visible: return
		if event.pressed:
			for key in _touch_buttons():
				if _touch_buttons()[key].has_point(event.position):
					touches[event.index] = key
					touch_actions[key] = true
					if key in ["enter","pause","mission","recover"]: game.touch_action(key)
					return
			if event.position.x < size.x*0.45:
				stick_id = event.index
				stick = ((event.position-_stick_center())/70).limit_length()
			else:
				look_id = event.index
		else:
			if event.index == stick_id:
				stick = Vector2.ZERO
				stick_id = -1
			if event.index == look_id: look_id = -1
			if touches.has(event.index):
				touch_actions.erase(touches[event.index])
				touches.erase(event.index)
	if event is InputEventScreenDrag and not menu.visible:
		if event.index == stick_id: stick = ((event.position-_stick_center())/70).limit_length()
		if event.index == look_id: game.look_delta(event.relative*1.5)

func held(key: String) -> bool:
	return touch_actions.get(key,false)
