extends SceneTree

func _initialize() -> void:
	call_deferred("generate")

func generate() -> void:
	var config := ConfigFile.new()
	var targets := [
		["Windows Desktop","EditorExportPlatformWindows","../build/windows/ArenaHyderabad.exe"],
		["Web","EditorExportPlatformWeb","../build/web/index.html"],
		["Android","EditorExportPlatformAndroid","../build/android/ArenaHyderabad.apk"]
	]
	for i in targets.size():
		var platform = ClassDB.instantiate(targets[i][1])
		var preset = platform.create_preset()
		var section := "preset.%d" % i
		config.set_value(section,"name",targets[i][0])
		config.set_value(section,"platform",targets[i][0])
		config.set_value(section,"runnable",true)
		config.set_value(section,"advanced_options",true)
		config.set_value(section,"dedicated_server",false)
		config.set_value(section,"custom_features","")
		config.set_value(section,"export_filter","all_resources")
		config.set_value(section,"include_filter","data/*.json")
		config.set_value(section,"exclude_filter","*.download.json")
		config.set_value(section,"export_path",targets[i][2])
		config.set_value(section,"script_export_mode",2)
		config.set_value(section,"encrypt_pck",false)
		config.set_value(section,"encrypt_directory",false)
		for property in preset.get_property_list():
			var name: String = property.name
			if name.contains("/") and property.usage & PROPERTY_USAGE_STORAGE:
				config.set_value(section+".options",name,preset.get(name))
		var options := section+".options"
		var templates := "../tools/export_templates/"
		if i == 0:
			config.set_value(options,"custom_template/release",templates+"windows_release_x86_64.exe")
			config.set_value(options,"binary_format/embed_pck",true)
			config.set_value(options,"application/product_name","ARENA Hyderabad")
			config.set_value(options,"application/file_description","HITEC City open-world action sandbox")
			config.set_value(options,"codesign/enable",false)
		elif i == 1:
			config.set_value(options,"custom_template/release",templates+"web_nothreads_release.zip")
			config.set_value(options,"variant/thread_support",false)
			config.set_value(options,"vram_texture_compression/for_desktop",false)
			config.set_value(options,"vram_texture_compression/for_mobile",false)
			config.set_value(options,"html/canvas_resize_policy",2)
			config.set_value(options,"html/head_include","<meta name='theme-color' content='#152b2b'><meta name='description' content='Explore HITEC City, Hyderabad, in an original open-world action sandbox built from OpenStreetMap.'>")
		else:
			config.set_value(options,"custom_template/debug",templates+"android_debug.apk")
			config.set_value(options,"custom_template/release",templates+"android_release.apk")
			config.set_value(options,"gradle_build/use_gradle_build",false)
			config.set_value(options,"architectures/armeabi-v7a",false)
			config.set_value(options,"architectures/arm64-v8a",true)
			config.set_value(options,"architectures/x86",false)
			config.set_value(options,"architectures/x86_64",false)
			config.set_value(options,"package/unique_name","games.arena.hyderabad")
			config.set_value(options,"package/name","ARENA Hyderabad")
			config.set_value(options,"version/name","0.1.0")
			config.set_value(options,"version/code",1)
			config.set_value(options,"screen/immersive_mode",true)
			config.set_value(options,"permissions/internet",false)
			config.set_value(options,"xr_features/xr_mode",0)
	var result := config.save("res://export_presets.cfg")
	print("Editor-generated export presets: ",error_string(result))
	quit(result)
