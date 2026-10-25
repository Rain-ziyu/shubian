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
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	var monsters := get_nodes_in_group("monsters")
	for m in monsters: m.set_physics_process(false)
	var m = monsters[0]
	m.global_position = Vector3(0,0,-16)
	p.global_position = Vector3(0,0.05,-10)
	p.rig.root.rotation.y = 0
	await physics_frame
	var hp: float = m.health
	var epoch: int = p.motion_epoch
	p.combat.set_action("throw")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	p.on_strike(0)
	check(is_instance_valid(p.projectile),"throw creates physical visual projectile")
	var shot = p.projectile
	shot.set_physics_process(false)
	check(m.health==hp,"throw does not apply instant ranged damage")
	for i in 40:
		if shot.finished: break
		shot._physics_process(0.025)
	check(shot.finished and m.health<hp,"flight ray collides and damages creature")
	check(get_nodes_in_group("hit_feedback").size()==1,"projectile contact produces one feedback effect")
	if p.global_position.z >= -10: print("LANDING_DIAGNOSTIC: ",p.message," at ",p.global_position)
	check(p.global_position.z < -10 and p.global_position.z > -16,"arrival stops before monster capsule")
	check(p.motion_epoch==epoch+1,"successful teleport marks discontinuous motion")
	await process_frame
	world.obstacle(Vector3(10,2,2),Vector3(8,4,0.5),Color.GRAY)
	p.global_position = Vector3(10,preload("res://scripts/forest_terrain.gd").height_at(10,8)+0.05,8)
	await physics_frame
	p.finish_throw(Vector3(10,0,-10))
	check(p.global_position.z>2.3,"capsule sweep prevents wall crossing")
	world.obstacle(Vector3(0,2.7,-12),Vector3(4,0.4,4),Color.GRAY).collision_layer = 2
	p.global_position = Vector3(0,0.05,-8)
	p.combat.set_action("idle")
	await physics_frame
	p.finish_throw(Vector3(0,1.1,-12))
	check(p.global_position.y<0.2 and p.global_position.z<-10,"arrival beneath low overhang does not teleport onto its roof")
	p.combat.set_action("hurt")
	var before: Vector3 = p.global_position
	epoch = p.motion_epoch
	p.finish_throw(Vector3(30,0,20))
	check(p.global_position==before,"interrupted throw cannot teleport")
	check(p.motion_epoch==epoch,"cancelled teleport preserves movement history")
	print("PROJECTILE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
