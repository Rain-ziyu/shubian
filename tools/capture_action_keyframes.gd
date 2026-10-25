extends SceneTree
## Actual runtime model pose samples, not concept art or live combat evidence.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(640,480)
	root.content_scale_size = root.size
	var world: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	world.hunter.set_process_unhandled_input(false)
	await create_timer(0.3).timeout
	var fighter: CharacterBody3D = world.hunter
	fighter.set_physics_process(false)
	var creature: CharacterBody3D
	for actor in get_nodes_in_group("monsters"):
		actor.set_physics_process(false)
		actor.hide()
		if actor.data.id == "reedclaw": creature = actor
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 36
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var label := Label.new()
	label.position = Vector2(16,14)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
	var sheet := Image.create(2560,960,false,Image.FORMAT_RGB8)
	fighter.pitch = -0.25
	fighter.yaw = 0
	fighter.rig.root.rotation.y = 0
	fighter.combat.set_action("heavy")
	for row in 2:
		fighter.visible = row == 0
		creature.visible = row == 1
		if row == 0:
			camera.position = fighter.global_position+Vector3(4,2.2,-4)
			camera.look_at(fighter.global_position+Vector3(0,0.95,0))
		else:
			creature.label.hide()
			for marker in creature.weak_markers: marker.hide()
			camera.position = creature.global_position+Vector3(8,4,-8)
			camera.look_at(creature.global_position+Vector3(0,1.2,0))
		for column in 4:
			var time: float
			if row == 0:
				time = [0.30,0.43,0.65,0.90][column]
				# Advance sequentially so runtime smoothing matches the sampled clock.
				var begin: float = [0.0,0.30,0.43,0.65][column]
				while begin < time:
					begin = minf(begin+1.0/120,time)
					fighter.combat.elapsed = begin
					fighter.animate(1.0/120,0)
			else:
				var phase: String = ["windup","active","recover","recover"][column]
				time = [float(creature.data.windup),0.30,0.15,float(creature.data.recovery)*0.9][column]
				creature.CreatureModel.animate(creature.mesh,creature.data,0,phase,time,0)
			label.text = ("HEAVY SWEEP" if row == 0 else "REEDCLAW LEAP")+" / "+["LOAD","RELEASE","SETTLE","RESET"][column]+"\nPOSE SAMPLE / %.2f s" % time
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(frame,Rect2i(0,0,640,480),Vector2i(column*640,row*480))
	var destination := ProjectSettings.globalize_path("res://../Shubian-action-keyframes-current.png")
	var result := sheet.save_png(destination)
	print("ACTION_KEYFRAMES: ",result," ",destination," / runtime pose samples, not live combat")
	world.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
