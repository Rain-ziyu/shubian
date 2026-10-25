extends SceneTree
## Direct pose samples for animation review, not a live combat recording.
const Monster = preload("res://scripts/monster.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(800,600)
	root.content_scale_size = root.size
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("52635d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,-0.5,0)
	stage.add_child(light)
	var creature := Monster.new()
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in database.species:
		if species.id=="reedclaw": creature.data = species
	stage.add_child(creature)
	creature.set_physics_process(false)
	creature.label.hide()
	for marker in creature.weak_markers: marker.hide()
	var camera := Camera3D.new()
	camera.fov = 38
	stage.add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var title := Label.new()
	title.position = Vector2(18,18)
	title.add_theme_font_size_override("font_size",22)
	layer.add_child(title)
	var sheet := Image.create(2400,600,false,Image.FORMAT_RGB8)
	var wrist: Node3D = creature.mesh.get_node("Forelimb1/Wrist")
	for index in 3:
		var phase: String = ["windup","active","recover"][index]
		var time: float = [creature.data.windup,0.30,0.0][index]
		creature.CreatureModel.animate(creature.mesh,creature.data,0,phase,time,0,Callable(),Callable(),true)
		camera.position = wrist.global_position+Vector3(1.1,0.4,-1.4)
		camera.look_at(wrist.global_position+Vector3(0,-0.08,-0.18))
		title.text = ["01 / ANTICIPATION - OPEN","02 / AIRBORNE - GRASP","03 / LANDING - RESET"][index]+"\nPOSE STUDY / NOT LIVE COMBAT"
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,Rect2i(0,0,800,600),Vector2i(index*800,0))
	sheet.save_png(ProjectSettings.globalize_path("res://../Shubian-reedclaw-grasp.png"))
	stage.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
