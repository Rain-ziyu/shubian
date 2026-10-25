extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func sole_position(leg: Node3D) -> Vector3:
	var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
	var foot: MeshInstance3D = leg.get_node("Foot")
	return leg.to_global(skeleton.get_bone_global_pose(2)*skeleton.get_bone_global_rest(2).affine_inverse()*(foot.transform*Vector3(0,-0.5,0)))
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	var monsters := get_nodes_in_group("monsters")
	for m in monsters: m.set_physics_process(false)
	p.apply_look(Vector2(-PI/2/0.003,-10000))
	check(is_equal_approx(p.yaw,PI/2) and is_equal_approx(p.pitch,0.65),"logical mouse look rotates yaw and clamps upward pitch")
	p.combat.set_action("light")
	check(absf(wrapf(p.rig.root.rotation.y-p.yaw,-PI,PI))<0.001,"free attack begins in view direction")
	Input.action_press("move_back")
	p._physics_process(1.0/60)
	Input.action_release("move_back")
	check(absf(wrapf(p.rig.root.rotation.y-p.yaw,-PI,PI))<0.001,"attack movement does not turn away from aim")
	check(is_equal_approx(p.mount.rotation.x,0.13),"high weapon aim keeps camera orbit above ground")
	p.pitch = -0.25
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.43
	p.animate(0,0)
	var neutral: Vector3 = p.rig.weapon.to_global(Vector3(0,1.2,0))
	check(absf(neutral.y-p.rig.weapon.global_position.y)<0.001,"neutral heavy remains horizontal")
	p.apply_look(Vector2(0,-10000))
	p.animate(0,0)
	var raised: Vector3 = p.rig.weapon.to_global(Vector3(0,1.2,0))
	check(raised.y-neutral.y>0.9,"aim raises actual sweep plane")
	for action in ["heavy","turn"]:
		p.combat.set_action(action)
		p.combat.elapsed = 0.43
		p.animate(0,0)
		for side in [-1,1]:
			var arm: Dictionary = p.rig.arms[side]
			check(arm.shoulder.position.distance_to(arm.hand.position)<0.8,"raised sweep grip remains reachable")
	var storm = monsters[4]
	storm.CreatureModel.animate(storm.mesh,storm.data,0,"idle",0,0)
	var before: float = storm.Parts.volumes(storm)[0].center.y
	var foot_before := sole_position(storm.mesh.get_node("Hind1"))
	storm.CreatureModel.animate(storm.mesh,storm.data,0,"windup",0.4,0)
	var lowered: float = before-storm.Parts.volumes(storm)[0].center.y
	check(lowered>1.0 and lowered<1.4,"deep charging posture lowers rear spine toward high attack height")
	check(foot_before.distance_to(sole_position(storm.mesh.get_node("Hind1")))<0.002,"charging torso keeps actual skinned sole planted")
	storm.phase = "windup"
	storm.clock = 0.3
	storm.rotation.y = 0
	p.global_position = storm.global_position+Vector3(2,0,1)
	storm._physics_process(0.1)
	check(absf(storm.rotation.y)<0.001,"pulse windup holds orientation while presenting flank")
	storm.CreatureModel.animate(storm.mesh,storm.data,0,"recover",0,0)
	check(is_zero_approx(storm.mesh.position.y),"charge posture recovers after attack")
	var mist = monsters[2]
	mist.phase = "windup"
	mist.clock = 0.2
	mist.rotation.y = 0
	p.global_position = mist.global_position+Vector3(2,0,1)
	mist._physics_process(0.1)
	check(absf(mist.rotation.y)>0.01,"mist still tracks target during early windup")
	print("AIM_CHARGE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
