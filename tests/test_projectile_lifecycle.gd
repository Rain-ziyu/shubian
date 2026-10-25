extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func fly(shot) -> void:
	for frame in 60:
		if shot.finished: return
		shot._physics_process(0.025)
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var p = world.hunter
	# Manual-flight fixture: native window mouse capture must not alter its aim.
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	var aim_before := Vector2(p.yaw,p.pitch)
	var interference := InputEventMouseMotion.new()
	interference.relative = Vector2(0,-360)
	Input.parse_input_event(interference)
	await process_frame
	check(Vector2(p.yaw,p.pitch).is_equal_approx(aim_before),"external mouse input cannot steer the manual lifecycle fixture")
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var monster = get_nodes_in_group("monsters")[0]
	monster.global_position = Vector3(0,0,-16)
	monster.rotation = Vector3.ZERO
	p.global_position = Vector3(0,0.05,-22)
	p.yaw = PI
	p.rig.root.rotation.y = PI
	p.combat.set_action("throw")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	# Freeze the transition at the committed release pose in this manual-flight fixture.
	p.pose_blend = 1.0
	p.animate(0,0)
	p.on_strike(0)
	var shot = p.projectile
	shot.set_physics_process(false)
	shot.cancel_arrival()
	# Move caster behind the target while the committed projectile still approaches its front.
	p.global_position = Vector3(0,0.05,-10)
	var health: float = monster.health
	fly(shot)
	check(shot.finished,"projectile reaches actual collider")
	check(absf((health-monster.health)-36*float(monster.data.front_armor))<0.01,"front armor uses incoming projectile direction rather than caster location")
	await process_frame
	p.global_position = Vector3(0,0.05,-10)
	p.yaw = 0
	p.rig.root.rotation.y = 0
	p.combat.set_action("throw")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	# Freeze the transition at the committed release pose in this manual-flight fixture.
	p.pose_blend = 1.0
	p.animate(0,0)
	p.on_strike(0)
	shot = p.projectile
	shot.set_physics_process(false)
	p.take_damage(20,monster.global_position,false)
	check(shot.arrival_cancelled and not shot.finished,"hurt cancels arrival but keeps committed flight")
	p.combat.advance(0.56)
	check(p.combat.action=="idle","fixture lets hurt recovery finish before impact")
	var before: Vector3 = p.global_position
	var epoch: int = p.motion_epoch
	health = monster.health
	fly(shot)
	check(monster.health<health,"committed flight still resolves physical hit after interruption")
	check(p.global_position==before and p.motion_epoch==epoch,"recovered caster does not regain cancelled teleport")
	check(p.projectile==null,"cancelled arrival still restores weapon ownership")
	var old = p.Projectile.new()
	old.shooter = p
	world.add_child(old)
	old.set_physics_process(false)
	var replacement = p.Projectile.new()
	replacement.shooter = p
	world.add_child(replacement)
	replacement.set_physics_process(false)
	p.projectile = replacement
	old.finish()
	check(p.projectile==replacement and p.global_position==before,"stale projectile completion cannot clear or teleport a newer throw")
	replacement.cancel_arrival()
	replacement.finish()
	replacement.finish()
	check(p.projectile==null and p.global_position==before,"repeated completion remains harmless")
	p.combat.set_action("throw")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	# Freeze the transition at the committed release pose in this manual-flight fixture.
	p.pose_blend = 1.0
	p.animate(0,0)
	p.on_strike(0)
	shot = p.projectile
	shot.set_physics_process(false)
	p.take_damage(1000,monster.global_position,false)
	health = monster.health
	fly(shot)
	check(p.combat.health==0 and p.global_position==before and p.motion_epoch==epoch,"dead caster cannot arrive with a committed projectile")
	check(monster.health<health,"already committed physical throw keeps its collision result on caster death")
	shot = p.Projectile.new()
	shot.shooter = p
	world.add_child(shot)
	shot.set_physics_process(false)
	p.projectile = shot
	world.set_process(false)
	p.queue_free()
	await process_frame
	health = monster.health
	shot._physics_process(0.025)
	check(shot.finished and shot.is_queued_for_deletion(),"orphan projectile cleans up without a freed actor callback")
	check(monster.health==health,"orphan projectile cannot damage through invalid owner")
	print("PROJECTILE_LIFECYCLE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
