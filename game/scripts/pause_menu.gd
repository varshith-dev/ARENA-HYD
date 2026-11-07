extends Control

var game: Node3D
var start_button: Button
var heading: Label
var pages: Array[Control] = []
var current_page := 0
var panel: PanelContainer
var accent := Color("dde5c9")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.02,0.025,0.63)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("141a1e")
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel",style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",18)
	panel.add_child(stack)
	heading = Label.new()
	heading.text = "ARENA / Hyderabad"
	heading.add_theme_font_size_override("font_size",32)
	stack.add_child(heading)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	stack.add_child(tabs)
	for i in 3:
		var names := ["Game","Settings","Controls"]
		var tab := button(names[i])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func(): show_page(i))
		tabs.add_child(tab)
	for i in 3:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation",12)
		stack.add_child(page)
		pages.append(page)
	var text := Label.new()
	text.text = "HITEC City · Hyderabad\nExplore on foot, then take the wheel."
	text.add_theme_font_size_override("font_size",17)
	text.add_theme_color_override("font_color",Color("bcc6cb"))
	pages[0].add_child(text)
	start_button = button("Enter the city",true)
	start_button.pressed.connect(func(): game.start_game())
	pages[0].add_child(start_button)
	var reference := button("Inspect Cyber Towers  ·  F6")
	reference.pressed.connect(func(): game.set_reference_view(0))
	pages[0].add_child(reference)
	var restart := button("Return to HITEC City station")
	restart.pressed.connect(func():
		game.start_game()
		game._teleport(game.spawn_position))
	pages[0].add_child(restart)
	var quit_button := button("Quit to desktop" if not OS.has_feature("web") else "End session")
	quit_button.pressed.connect(func(): game.quit_game())
	pages[0].add_child(quit_button)
	var quality := button("Shadows and distance: High")
	quality.pressed.connect(func():
		game.high_quality = not game.high_quality
		game.apply_quality()
		quality.text = "Shadows and distance: High" if game.high_quality else "Shadows and distance: Balanced")
	pages[1].add_child(quality)
	var display := button("Toggle fullscreen  ·  F11")
	display.pressed.connect(func(): game.toggle_fullscreen())
	pages[1].add_child(display)
	var sound := CheckButton.new()
	sound.text = "Sound"
	sound.button_pressed = true
	sound.toggled.connect(func(enabled: bool):
		game.sound_enabled = enabled
		AudioServer.set_bus_mute(0,not enabled))
	pages[1].add_child(sound)
	var perf := CheckButton.new()
	perf.text = "Show frame rate"
	perf.toggled.connect(func(enabled: bool): game.show_performance = enabled)
	pages[1].add_child(perf)
	var sensitivity := Label.new()
	sensitivity.text = "Mouse sensitivity"
	pages[1].add_child(sensitivity)
	var slider := HSlider.new()
	slider.min_value = 0.0008
	slider.max_value = 0.006
	slider.step = 0.0002
	slider.value = game.mouse_sensitivity
	slider.custom_minimum_size.y = 30
	slider.value_changed.connect(func(value: float): game.mouse_sensitivity = value)
	pages[1].add_child(slider)
	var rendering := Label.new()
	rendering.text = "Native resolution · MSAA · no blur\nFewer shadows in Balanced; resolution stays sharp."
	rendering.add_theme_font_size_override("font_size",14)
	rendering.add_theme_color_override("font_color",Color("b4bfc4"))
	pages[1].add_child(rendering)
	var controls := Label.new()
	controls.text = "W A S D      Walk / drive\nMouse         Look around\nShift             Sprint\nSpace           Jump / brake\nE                   Enter / exit vehicle\nLeft mouse   Fire\nR                   Reload / recover vehicle\nN                   Accept contract\nM                  Map\nC                   Camera\nT                    Day / night\nEsc                Pause / resume\nF11                Fullscreen / window"
	controls.add_theme_font_size_override("font_size",18)
	pages[2].add_child(controls)
	resized.connect(_layout)
	_layout()
	show_page(0)

func _layout() -> void:
	panel.position = Vector2(maxf(24,size.x*0.07),maxf(20,(size.y-560)*0.5))
	panel.custom_minimum_size = Vector2(minf(480,size.x-48),0)
	panel.size.x = minf(480,size.x-48)

func button(text: String,primary: bool=false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",Color("15201b") if primary else Color("e7e9e7"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent if primary else Color("232d32")
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	b.add_theme_stylebox_override("normal",normal)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("hover",hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("c9d7ba")
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("focus",focus)
	return b

func show_page(index: int) -> void:
	current_page = index
	for i in pages.size(): pages[i].visible = i == index
	panel.reset_size()
	_layout()
	if index == 0: start_button.grab_focus()

func open() -> void:
	visible = true
	heading.text = "Paused" if game.started else "ARENA / Hyderabad"
	start_button.text = "Resume game" if game.started else "Enter the city"
	show_page(0)
