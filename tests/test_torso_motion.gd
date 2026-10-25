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
	p.yaw = 0
	p.rig.root.rotation = Vector3.ZERO
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.combat.drawn = true
	p.combat.set_action("idle")
	p.animate(0,0)
	var ready_weapon: Transform3D = p.rig.weapon.transform
	var ready_foot: Vector3 = p.rig.legs[-1].ankle.global_position
	p.combat.set_action("guard")
	p.animate(0,0)
	check(p.rig.weapon.transform.is_equal_approx(ready_weapon),"guard starts at the forward ready grip without position jump")
	check(p.rig.legs[-1].ankle.global_position.distance_to(ready_foot)<0.002,"guard stance starts without a foot jump")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	var braced: Transform3D = p.rig.weapon.transform
	var braced_foot: Vector3 = p.rig.legs[-1].ankle.global_position
	check(p.rig.weapon.get_node("ButtContact").global_position.z<p.rig.weapon.get_node("TipContact").global_position.z,"guard carries the head behind and presents the butt forward")
	p.combat.set_action("reply")
	p.animate(0,0)
	check(p.rig.weapon.transform.is_equal_approx(braced) and p.rig.legs[-1].ankle.global_position.distance_to(braced_foot)<0.002,"reply joins the braced weapon and support stance")
	p.combat.elapsed = 0.12
	p.animate(0,0)
	var loaded_root: float = p.rig.root.position.z
	var loaded_butt: Vector3 = p.rig.weapon.get_node("ButtContact").global_position
	p.combat.elapsed = 0.26
	p.animate(0,0)
	check(loaded_root-p.rig.root.position.z>0.09,"reply transfers whole-body weight from load to extension")
	check(loaded_butt.z-p.rig.weapon.get_node("ButtContact").global_position.z>0.29,"reply sends actual butt contact forward with the body")
	check(absf(p.rig.legs[1].ankle.global_position.y-p.global_position.y-0.1)<0.002,"rear support foot stays grounded during reply")
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	check(p.rig.torso.rotation.y< -0.20,"heavy anticipates with torso windup")
	p.combat.elapsed = 0.50
	p.animate(0,0)
	check(absf(p.to_local(p.rig.weapon.get_node("TipContact").global_position).x)>0.70,"heavy follow-through clears the tip laterally beyond the torso")
	p.combat.elapsed = 0.61
	p.animate(0,0)
	check(p.rig.torso.rotation.y>0.20,"heavy follows through across the body")
	var follow_weapon: Transform3D = p.rig.weapon.transform
	var follow_torso: Transform3D = p.rig.torso.transform
	p.combat.elapsed = 0.70
	p.animate(0,0)
	check(p.rig.weapon.transform.is_equal_approx(follow_weapon),"heavy settles at far side before reversing into recovery")
	check(p.rig.torso.transform.is_equal_approx(follow_torso),"chest holds the same follow-through as the held shaft")
	var face: Node3D = p.rig.torso.get_node("Head")
	var relative_face: Basis = p.rig.root.global_basis.inverse()*face.global_basis
	check(absf(relative_face.get_euler().y)<0.22,"heavy gaze stays near target while chest follows through")
	check(absf(face.rotation.y)>0.4,"neck actively counterturns instead of freezing chest")
	var aligned := true
	for part in p.rig.head_parts:
		var motion: Transform3D = part.source.transform*part.rest.affine_inverse()
		var face_motion: Transform3D = face.transform*p.rig.head_parts[0].rest.affine_inverse()
		aligned = aligned and motion.is_equal_approx(face_motion)
	check(aligned,"eyes and hair share the face neck transform")
	p.combat.elapsed = 0.92
	p.animate(0,0)
	check(p.rig.torso.rotation.length()<0.001,"heavy recovers to neutral torso")
	p.combat.set_action("pull")
	p.combat.elapsed = 0.56
	p.animate(0,0)
	check(p.rig.torso.rotation.x>0.10 and p.rig.torso.position.z>0.03,"pull braces upper body backward")
	p.combat.set_action("light")
	p.combat.elapsed = 0.25
	p.animate(0,0)
	check(p.rig.torso.rotation.x< -0.08 and p.rig.torso.position.z<0,"thrust sends upper body forward")
	var head_follows := false
	for binding in p.rig.skinning.bindings:
		if binding.source.name=="Head":
			var pose: Transform3D = p.rig.skinning.skeleton.get_bone_global_pose(binding.bone)
			head_follows = pose.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY)>0.05
	check(head_follows,"rendered head bone follows torso movement")
	p.combat.set_action("finisher")
	p.combat.elapsed = 0.95
	p.animate(0,0)
	var support: Vector3 = p.to_local(p.rig.legs[-1].ankle.global_position)
	var body_center: Vector3 = p.rig.torso.transform*Vector3(0,0.25,0)
	check(body_center.z>=support.z-0.21 and body_center.z<=support.z+0.09,"kick moves support foot beneath upper body in fore-aft direction")
	check(absf(p.to_local(p.rig.legs[-1].ankle.to_global(Vector3(0,-0.1,0))).y)<0.002,"support foot is grounded at kick contact")
	var kick_weapon: Basis = p.rig.weapon.global_basis
	check(p.rig.root.position.z>0.04,"kick balances the hips backward over the support foot")
	check(absf(p.to_local(p.rig.legs[1].ankle.global_position).z+0.72)<0.003,"body counterbalance preserves actual forward kick reach")
	for time in [0.80,1.02,1.14]:
		p.combat.elapsed = time
		p.animate(0,0)
		check(p.rig.weapon.global_basis.is_equal_approx(kick_weapon),"staff stays braced while kick extends and retracts")
	var worst_grip := 0.0
	var worst_segment := 0.0
	var worst_case := ""
	for action in p.Combat.MOVES:
		if p.Combat.MOVES[action].hits.is_empty() and action not in ["guard","dodge","plant"]: continue
		for aim in [-0.9,-0.25,0.65]:
			p.pitch = aim
			p.combat.set_action(action)
			p.combat.drawn = true
			var duration: float = p.Combat.MOVES[action].duration
			for frame in range(ceili(duration*60)+1):
				p.combat.elapsed = minf(duration,frame/60.0)
				p.animate(0,0)
				for side in [-1,1]:
					var arm: Dictionary = p.rig.arms[side]
					var grip: Vector3 = p.rig.weapon.transform*Vector3(0,0.18 if side==-1 else -0.28,0)
					var release := smoothstep(0.38,0.60,p.combat.elapsed) if action=="throw" else 0.0
					var relaxed: Vector3 = arm.shoulder.position+Vector3(0,-0.72,-0.015)
					var expected: Vector3 = grip.lerp(relaxed,release)
					worst_grip = maxf(worst_grip,arm.hand.position.distance_to(expected))
					var error := maxf(absf(arm.shoulder.position.distance_to(arm.elbow.position)-0.39),absf(arm.elbow.position.distance_to(arm.hand.position)-0.39))
					if error>worst_segment:
						worst_segment = error
						worst_case = "%s %.3f aim %.2f side %d" % [action,p.combat.elapsed,aim,side]
	check(worst_grip<0.001,"all sampled hands follow held or released targets")
	check(worst_segment<0.002,"all sampled arm segments retain length: "+worst_case+" error "+str(worst_segment))
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	var before: Vector3 = p.rig.torso.rotation
	p.combat.set_action("light")
	p.animate(1.0/60,0)
	check(before.distance_to(p.rig.torso.rotation)<0.12,"runtime action change blends torso rather than snapping")
	check(is_zero_approx(p.combat.elapsed),"presentation does not advance authoritative combat time")
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	var high_ready: float = p.rig.weapon.position.y
	var ready_tip: Vector3 = p.rig.weapon.to_global(p.rig.weapon.get_node("TipContact").position)
	p.combat.elapsed = 0.30
	p.animate(0,0)
	check(ready_tip.distance_to(p.rig.weapon.get_node("TipContact").global_position)<0.002,"heavy holds its readable loaded silhouette before acceleration")
	p.combat.set_action("light")
	p.combat.elapsed = 0.11
	p.animate(0,0)
	check(high_ready-p.rig.weapon.position.y>0.3,"heavy chest-high windup is distinct from the low thrust preparation")
	var loaded: float = p.rig.root.position.z
	p.combat.elapsed = 0.25
	p.animate(0,0)
	check(loaded>0.02 and p.rig.root.position.z< -0.07,"thrust shifts the whole body from back-loaded to forward drive")
	check(absf(p.to_local(p.rig.legs[-1].ankle.to_global(Vector3(0,-0.1,0))).y)<0.002,"driving stance keeps the leading sole grounded at contact")
	print("TORSO_MOTION_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
