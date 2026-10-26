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
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.combat.set_action("heavy")
	p.pitch = -0.25
	var tips: Array[Vector3] = []
	for time in [0.0,0.18,0.43,0.60,0.92]:
		p.combat.elapsed = time
		p.animate(0,0)
		tips.append(p.rig.weapon.transform*p.rig.weapon.get_node("TipContact").position)
	p.combat.set_action("idle")
	p.combat.drawn = true
	p.animate(0,0)
	var neutral: Vector3 = p.rig.weapon.transform*p.rig.weapon.get_node("TipContact").position
	check(tips[0].distance_to(neutral)<0.001,"heavy begins from neutral rather than jumping to backswing")
	check(tips[4].distance_to(neutral)<0.001,"heavy ends at neutral rather than leaving weapon sideways")
	check(tips[1].x>tips[2].x+0.4,"heavy sweeps from prepared side through contact")
	check(tips[3].x<tips[2].x-0.4,"heavy follows through to opposite side")
	check(absf(tips[2].x)<0.20,"physical heavy contact passes near the aimed centerline")
	print("HEAVY_TRAJECTORY_CHECKS: ",checks," FAILURES: ",failures," TIPS: ",tips)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
