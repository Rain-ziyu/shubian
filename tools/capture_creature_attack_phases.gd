extends SceneTree
## Runtime model poses at four attack stages. No exported assets are changed.
const Model = preload("res://scripts/creature_model.gd")
const CELL := Vector2i(640,480)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Attack pose capture requires native rendering")
		quit(2)
		return
	root.size = CELL
	root.content_scale_size = CELL
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("58655c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8,-0.4,0)
	stage.add_child(sun)
	Model.V.piece(stage,Vector3(0,-0.15,0),Vector3(40,0.3,40),Color("7b887b"))
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 42
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var label := Label.new()
	label.position = Vector2(16,12)
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_constant_override("outline_size",4)
	layer.add_child(label)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	var shoulder_study := "--forelimb" in OS.get_cmdline_user_args()
	if shoulder_study: data.species = data.species.filter(func(species): return species.id=="reedclaw")
	var sheet := Image.create(CELL.x*4,CELL.y*data.species.size(),false,Image.FORMAT_RGB8)
	var captures := 0
	for row in data.species.size():
		var species: Dictionary = data.species[row]
		var model := Model.create(stage,species)
		var size: float = species.size
		camera.position = Vector3(size*2.4,size*1.5,-size*3.2)
		camera.look_at(Vector3(0,size*0.65,0))
		var samples := [["idle",0.0],["windup",float(species.windup)],["active",0.20],["recover",0.15]]
		for column in samples.size():
			var sample: Array = samples[column]
			var ground := func(_point: Vector3) -> float: return 0.0
			var normal := func(_point: Vector3) -> Vector3: return Vector3.UP
			Model.animate(model,species,0,sample[0],sample[1],0,ground,normal)
			if shoulder_study:
				camera.position = Vector3(size*1.8,size*0.95+model.position.y,-size*1.3)
				camera.look_at(Vector3(size*0.20,size*0.60+model.position.y,-size*0.35))
				camera.fov = 35
			label.text = "%s / %s / %.2fs\nRUNTIME POSE SAMPLE" % [str(species.id).to_upper(),str(sample[0]).to_upper(),float(sample[1])]
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(frame,Rect2i(Vector2i.ZERO,CELL),Vector2i(column*CELL.x,row*CELL.y))
			captures += 1
		model.free()
	var destination := ProjectSettings.globalize_path("res://../"+("Shubian-reedclaw-shoulder-poses.png" if shoulder_study else "Shubian-creature-attack-phases.png"))
	var error := sheet.save_png(destination)
	print("CREATURE_ATTACK_PHASES: captures=",captures," result=",error," path=",destination," / pose samples, not AI or human acceptance")
	stage.queue_free()
	await process_frame
	quit(0 if error==OK and captures==data.species.size()*4 else 1)
