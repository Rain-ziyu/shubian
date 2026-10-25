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
	var monsters := get_nodes_in_group("monsters")
	for i in monsters.size():
		monsters[i].set_physics_process(false)
		monsters[i].global_position = Vector3(45+i*3,0,45)
	var m = monsters[0]
	p.global_position = Vector3(0,0.05,-8)
	var travels: Array[float] = []
	for blocked in [false,true]:
		if blocked: world.obstacle(Vector3(0,2,-10.2),Vector3(8,4,0.2),Color.GRAY)
		# Begin clear of the wall with the complete elongated trunk footprint.
		m.global_position = Vector3(0,0.05,-12.5)
		m.velocity = Vector3.ZERO
		m.stagger = 0
		await physics_frame
		await physics_frame
		var before: Vector3 = m.global_position
		m.receive_strike(20,p.global_position,"pull","body")
		for tick in 12:
			m._physics_process(1.0/60)
			await physics_frame
		travels.append(m.global_position.z-before.z)
		check(m.global_position.distance_to(p.global_position)<before.distance_to(p.global_position),"pull causes real movement toward hunter")
		check(absf(m.global_position.y-before.y)<0.1,"flat-ground pull does not launch creature")
		if blocked: check(m.global_position.z<=-10.3-float(m.data.size)*0.48+0.02,"pulled front trunk stops before wall")
	check(travels[0]>0.5 and travels[1]<travels[0]-0.1,"wall reduces real pull displacement")
	print("PULL_PHYSICS_CHECKS: ",checks," FAILURES: ",failures," TRAVEL: ",travels)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
