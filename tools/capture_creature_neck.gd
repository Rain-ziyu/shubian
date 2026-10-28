extends SceneTree
## Rendered neck/body poses. No AI, input or combat acceptance.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(640,360)
	root.content_scale_size = root.size
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("c4cdbf")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.35
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,2.8,0)
	light.light_energy = 0.8
	stage.add_child(light)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	var data: Dictionary
	for species in database.species:
		if species.id=="stormcrest": data = species
	var model := preload("res://scripts/creature_model.gd").create(stage,data)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 35
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var label := Label.new()
	label.position = Vector2(12,12)
	label.add_theme_font_size_override("font_size",19)
	label.add_theme_color_override("font_color",Color("29392e"))
	layer.add_child(label)
	var result := Image.create(1280,1080,false,Image.FORMAT_RGB8)
	var phases := ["idle","windup","stagger"]
	for row in 3:
		var phase: String = phases[row]
		var pose := {"neck_rotation":Vector3(-0.22,0.45,0),"body_surface_rotation":Vector3(0,0,0.10)} if phase=="stagger" else {}
		preload("res://scripts/creature_model.gd").animate(model,data,0,phase,float(data.windup) if phase=="windup" else 0.12,0,Callable(),Callable(),false,pose)
		for column in 2:
			camera.position = model.position+Vector3(float(data.size)*(1.8 if column==0 else -1.8),float(data.size)*0.95,-float(data.size)*1.5)
			camera.look_at(model.position+Vector3(0,float(data.size)*0.65,-float(data.size)*0.45))
			label.text = "STORMCREST / "+phase.to_upper()+" / "+("RIGHT" if column==0 else "LEFT")
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			result.blit_rect(shot,Rect2i(0,0,640,360),Vector2i(column*640,row*360))
	var destination := ProjectSettings.globalize_path("res://../Shubian-stormcrest-neck-poses.png")
	var error := result.save_png(destination)
	print("CREATURE_NECK_CAPTURE: ",error," ",destination," / six frozen views, no AI or input")
	stage.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
