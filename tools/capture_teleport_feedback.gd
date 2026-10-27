extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.3).timeout
	var p = world.hunter
	p.set_physics_process(false)
	p.set_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var outcome_study := "--outcome" in OS.get_cmdline_user_args()
	var close_return := "--close-return" in OS.get_cmdline_user_args()
	if not outcome_study: world.hud.get_parent().hide()
	p.global_position = Vector3(0,0.05,-10)
	p.combat.drawn = true
	p.animate(0,0)
	await physics_frame
	p.finish_throw(p.global_position if close_return else Vector3(0,0,-14))
	for effect in get_nodes_in_group("teleport_feedback"): effect.set_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(7,4,-7)
	camera.look_at(Vector3(0,1,-12))
	camera.make_current()
	if outcome_study:
		for frame in 120: p.update_camera_framing(1.0/60)
		p.camera.make_current()
		world.combat_hud.update_state(p,0)
		await physics_frame
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination := "res://../Shubian-teleport-feedback.png"
	if outcome_study: destination = "res://../Shubian-teleport-outcome-close.png" if close_return else "res://../Shubian-teleport-outcome.png"
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(destination))
	print("TELEPORT_FEEDBACK_CAPTURE: ",error," outcome=",outcome_study," close_return=",close_return," / controlled arrival fixture")
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if error==OK else 1)
