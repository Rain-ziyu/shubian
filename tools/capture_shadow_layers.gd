extends SceneTree
const Player = preload("res://scripts/player.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("273b34")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,-0.4,0)
	stage.add_child(light)
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.combat.shadow_lifetimes.assign([180.0,180.0,180.0,180.0,180.0])
	p.animate(0,0)
	await process_frame
	await process_frame
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(1.8,1.9,3.6)
	camera.look_at(Vector3(0,1.1,0))
	camera.fov = 40
	camera.current = true
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	first.save_png(ProjectSettings.globalize_path("res://../Shubian-spectral-layers.png"))
	for frame in 36:
		p.animate(1.0/60,0)
		await process_frame
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image()
	second.save_png(ProjectSettings.globalize_path("res://../Shubian-spectral-settled.png"))
	var changed := 0
	for y in first.get_height():
		for x in first.get_width():
			var diff := first.get_pixel(x,y)-second.get_pixel(x,y)
			if absf(diff.r)+absf(diff.g)+absf(diff.b)>0.04: changed += 1
	print("SPECTRAL_RENDER_CHANGED_PIXELS: ",changed)
	stage.queue_free()
	await process_frame
	quit(0 if changed>100 else 1)
