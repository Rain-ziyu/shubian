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
	# This is a controlled fixture, not a window-input test.
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.yaw = 0
	p.pitch = -0.25
	p.rig.root.rotation.y = 0
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	for action in ["idle","light","heavy","turn","guard","reply","flash","fourfold","spin","plant","wait","counter_window","finisher"]:
		p.combat.set_action(action)
		p.combat.drawn = true
		for phase in [0.0,0.15,0.35,0.65,0.95]:
			p.combat.elapsed = phase*float(p.Combat.MOVES.get(action,{"duration":1}).duration)
			p.animate(0,0)
			for side in [-1,1]:
				var arm: Dictionary = p.rig.arms[side]
				var grip: Vector3 = p.rig.weapon.transform*Vector3(0,0.18 if side==-1 else -0.28,0)
				if action=="reply" and side==-1 and p.combat.elapsed>0:
					if p.combat.elapsed>=0.12 and p.combat.elapsed<=0.54: check(arm.hand.position.distance_to(grip)>0.10,"counter sweep releases the left hand for balance")
				else: check(arm.hand.position.distance_to(grip)<0.001,"hand follows grip "+action)
				check(arm.shoulder.position.distance_to(grip)<0.80,"grip reachable "+action)
	p.combat.set_action("guard")
	p.combat.elapsed = 0
	p.animate(0,0)
	var head_start: Vector3 = p.rig.weapon.transform*Vector3(0,1.1,0)
	check(head_start.z<0,"guard begins head forward")
	p.combat.elapsed = 0.3
	p.animate(0,0)
	var head_end: Vector3 = p.rig.weapon.transform*Vector3(0,1.1,0)
	var butt_end: Vector3 = p.rig.weapon.transform*Vector3(0,-0.93,0)
	check(head_end.z>0 and butt_end.z<0,"guard rotates head rearward and butt forward")
	p.combat.set_action("reply")
	p.combat.elapsed = 0
	p.animate(0,0)
	var reply_head: Vector3 = p.rig.weapon.transform*Vector3(0,1.1,0)
	var reply_butt: Vector3 = p.rig.weapon.transform*Vector3(0,-0.93,0)
	check(reply_head.z>0 and reply_butt.z<0,"reply begins from braced butt-forward guard rather than rewinding")
	var pivot: Vector3 = p.rig.weapon.transform*Vector3(0,-0.28,0)
	for time in [0.10,0.26,0.36,0.52]:
		p.combat.elapsed = time
		p.animate(0,0)
		check((p.rig.weapon.transform*Vector3(0,-0.28,0)).distance_to(pivot)<0.001,"counter rotates around the right-hand grip")
		if time==0.26: check(absf(p.rig.weapon.get_node("TipContact").position.y)>1,"counter retains its physical blade endpoint")
		if time==0.36:
			check(p.rig.weapon.get_node("TipContact").global_position.z-p.rig.root.global_position.z< -0.8,"counter sweep brings the blade forward at its actual contact beat")
			check(p.rig.arms[-1].hand.position.distance_to(p.rig.weapon.transform*Vector3(0,0.18,0))>0.10,"left hand is visibly free at contact")
	p.combat.elapsed = 0.82
	p.animate(0,0)
	for side in [-1,1]: check(p.rig.arms[side].hand.position.distance_to(p.rig.weapon.transform*Vector3(0,0.18 if side==-1 else -0.28,0))<0.001,"counter recovers the two-hand ready grip")
	for action in ["guard","reply"]:
		var heights := []
		for aim in [-0.25,0.25]:
			p.pitch = aim
			p.combat.set_action(action)
			p.combat.elapsed = 0.18 if action=="guard" else 0.36
			p.animate(0,0)
			heights.append(p.rig.weapon.get_node("ButtContact" if action=="guard" else "TipContact").global_position.y)
		check(float(heights[1])-float(heights[0])>0.5,"raising aim elevates the actual butt contact for "+action)
	p.pitch = 0.25
	p.combat.set_action("guard")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	var raised_guard: Transform3D = p.rig.weapon.transform
	p.combat.set_action("reply")
	p.animate(0,0)
	check(p.rig.weapon.transform.is_equal_approx(raised_guard),"raised reply joins the actual raised guard without a shaft jump")
	for aim in [-0.9,0.65]:
		p.pitch = aim
		p.combat.set_action("light")
		p.combat.elapsed = 0.25
		p.animate(0,0)
		for side in [-1,1]:
			var arm: Dictionary = p.rig.arms[side]
			check(arm.shoulder.position.distance_to(arm.hand.position)<0.80,"aimed thrust grip remains reachable")
	print("RIG_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
