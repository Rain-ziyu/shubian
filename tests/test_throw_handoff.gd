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
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.yaw = 0
	p.combat.set_action("throw")
	p.combat.elapsed = 0
	p.animate(0,0)
	var start: Vector3 = p.rig.weapon.position
	p.combat.elapsed = 0.2
	p.animate(0,0)
	var windup: Vector3 = p.rig.weapon.position
	var loaded_body: Vector3 = p.rig.root.position
	check(absf(p.rig.pelvis.rotation.y)>0.08,"throw windup carries the pelvis with the winding chest")
	check(windup.y>start.y+0.2,"throw lifts weapon during preparation")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	check(p.rig.weapon.position.z<windup.z-0.25,"throw sends weapon forward into release")
	check(loaded_body.z-p.rig.root.position.z>0.09,"throw drives the whole body forward from the loaded stance")
	check(loaded_body.z-p.rig.root.position.z>0.19 and p.rig.root.position.y-loaded_body.y>0.08,"throw releases a distinct rear-leg load into forward body drive")
	check(absf(p.to_local(p.rig.legs[1].ankle.to_global(Vector3(0,-0.1,0))).y)<0.002,"throw keeps the rear support foot grounded at release")
	var handoff: Vector3 = p.rig.weapon.global_position
	var axis: Vector3 = p.rig.weapon.global_basis.y.normalized()
	p.on_strike(0)
	p.projectile.set_physics_process(false)
	check(p.projectile.global_position.distance_to(handoff)<0.001,"flight starts at held weapon center")
	check(axis.dot(p.projectile.direction)>0.999,"release shaft aligns with actual projectile flight")
	p.projectile.cancel_arrival()
	p.projectile.finish()
	var rear_supported := true
	var return_lift := 0.0
	for frame in 97:
		p.combat.elapsed = float(frame)/120
		p.animate(0,0)
		var rear: Vector3 = p.to_local(p.rig.legs[1].ankle.to_global(Vector3(0,-0.1,0)))
		rear_supported = rear_supported and absf(rear.y)<0.003
		if p.combat.elapsed>0.50:
			var front: Vector3 = p.to_local(p.rig.legs[-1].ankle.to_global(Vector3(0,-0.1,0)))
			return_lift = maxf(return_lift,front.y)
	check(rear_supported,"throw retains rear support throughout preparation and recovery")
	check(return_lift>0.04,"throw lifts the front foot when returning from its step")
	for aim in [-0.65,0.30,0.65]:
		p.pitch = aim
		p.combat.set_action("throw")
		p.combat.elapsed = 0.38
		p.animate(0,0)
		var aimed_axis: Vector3 = p.rig.weapon.global_basis.y.normalized()
		p.on_strike(0)
		p.projectile.set_physics_process(false)
		check(aimed_axis.dot(p.projectile.direction)>0.999,"aimed projectile follows the actual released shaft")
		check(p.projectile.direction.y>0.4 if aim>0 else p.projectile.direction.y< -0.3,"mouse elevation changes physical throwing direction")
		p.projectile.cancel_arrival()
		p.projectile.finish()
	p.pitch = -0.25
	p.global_position = Vector3(0,0.05,-8)
	world.obstacle(Vector3(0,1.4,-8.25),Vector3(3,3,0.1),Color.GRAY)
	await physics_frame
	await physics_frame
	p.combat.set_action("throw")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	p.on_strike(0)
	var blocked = p.projectile
	blocked.set_physics_process(false)
	check(blocked.global_position.z> -8.2,"held weapon beyond wall cannot spawn projectile on far side")
	blocked._physics_process(0.1)
	check(blocked.finished and blocked.global_position.z> -8.31,"blocked launch actually collides with wall")
	print("THROW_HANDOFF_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
