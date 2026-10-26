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
	# Controlled fixture: desktop motion must not change the starting view.
	world.hunter.set_process_input(false)
	world.hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.hunter.yaw = 0
	world.hunter.pitch = -0.25
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	var monsters := get_nodes_in_group("monsters")
	for m in monsters: m.set_physics_process(false)
	p.combat.set_action("light")
	p.combat.elapsed = 0.25
	p.animate(0,0)
	var tip: Vector3 = p.rig.weapon.transform*Vector3(0,1.1,0)
	check(tip.y>p.rig.weapon.position.y and tip.z<p.rig.weapon.position.z,"light tip points diagonally upward and forward")
	var m = monsters[0]
	var killed: Dictionary = m.receive_strike(100000,m.global_position+Vector3(0,0,4),"light")
	m._physics_process(0.02)
	check(m.health==0 and m.collision_layer==0,"defeated monster no longer blocks movement")
	check(not m.receive_strike(100,m.global_position,"light").hit,"corpse cannot be hit again")
	check(not m.weak_marker.visible,"corpse weak marker removed")
	p.combat.health = 0
	var living = monsters[1]
	living.phase = "active"
	living._physics_process(0.01)
	check(living.phase=="idle" and not living.tell.visible,"monster stops attack on player death")
	check(not p.combat.request("light"),"dead player cannot start actions")
	p.combat.health = 240
	for creature in monsters: creature.health = 0
	world._process(0)
	check("林地已清理" in world.hud.text,"all five defeated gives completion feedback")
	p.combat.health = 0
	world._process(0)
	check("任务失败" in world.hud.text and not "林地已清理" in world.hud.text,"failure wins over victory on player death")
	print("LIFECYCLE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
