extends SceneTree
const Terrain = preload("res://scripts/forest_terrain.gd")
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
	world.hunter.set_physics_process(false)
	world.hunter.global_position = Vector3(35,0,0)
	var monsters := get_nodes_in_group("monsters")
	for i in monsters.size():
		monsters[i].set_physics_process(false)
		monsters[i].global_position = Vector3(70+i*10,0,70)
	for m in monsters:
		for action in ["spin","finisher"]:
			m.global_position = Vector3(0,0.01,-16)
			m.velocity = Vector3.ZERO
			m.phase = "idle"
			m.stagger = 0
			m.airborne_leap = false
			m.rear_attack = false
			for tick in 5:
				m._physics_process(1.0/60)
				await physics_frame
			var start: Vector3 = m.global_position
			var result: Dictionary = m.receive_strike(10,start+Vector3(0,0,3),action,"body")
			var highest: float = start.y
			var airborne := false
			var settle_frames := ceili((m.stagger+float(m.data.recovery)+0.2)*60)
			for tick in settle_frames:
				m._physics_process(1.0/60)
				highest = maxf(highest,m.global_position.y)
				airborne = airborne or not m.is_on_floor()
				await physics_frame
			check(result.hit and airborne and highest-start.y>0.2,str(m.data.id)+" "+action+" physically launches the body")
			check(m.global_position.z<start.z-0.3,"launch also moves the creature away from the attacker")
			check(m.is_on_floor() and absf(m.global_position.y-Terrain.mesh_height_at(m.global_position.x,m.global_position.z))<0.06,"launched body lands on real terrain")
			check(m.stagger==0 and m.phase=="idle",str(m.data.id)+" "+action+" exits stagger and recovery after landing")
			print("LAUNCH_CASE: ",JSON.stringify({"species":m.data.id,"action":action,"rise":highest-start.y,"away":start.z-m.global_position.z,"grounded":m.is_on_floor(),"phase":m.phase}))
		m.velocity = Vector3.ZERO
		m.stagger = 0
		m.receive_strike(10,m.global_position+Vector3(0,0,3),"fourfold","body")
		check(m.stagger==0 and is_zero_approx(m.velocity.y),"fourfold does not inherit the launch or stagger response")
		m.global_position = Vector3(70,0,70)
	print("LAUNCH_PHYSICS_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
