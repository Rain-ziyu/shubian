extends SceneTree
## Fixed impact fixture, not an AI combat demonstration.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(800,600)
	root.content_scale_size = root.size
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.3).timeout
	world.hunter.hide()
	world.hunter.set_physics_process(false)
	var creature: CharacterBody3D
	for m in get_nodes_in_group("monsters"):
		m.set_physics_process(false)
		m.hide()
		if m.data.id=="reedclaw": creature = m
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	creature.show()
	creature.label.hide()
	for marker in creature.weak_markers: marker.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = creature.global_position+Vector3(6,3,-7)
	camera.look_at(creature.global_position+Vector3(0,1.5,-0.6))
	camera.fov = 35
	camera.current = true
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	var label := Label.new()
	label.position = Vector2(16,16)
	label.add_theme_font_size_override("font_size",24)
	canvas.add_child(label)
	creature.phase = "idle"
	creature.stagger = 0
	creature.exposed = 1
	creature.receive_strike(1,creature.global_position+creature.global_basis*Vector3(-3,0,0),"heavy","flank")
	# Disable the flash overlay so the silhouette change is visible on its own.
	for part in creature.impact_meshes: part.material_overlay = null
	var sheet := Image.create(2400,600,false,Image.FORMAT_RGB8)
	for index in 3:
		label.text = "IMPACT POSE FIXTURE / "+["BEFORE","RECOIL 45ms","SETTLED 260ms"][index]
		creature.mesh.set_meta("impact_age",[0.0,0.045,0.26][index])
		creature.CreatureModel.animate(creature.mesh,creature.data,0,"idle",0,0)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,Rect2i(0,0,800,600),Vector2i(index*800,0))
	var result := sheet.save_png(ProjectSettings.globalize_path("res://../Shubian-creature-impact-study.png"))
	print("CREATURE_IMPACT_CAPTURE: ",result)
	world.queue_free()
	await process_frame
	quit(0 if result==OK else 1)
