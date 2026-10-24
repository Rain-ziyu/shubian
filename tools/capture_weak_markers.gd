extends SceneTree
const Monster = preload("res://scripts/monster.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(600,500)
	root.content_scale_size = root.size
	var stage := Node3D.new()
	root.add_child(stage)
	var defeated := "--defeat" in OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("68766b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8,-0.6,0)
	stage.add_child(sun)
	if defeated:
		var floor_mesh := Monster.Visuals.piece(stage,Vector3(0,-0.2,0),Vector3(80,0.4,80),Color("748174"))
		floor_mesh.create_trimesh_collision()
		floor_mesh.get_child(0).collision_layer = 2
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 40
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var title := Label.new()
	title.position = Vector2(16,16)
	title.add_theme_font_size_override("font_size",22)
	layer.add_child(title)
	var species: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json")).species
	var sheet := Image.create(3000,500,false,Image.FORMAT_RGB8)
	for i in species.size():
		var m := Monster.new()
		m.data = species[i]
		stage.add_child(m)
		m.set_physics_process(false)
		m.phase = "windup"
		m.exposed = 1
		m.mesh.get_node("Neck").rotation.y = 0.4
		m.mesh.get_node("Tail").rotation.y = -0.5
		if defeated:
			m.health = 0
			for tick in 75:
				m._physics_process(1.0/60)
				await physics_frame
		var s: float = m.data.size
		camera.position = Vector3(s*2.4,s*1.5,s*2.7)
		if m.data.id=="mistfrill": camera.position.z = -s*2.7
		camera.look_at(Vector3(0,s*0.6,0))
		title.text = "SHUBIAN / "+str(m.data.name)+"\nOPEN WEAK POINT"
		if defeated: title.text = "SHUBIAN / "+str(m.data.name)+"\nDEFEAT / FLAT FLOOR STUDY"
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image,Rect2i(0,0,600,500),Vector2i(i*600,0))
		m.queue_free()
		await process_frame
	sheet.save_png(ProjectSettings.globalize_path("res://../Shubian-creature-defeat.png" if defeated else "res://../Shubian-weak-markers.png"))
	stage.queue_free()
	await process_frame
	quit()
