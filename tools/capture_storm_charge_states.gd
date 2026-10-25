extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(640,480)
	root.content_scale_size = root.size
	var world: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	world.hunter.set_process_unhandled_input(false)
	await create_timer(0.3).timeout
	world.hunter.set_physics_process(false)
	var actor: CharacterBody3D
	for creature in get_nodes_in_group("monsters"):
		creature.set_physics_process(false)
		creature.set_process(false)
		if creature.data.id=="stormcrest": actor = creature
		else: creature.hide()
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	world.hunter.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = actor.global_position+Vector3(11,6,-12)
	camera.look_at(actor.global_position+Vector3(0,2.5,0))
	camera.fov = 36
	camera.current = true
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var title := Label.new()
	title.position = Vector2(16,16)
	title.add_theme_font_size_override("font_size",19)
	layer.add_child(title)
	var sheet := Image.create(2560,480,false,Image.FORMAT_RGB8)
	for state in 4:
		if state<3:
			actor.phase = "idle" if state==0 else "windup"
			actor.clock = [0.0,float(actor.data.windup)*0.3,float(actor.data.windup)][state]
			actor.CreatureModel.animate(actor.mesh,actor.data,0,actor.phase,actor.clock,0)
		else:
			actor.stagger = 1.0
			actor.was_staggering = false
			actor._physics_process(1.0/60)
		actor.label.hide()
		for marker in actor.weak_markers: marker.hide()
		title.text = ["IDLE","CHARGING / TAIL TO HEAD","FULL CHARGE","INTERRUPTED / OPEN SPINE"][state]+"\nPOSE AND MATERIAL STUDY"
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,Rect2i(0,0,640,480),Vector2i(state*640,0))
	var error := sheet.save_png(ProjectSettings.globalize_path("res://../Shubian-storm-charge-states.png"))
	print("STORM_CHARGE_CAPTURE: ",error)
	world.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
