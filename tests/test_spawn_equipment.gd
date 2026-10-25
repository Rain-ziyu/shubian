extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var back := Vector3(0,1.05,0.26)
	check(p.rig.weapon.position.distance_to(back)<0.001 and not p.combat.drawn,"first ready frame starts with weapon on back")
	var stable := true
	for frame in 12:
		p.animate(1.0/60,0)
		stable = stable and p.rig.weapon.position.distance_to(back)<0.001
	check(stable,"initial idle frames do not blend from uninitialized origin")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	p._unhandled_input(left)
	check(p.combat.drawn and p.combat.action=="light","first actual attack draws from initialized back pose")
	p.animate(1.0/60,0)
	check(p.rig.weapon.position.distance_to(back)<0.2,"first draw begins continuously at back")
	check(p.combat.health==240 and p.combat.shadow_lifetimes.is_empty(),"initialization does not grant combat resources")
	print("SPAWN_EQUIPMENT_CHECKS: ",checks," FAILURES: ",failures)
	# Assertions above still inspect the first ready frame. Let queued native
	# environment textures finish creating before destroying their owners.
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	world.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
