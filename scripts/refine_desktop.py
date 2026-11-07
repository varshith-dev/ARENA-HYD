from pathlib import Path
root=Path(__file__).resolve().parents[1]
hud=root/'game/scripts/hud.gd'
s=hud.read_text(encoding='utf-8')
s=s.replace('var menu: PanelContainer','var menu: Control')
s=s.replace('touch_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")','touch_enabled = OS.has_feature("android") or OS.has_feature("ios")\n\tif OS.has_feature("web"):\n\t\ttouch_enabled = bool(JavaScriptBridge.eval("matchMedia(\'(pointer: coarse)\').matches"))')
a=s.index('func _make_menu()')
b=s.index('func _text(',a)
s=s[:a]+'''func _make_menu() -> void:
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

'''+s[b:]
s=s.replace('style.set_corner_radius_all(5)','style.set_corner_radius_all(0)')
a=s.index('\tif game.vehicle != null:\n',s.index('func _draw()'))
b=s.index('\tif game.toast_time > 0:',a)
s=s[:a]+'''	if game.vehicle != null:
		_panel(Rect2(w-169,h-105,143,63))
		_text(Vector2(w-154,h-65),"%03d" % int(absf(game.vehicle.speed)*3.6),32,ink)
		_text(Vector2(w-87,h-66),"km/h",14,muted)
	else:
		draw_line(Vector2(w/2-5,h/2),Vector2(w/2+5,h/2),Color(1,1,1,0.75),1,true)
		draw_line(Vector2(w/2,h/2-5),Vector2(w/2,h/2+5),Color(1,1,1,0.75),1,true)
	if game.show_performance:
		_text(Vector2(w-150,160),"%d FPS · Native" % Engine.get_frames_per_second(),14,ink)
'''+s[b:]
s=s.replace('"WASD MOVE  ·  E ENTER / EXIT  ·  SPACE BRAKE / JUMP  ·  LMB FIRE  ·  ESC PAUSE"','"WASD  Move    E  Vehicle    Esc  Menu    F11  Fullscreen"')
s=s.replace('"C CAMERA  ·  R RECOVER / RELOAD  ·  T TIME OF DAY  ·  H HORN  ·  SHIFT SPRINT"','"Shift  Sprint    Space  Jump    M  Map    N  Contract"')
s=s.replace('if event is InputEventScreenTouch:\n\t\ttouch_enabled = true','if event is InputEventScreenTouch:\n\t\tif not (OS.has_feature("mobile") or OS.has_feature("web")): return\n\t\ttouch_enabled = true')
hud.write_text(s,encoding='utf-8')

p=root/'game/scripts/main.gd'
s=p.read_text(encoding='utf-8')
s=s.replace('var screen_capture := false','var show_performance := false\nvar mouse_sensitivity := 0.0024\nvar ignore_mouse_frames := 0\nvar screen_capture := false')
s=s.replace('sky_mat.sky_top_color = Color("4d788f")','sky_mat.sky_top_color = Color("6285a6")')
s=s.replace('sky_mat.sky_horizon_color = Color("d3c7ac")','sky_mat.sky_horizon_color = Color("c6d5df")')
s=s.replace('environment.fog_density = 0.00065','environment.fog_density = 0.00013')
s=s.replace('environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC','environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR')
s=s.replace('sun.light_color = Color("ffdeac")','sun.light_color = Color("fff4e5")')
s=s.replace('sun.light_energy = 1.1','sun.light_energy = 0.9')
s=s.replace('sun.rotation_degrees = Vector3(-24,-56,0)','sun.rotation_degrees = Vector3(-42,-56,0)')
s=s.replace('city.nearest_road(HitecCity.project(17.4517,78.3817))','city.nearest_road(HitecCity.project(17.4509238,78.3818386))')
s=s.replace('camera_yaw = vehicle.rotation.y+0.45','camera_yaw = focus_yaw()+0.2')
s=s.replace('\t\tvehicle.speed = 0','\t\tif vehicle != null: vehicle.speed = 0')
s=s.replace('func start_game() -> void:\n\tstarted = true','func start_game() -> void:\n\tvar first_entry := not started\n\tstarted = true')
s=s.replace('\thud.set_menu(false)\n\tif not hud.touch_enabled: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED','\thud.set_menu(false)\n\tif first_entry and not smoke_test: _enter_exit()\n\tif not hud.touch_enabled: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED\n\tignore_mouse_frames = 3\n\tengine_audio.stream_paused = false\n\tsiren.stream_paused = false')
a=s.index('func _unhandled_input(')
b=s.index('\tif paused: return',a)
s=s[:a]+'''func _input(event: InputEvent) -> void:
	if camera == null or hud == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11 or event.keycode == KEY_F11:
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
'''+s[b:]
s=s.replace('func look_delta(relative: Vector2) -> void:\n\tcamera_yaw -= relative.x*0.003\n\tcamera_pitch = clampf(camera_pitch-relative.y*0.002,-0.65,0.4)','func look_delta(relative: Vector2) -> void:\n\tif ignore_mouse_frames > 0:\n\t\tignore_mouse_frames -= 1\n\t\treturn\n\tcamera_yaw -= relative.x*mouse_sensitivity\n\tcamera_pitch = clampf(camera_pitch-relative.y*mouse_sensitivity,-0.65,0.25)')
s=s.replace('\t\t"pause":\n\t\t\tpaused = true\n\t\t\thud.set_menu(true)','\t\t"pause": pause_game()')
s=s.replace('var height := 4.3 if vehicle != null else 1.6','var height := 3.3 if vehicle != null else 1.5')
s=s.replace('get_viewport().msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED','get_viewport().msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_2X')
s=s.replace('get_viewport().scaling_3d_scale = 1.0 if high_quality else 0.75','get_viewport().scaling_3d_scale = 1.0\n\tget_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED\n\tget_viewport().use_taa = false')
s=s.replace('print("Capture saved")','print("Capture saved; FPS=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," resolution=",get_viewport().get_visible_rect().size)')
p.write_text(s,encoding='utf-8')
p=root/'game/project.godot'
s=p.read_text().replace('window/stretch/mode="canvas_items"','window/stretch/mode="disabled"\nwindow/dpi/allow_hidpi=true\nwindow/size/mode=2').replace('anti_aliasing/quality/msaa_3d=1','anti_aliasing/quality/msaa_3d=2')
p.write_text(s)
print('Desktop input, menu, native rendering and on-foot entry updated.')
