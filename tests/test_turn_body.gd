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
	world.hunter.set_process_input(false)
	world.hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.yaw = 0
	var turn_input := InputEventMouseButton.new()
	turn_input.button_index = MOUSE_BUTTON_LEFT
	turn_input.pressed = true
	turn_input.alt_pressed = true
	p._unhandled_input(turn_input)
	check(p.combat.action=="turn","Alt left input starts the ordinary turn")
	p.combat.elapsed = 0.30
	p.animate(0,0)
	check(absf(wrapf(p.rig.root.rotation.y,-PI,PI))>1.0,"turn rotates full body rather than only weapon")
	check(absf(p.rig.legs[-1].ankle.global_position.y-p.rig.legs[1].ankle.global_position.y)>0.04,"turn lifts alternating feet")
	check(p.rig.weapon.position.z< -0.20,"ordinary turn keeps the grip in front of its rotating chest")
	var weapon_before: Transform3D = p.rig.weapon.global_transform
	var facing_before: Vector3 = p.combat_forward()
	p.clear_body_turn()
	check(p.rig.weapon.global_transform.is_equal_approx(weapon_before),"removing presentation turn preserves actual weapon transform")
	check(p.combat_forward().distance_to(facing_before)<0.001,"removing presentation turn preserves combat heading")
	check(is_zero_approx(p.yaw),"body turn does not rotate camera yaw")
	p.combat.elapsed = 0.60
	p.animate(0,0)
	check(absf(wrapf(p.rig.root.rotation.y,-PI,PI))<0.001,"body completes rotation before ordinary combo window")
	p.combat.set_action("guard")
	p.animate(0,0)
	check(absf(wrapf(p.rig.root.rotation.y,-PI,PI))<0.001,"next guard keeps authoritative facing")
	p.combat.set_action("turn")
	p.combat.elapsed = 0.30
	p.animate(0,0)
	p.combat.set_action("guard")
	p.combat.elapsed = 0.2
	p.animate(1.0/60,0)
	p.take_damage(20,p.global_position+Vector3.FORWARD*3,true)
	check(p.combat.health==240 and p.combat.guard_reward>0,"residual body motion cannot turn away a valid frontal guard")
	var m = get_nodes_in_group("monsters")[0]
	m.global_position = Vector3(-2,0,0)
	p.global_position = Vector3(0,0.05,0)
	p.combat.set_action("turn")
	p.combat.elapsed = 0.44
	p.animate(0,0)
	var hp: float = m.health
	p.on_strike(0)
	p.update_weapon_contacts()
	check(m.health<hp,"body turn retains actual swept weapon contact")
	p.combat.set_action("spin")
	var previous := 0.0
	var total := 0.0
	var lifted := 0.0
	var worst_step := 0.0
	var grip_stays_forward := true
	for frame in 82:
		p.combat.elapsed = minf(float(frame)/60,1.35)
		p.animate(0,0)
		var angle: float = p.rig.root.rotation.y
		var step := wrapf(angle-previous,-PI,PI)
		if frame>0:
			total += step
			worst_step = maxf(worst_step,absf(step))
		previous = angle
		grip_stays_forward = grip_stays_forward and p.rig.weapon.position.z< -0.25
		lifted = maxf(lifted,absf(p.rig.legs[-1].ankle.global_position.y-p.rig.legs[1].ankle.global_position.y))
	check(absf(total-TAU)<0.002 and worst_step<0.17,"spin turns the full body continuously through one revolution")
	check(lifted>0.08,"spin steps with alternating feet rather than rotating a fixed stance")
	check(grip_stays_forward,"spin carries the grip center in front of the turning chest")
	check(absf(wrapf(p.rig.root.rotation.y,-PI,PI))<0.002 and is_zero_approx(p.yaw),"spin settles facing forward without changing camera yaw")
	for pair in [[0.24,0.38,0.055],[0.68,0.85,0.035]]:
		p.combat.elapsed = pair[0]
		p.animate(0,0)
		var loaded_height: float = p.rig.root.position.y
		p.combat.elapsed = pair[1]
		p.animate(0,0)
		check(p.rig.root.position.y-loaded_height>float(pair[2]),"spin extends out of a distinct leg load for each hit")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	var spin_weapon: Transform3D = p.rig.weapon.global_transform
	var spin_heading: Vector3 = p.combat_forward()
	p.clear_body_turn()
	check(p.rig.weapon.global_transform.is_equal_approx(spin_weapon) and p.combat_forward().distance_to(spin_heading)<0.002,"spin presentation preserves world weapon contact and combat heading when cleared")
	var spin_health: float = p.combat.health
	p.take_damage(20,p.global_position+Vector3.FORWARD*3,true)
	check(p.combat.action=="spin" and is_equal_approx(p.combat.health,spin_health-20),"spinning body retains armor while taking actual damage")
	p.combat.set_action("finisher")
	previous = 0
	total = 0
	lifted = 0
	grip_stays_forward = true
	for frame in 91:
		p.combat.elapsed = float(frame)/120
		p.animate(0,0)
		var angle: float = p.rig.root.rotation.y
		if frame>0: total += wrapf(angle-previous,-PI,PI)
		previous = angle
		grip_stays_forward = grip_stays_forward and p.rig.weapon.position.z< -0.20
		if p.combat.elapsed<0.50: lifted = maxf(lifted,absf(p.rig.legs[-1].ankle.global_position.y-p.rig.legs[1].ankle.global_position.y))
	check(absf(total-TAU)<0.002,"finisher turns the whole body once before the forward kick")
	check(lifted>0.05,"finisher rotation includes stepping before kick preparation")
	check(grip_stays_forward,"finisher carries its two-hand grip in front of the turning chest")
	p.combat.elapsed = 0.95
	p.animate(0,0)
	check(absf(wrapf(p.rig.root.rotation.y,-PI,PI))<0.002 and is_zero_approx(p.yaw),"finisher returns to committed forward heading before kick contact")
	print("TURN_BODY_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
