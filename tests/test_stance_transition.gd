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
