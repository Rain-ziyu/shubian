extends SceneTree
const Model = preload("res://scripts/trident_mesh.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("26352f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9d9cf")
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.5,-2.5,0)
	light.light_energy = 1.4
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1,-1.2)
	camera.look_at(Vector3(0,0.96,0))
	camera.fov = 35
	camera.current = true
	var weapon := Model.create(stage,false)
	var sheet := Image.create(2560,720,false,Image.FORMAT_RGB8)
	for index in 2:
		weapon.rotation.y = [0.0,0.65][index]
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,Rect2i(0,0,1280,720),Vector2i(index*1280,0))
	var error := sheet.save_png(ProjectSettings.globalize_path("res://../Shubian-trident-surface.png"))
	print("TRIDENT_SURFACE_CAPTURE: ",error)
	stage.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
