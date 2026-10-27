extends SceneTree
var checks := 0
var failures := 0
var frames: Array[float] = []
var previous_us := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	previous_us = Time.get_ticks_usec()
	process_frame.connect(func():
		var now := Time.get_ticks_usec()
		frames.append((now-previous_us)/1000.0)
		previous_us = now
	)
	var startup: Node = load("res://scenes/main/startup.tscn").instantiate()
	if DisplayServer.get_name()!="headless" and "--capture-startup" in OS.get_cmdline_user_args():
		RenderingServer.frame_post_draw.connect(func(): root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-preparation-screen.png")),CONNECT_ONE_SHOT)
	root.add_child(startup)
	var observed_pause := false
	var paused_clocks_valid := true
	while not startup.complete:
		if is_instance_valid(startup.world):
			observed_pause = observed_pause or startup.world.process_mode==Node.PROCESS_MODE_DISABLED
			for actor in get_nodes_in_group("monsters"): paused_clocks_valid = paused_clocks_valid and is_zero_approx(actor.clock)
		await process_frame
	var world: Node3D = startup.world
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/main/startup.tscn","normal project launch uses the preparation entry")
	check(is_instance_valid(world.hunter) and get_nodes_in_group("monsters").size()==5,"startup creates the complete normal world")
	check(world.process_mode==Node.PROCESS_MODE_INHERIT,"startup restores normal actor processing")
	check(world.hunter.combat.health==240 and world.hunter.combat.shadow_lifetimes.is_empty(),"preparation does not consume life or grant intent")
	check(get_nodes_in_group("hazards").is_empty(),"temporary preparation hazards are removed before play")
	check(get_nodes_in_group("hit_feedback").is_empty(),"temporary first-hit preparation objects are removed before play")
	if DisplayServer.get_name()=="headless": check(is_instance_valid(world.hunter.camera),"headless startup retains the normal camera node")
	else: check(root.get_camera_3d()==world.hunter.camera,"normal player camera restored")
	if DisplayServer.get_name()!="headless":
		check(observed_pause,"native preparation pauses gameplay while rendering")
		check(paused_clocks_valid,"AI attack clocks do not advance during preparation")
		check(not is_instance_valid(startup.overlay) or startup.overlay.is_queued_for_deletion(),"loading overlay dismissed after preparation")
		print("STARTUP_FRAME_TIMES_MS: ",JSON.stringify(frames))
		var ready_index := frames.size()
		for frame in 120: await process_frame
		print("STARTUP_POST_READY_FRAME_TIMES_MS: ",JSON.stringify(frames.slice(ready_index)))
	print("STARTUP_CHECKS: ",checks," FAILURES: ",failures)
	startup.queue_free()
	await process_frame
	quit(1 if failures else 0)
