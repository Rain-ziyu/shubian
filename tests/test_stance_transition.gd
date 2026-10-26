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
	for pair in [["light",0.37,"heavy"],["heavy",0.61,"light"],["pull",0.55,"light"],["reply",0.54,"heavy"]]:
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
		print("STANCE_WEAPON_FIRST_STEP: ",pair[0]," -> ",pair[2]," meters=",p.rig.weapon.global_position.distance_to(grip_before))
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
	for sample in [["heavy",0.43],["turn",0.30],["fourfold",0.43],["finisher",0.95],["dodge",0.40]]:
		p.combat.set_action(sample[0])
		p.combat.elapsed = sample[1]
		p.animate(0,0)
		var before_hurt := {}
		var sole_before_hurt := {}
		for side in [-1,1]:
			before_hurt[side] = p.rig.legs[side].ankle.global_position
			sole_before_hurt[side] = p.rig.legs[side].boot.global_basis.orthonormalized().get_rotation_quaternion()
		var hp_before: float = p.combat.health
		p.take_damage(1,p.global_position+Vector3.FORWARD,false)
		check(p.combat.action=="hurt" and p.combat.health==hp_before-1,"controlled damage really interrupts "+sample[0])
		p.animate(1.0/60,0)
		var hurt_step := 0.0
		for side in [-1,1]: hurt_step = maxf(hurt_step,before_hurt[side].distance_to(p.rig.legs[side].ankle.global_position))
		print("HURT_FIRST_FRAME_STEP: ",sample[0]," meters=",hurt_step)
		check(hurt_step<0.05,"damage carries actual feet into recoil instead of resetting them: "+sample[0])
		for side in [-1,1]:
			check(sole_before_hurt[side].angle_to(p.rig.legs[side].boot.global_basis.orthonormalized().get_rotation_quaternion())<0.20,"damage carries sole heading instead of instantly flattening it")

		for frame in 10:
			p.combat.advance(1.0/60)
			p.animate(1.0/60,0)
		check(is_equal_approx(p.combat.elapsed,10.0/60),"hurt pose blend does not delay recovery clock")
	p.global_position += Vector3(12,0,0)
	p.motion_epoch += 1
	p.animate(1.0/60,0)
	for side in [-1,1]: check(p.rig.legs[side].ankle.global_position.distance_to(p.global_position)<2,"relocation invalidates captured hurt feet and sole orientation")
	for chain in [["reply",0.54,"heavy"],["heavy",0.60,"light"],["light",0.37,"heavy"],["pull",0.55,"light"],["spin",1.08,"light"],["spin",1.08,"heavy"]]:
		p.combat.drawn = true
		p.pitch = -0.25
		p.combat.set_action(chain[0])
		p.combat.elapsed = chain[1]
		p.animate(0,0)
		var hands_before := {}
		for side in [-1,1]: hands_before[side] = p.rig.arms[side].hand.position
		p.combat.set_action(chain[2])
		var peak_hand_step := 0.0
		var arm_error := 0.0
		var right_on_shaft := true
		for frame in 25:
			p.combat.elapsed = frame/120.0
			p.animate(1.0/120,0)
			for side in [-1,1]:
				var arm: Dictionary = p.rig.arms[side]
				peak_hand_step = maxf(peak_hand_step,hands_before[side].distance_to(arm.hand.position))
				arm_error = maxf(arm_error,maxf(absf(arm.upper.scale.y-0.39),absf(arm.lower.scale.y-0.39)))
				hands_before[side] = arm.hand.position
			var right_local: Vector3 = p.rig.weapon.transform.affine_inverse()*p.rig.arms[1].hand.position
			right_on_shaft = right_on_shaft and Vector2(right_local.x,right_local.z).length()<0.001
		print("CHAIN_REGRIP: ",chain," step=",peak_hand_step," bone_error=",arm_error)
		check(peak_hand_step<0.12,"chain regrips without a sudden hand teleport: "+str(chain))
		check(arm_error<0.002,"both arms retain anatomical lengths through handoff: "+str(chain))
		check(right_on_shaft,"right hand slides on the physical shaft during handoff: "+str(chain))
		var settled_grips := true
		for side in [-1,1]:
			var local: Vector3 = p.rig.weapon.transform.affine_inverse()*p.rig.arms[side].hand.position
			settled_grips = settled_grips and local.distance_to(Vector3(0,0.18 if side==-1 else -0.28,0))<0.001
		check(settled_grips,"both ordinary grips settle before the new attack contact: "+str(chain))
	print("STANCE_TRANSITION_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
