extends SceneTree
## Direct pose continuity checks; combat timing and AI acceptance are separate.
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.combat.drawn = true
	for pair in [["light",0.37,"heavy"],["heavy",0.61,"light"],["pull",0.55,"light"],["reply",0.42,"flash"]]:
		p.combat.set_action(pair[0])
		p.combat.elapsed = pair[1]
		p.animate(0,0)
		var before := {}
		var grip_before: Vector3 = p.rig.weapon.global_position
		for side in [-1,1]: before[side] = p.rig.legs[side].ankle.global_position
		p.combat.set_action(pair[2])
		var health: float = p.combat.health
		var stamina: float = p.combat.stamina
		p.animate(1.0/60,0)
		var maximum := 0.0
		for side in [-1,1]: maximum = maxf(maximum,before[side].distance_to(p.rig.legs[side].ankle.global_position))
		print("STANCE_FIRST_FRAME: ",pair[0]," -> ",pair[2]," meters=",maximum)
		check(maximum<0.025,"ordinary chain does not snap stance foot on its first frame")
		check(p.rig.weapon.global_position.distance_to(grip_before)<0.08,"ordinary chain carries the weapon grip continuously")
		check(p.combat.elapsed==0 and p.combat.health==health and p.combat.stamina==stamina,"stance presentation preserves combat time and resources")
		for frame in 8:
			p.combat.elapsed += 1.0/60
			p.animate(1.0/60,0)
		var settled := {}
		for side in [-1,1]: settled[side] = p.rig.legs[side].ankle.global_position
		p.animate(0,0)
		for side in [-1,1]: check(settled[side].distance_to(p.rig.legs[side].ankle.global_position)<0.002,"stance reaches authored pose after transition")
	# Stopping movement is still the idle action: it needs its own handoff.
	for sample in 16:
		var armed := sample>=8
		p.combat.drawn = armed
		p.combat.set_action("idle")
		p.walk_clock = float(sample%8)*PI/4
		p.animate(0,4.5)
		var moving_feet := {}
		for side in [-1,1]: moving_feet[side] = p.rig.legs[side].ankle.global_position
		p.animate(1.0/60,0)
		var stop_step := 0.0
		for side in [-1,1]: stop_step = maxf(stop_step,moving_feet[side].distance_to(p.rig.legs[side].ankle.global_position))
		print("LOCOMOTION_STOP_FIRST_STEP: ",armed," meters=",stop_step)
		check(stop_step<0.035,"releasing movement does not teleport the foot to neutral")
		for frame in 8: p.animate(1.0/60,0)
		var stopped_feet := {}
		for side in [-1,1]: stopped_feet[side] = p.rig.legs[side].ankle.global_position
		p.animate(0,0)
		for side in [-1,1]: check(stopped_feet[side].distance_to(p.rig.legs[side].ankle.global_position)<0.002,"movement stop reaches its actual rest stance")
		p.animate(1.0/60,4.5)
		var start_step := 0.0
		for side in [-1,1]: start_step = maxf(start_step,stopped_feet[side].distance_to(p.rig.legs[side].ankle.global_position))
		check(start_step<0.035,"starting movement carries feet out of rest continuously")
		p.animate(0,4.5)
		var before_attack := {}
		for side in [-1,1]: before_attack[side] = p.rig.legs[side].ankle.global_position
		p.combat.set_action("light")
		p.animate(1.0/60,0)
		var attack_step := 0.0
		for side in [-1,1]: attack_step = maxf(attack_step,before_attack[side].distance_to(p.rig.legs[side].ankle.global_position))
		check(attack_step<0.035,"movement into attack carries the airborne foot height")

	p.combat.drawn = true
	# A late sweep has the largest return angle. Check its whole handoff, not
	# only the first frame, where a short blend can hide its peak rotation speed.
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.60
	p.animate(0,0)
	check(p.combat.request("light"),"late heavy accepts the ordinary light chain")
	var previous_tip: Vector3 = p.rig.weapon.get_node("TipContact").global_position
	var peak_step := 0.0
	for frame in 10:
		p.combat.advance(1.0/60)
		p.animate(1.0/60,0)
		var tip: Vector3 = p.rig.weapon.get_node("TipContact").global_position
		peak_step = maxf(peak_step,previous_tip.distance_to(tip))
		previous_tip = tip
	print("HEAVY_LIGHT_RETURN_STEP: ",peak_step)
	check(peak_step<0.28,"late heavy to light avoids a rapid mid-transition weapon jump at60Hz")
	check(is_equal_approx(p.combat.elapsed,10.0/60),"smoother weapon return does not delay the light combat clock")
	p.combat.set_action("light")
	p.combat.elapsed = 0.4
	p.animate(0,0)
	p.combat.set_action("heavy")
	p.animate(1.0/60,0)
	p.global_position += Vector3(12,0,0)
	p.motion_epoch += 1
	p.animate(1.0/60,0)
	for side in [-1,1]: check(p.rig.legs[side].ankle.global_position.distance_to(p.global_position)<2,"teleport cannot interpolate feet across the old location")
	print("STANCE_TRANSITION_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
