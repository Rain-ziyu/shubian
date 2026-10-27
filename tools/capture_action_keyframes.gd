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
	var saved_study := "--saved-counter" in OS.get_cmdline_user_args()
	var guard_study := "--guard" in OS.get_cmdline_user_args() or saved_study
	var saved_holder: Node3D
	var saved_animation: AnimationPlayer
	if saved_study:
		saved_holder = Node3D.new()
		world.add_child(saved_holder)
		saved_holder.global_position = fighter.global_position
		var saved: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
		saved_holder.add_child(saved)
		saved_animation = saved.get_node("AnimationPreview")
		saved_animation.play("reply")
		saved_holder.hide()
	fighter.pitch = -0.25
	fighter.yaw = 0
	fighter.rig.root.rotation.y = 0
	fighter.combat.set_action("heavy")
	for row in 2:
		fighter.visible = row == 0 or guard_study
		if saved_study:
			fighter.visible = row==0
			saved_holder.visible = row==1
		creature.visible = row == 1 and not guard_study
		if guard_study: fighter.combat.set_action("guard" if row == 0 else "reply")
		if row == 0 or guard_study:
			camera.position = fighter.global_position+Vector3(4,2.2,-4)
			camera.look_at(fighter.global_position+Vector3(0,0.95,0))
		else:
			creature.label.hide()
			for marker in creature.weak_markers: marker.hide()
			camera.position = creature.global_position+Vector3(8,4,-8)
			camera.look_at(creature.global_position+Vector3(0,1.2,0))
		for column in 4:
			var time: float
			if saved_study and row==1:
				time = [0.36,0.60,0.72,0.82][column]
				saved_animation.seek(time,true)
			elif row == 0 or guard_study:
				time = ([0.0,0.06,0.12,0.18] if row == 0 else [0.0,0.12,0.26,0.42])[column] if guard_study else [0.30,0.43,0.65,0.90][column]
				# Advance sequentially so runtime smoothing matches the sampled clock.
				var begin: float = ([0.0,0.0,0.06,0.12] if row == 0 else [0.0,0.0,0.12,0.26])[column] if guard_study else [0.0,0.30,0.43,0.65][column]
				if is_zero_approx(time): fighter.animate(0,0)
				while begin < time:
					begin = minf(begin+1.0/120,time)
					fighter.combat.elapsed = begin
					fighter.animate(1.0/120,0)
			else:
				var phase: String = ["windup","active","recover","recover"][column]
				time = [float(creature.data.windup),0.30,0.15,float(creature.data.recovery)*0.9][column]
				creature.CreatureModel.animate(creature.mesh,creature.data,0,phase,time,0)
			var action_name: String = ("GUARD" if row == 0 else "BUTT REPLY") if guard_study else ("HEAVY SWEEP" if row == 0 else "REEDCLAW LEAP")
			if saved_study and row==1: action_name = "SAVED COUNTER / CONTACT TO RECOVERY"
			label.text = action_name+" / "+str(column+1)+"\nPOSE SAMPLE / %.2f s" % time
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(frame,Rect2i(0,0,640,480),Vector2i(column*640,row*480))
	var destination := ProjectSettings.globalize_path("res://../Shubian-guard-keyframes-current.png" if guard_study else "res://../Shubian-action-keyframes-current.png")
	if saved_study: destination = ProjectSettings.globalize_path("res://../Shubian-saved-counter-keyframes.png")
	var result := sheet.save_png(destination)
	print("ACTION_KEYFRAMES: ",result," ",destination," / runtime pose samples, not live combat")
	world.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
