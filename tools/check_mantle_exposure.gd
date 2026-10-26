extends SceneTree
## Render diagnostic skin colors without hiding any body geometry.
const Player = preload("res://scripts/player.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Exposure study requires native rendering")
		quit(2)
		return
	root.size = Vector2i(512,512)
	root.content_scale_size = Vector2i(512,512)
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("58655c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,-0.4,0)
	stage.add_child(light)
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	if legacy and p.rig.torso.get_node("RainCape1").get_meta("segmented_mantle",false):
		printerr("Legacy baseline no longer uses the original cape; refusing a mislabeled comparison")
		quit(2)
		return
	if legacy: p.get_node("OcclusionVisibility").free()
	else: preload("res://tools/prepare_segmented_mantle.gd").apply(p)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO=COLOR.rgb; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	for binding in p.rig.skinning.bindings:
		var name: String = str(binding.source.name)
		var arm := name.begins_with("UpperArmSurface")
		if not arm and not name.begins_with("JointClothShoulder"): continue
		var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
		var refs: PackedVector3Array = binding.source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		for point in refs: colors.append(Color.RED if not arm or point.y<=-0.05 else (Color(1,0.5,0) if point.y<=0.05 else Color.BLACK))
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		binding.rendered.mesh = mesh
		binding.rendered.material_override = material
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 40
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.pitch = -0.25
	p.combat.drawn = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var label := Label.new()
	label.position = Vector2(8,8)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_constant_override("outline_size",3)
	layer.add_child(label)
	var samples := [["heavy",0.18],["heavy",0.43],["heavy",0.60],["guard",0.18],["plant",0.18],["plant",0.34]]
	if "--all-actions" in OS.get_cmdline_user_args():
		samples.clear()
		for spec in [["light",0.66],["heavy",0.92],["pull",0.86],["turn",0.95],["guard",1.40],["reply",0.82],["throw",0.80],["fourfold",1.25],["spin",1.35],["plant",0.65],["finisher",1.45]]:
			for phase in [0.20,0.47,0.65]: samples.append([spec[0],float(spec[1])*phase])
	var results := []
	var worst := []
	for sample in samples:
		p.combat.set_action(sample[0])
		p.combat.elapsed = sample[1]
		p.animate(0,0)
		for view in 8:
			camera.position = Vector3(sin(view*TAU/8)*2.2,1.55,cos(view*TAU/8)*2.2)
			camera.look_at(Vector3(0,1.33,0))
			label.text = "%s / %.3fs / VIEW%d" % [str(sample[0]).to_upper(),sample[1],view]
			camera.make_current()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.resize(512,512)
			frame.convert(Image.FORMAT_RGB8)
			var bytes := frame.get_data()
			var red := 0
			var boundary := 0
			for i in range(0,bytes.size(),3):
				if bytes[i]>240 and bytes[i+2]<24:
					if bytes[i+1]<24: red += 1
					else: boundary += 1
			var record := {"action":sample[0],"time":sample[1],"view":view,"red_pixels":red,"boundary_pixels":boundary}
			results.append(record)
			worst.append({"record":record,"image":frame})
			worst.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.record.red_pixels>b.record.red_pixels)
			if worst.size()>12: worst.pop_back()
	var sheet := Image.create(2048,1536,false,Image.FORMAT_RGB8)
	for i in worst.size(): sheet.blit_rect(worst[i].image,Rect2i(0,0,512,512),Vector2i((i%4)*512,(i/4)*512))
	var output := ProjectSettings.globalize_path("res://../mantle-exposure-"+("legacy" if legacy else "segmented"))
	if sheet.save_png(output+".png")!=OK:
		printerr("Exposure image write failed")
		quit(2)
		return
	var boundary_total := 0
	var total := 0
	var affected := 0
	for record in results:
		total += record.red_pixels
		boundary_total += record.boundary_pixels
		if record.red_pixels>0: affected += 1
	var report := {"legacy":legacy,"scope":"Authored neutral-aim samples, eight horizontal cameras,512px. Red=all JointClothShoulder and original UpperArmSurface localY<=-0.05; orange=-0.05<localY<=0.05 is the intended sleeve opening band. Other body geometry remains present. Both visible target regions are reported; uncovered target skin need not be an interior fabric hole. Not whole-body, arbitrary-view, or continuous-motion approval.","poses":samples.size(),"boundary_pixels":boundary_total,"views":results.size(),"affected_views":affected,"total_red_pixels":total,"results":results,"worst_views":worst.map(func(item: Dictionary): return item.record)}
	var file := FileAccess.open(output+".json",FileAccess.WRITE)
	if file==null:
		printerr("Exposure report write failed")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MANTLE_EXPOSURE: legacy=",legacy," views=",results.size()," affected=",affected," red_pixels=",total," boundary_pixels=",boundary_total)
	stage.queue_free()
	await process_frame
	quit()
