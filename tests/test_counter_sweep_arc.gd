extends SceneTree
## Controlled pose/contact fixture; guard permission and live inputs are tested separately.
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
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.global_position = Vector3.ZERO
	p.yaw = 0
	p.pitch = -0.25
	p.rig.root.rotation = Vector3.ZERO
	var target
	var index := 0
	for monster in get_nodes_in_group("monsters"):
		monster.set_physics_process(false)
		monster.set_process(false)
		monster.global_position = Vector3(80+index*12,0,80)
		index += 1
		if monster.data.id=="reedclaw": target = monster
	target.rotation = Vector3.ZERO
	target.phase = "idle"
	target.stagger = 0
	p.combat.set_action("reply")
	p.combat.elapsed = 0.23
	p.animate(0,0)
	var tip: Vector3 = p.rig.weapon.get_node("TipContact").global_position
	var body: MeshInstance3D = target.mesh.get_node("BodySurface")
	var offset: Vector3 = target.to_local(body.to_global(body.mesh.get_aabb().get_center()))
	target.global_position = tip+Vector3(0.5,0,0)-offset
	var hp: float = target.health
	var first_contact := -1.0
	var late_active_cue := false
	p.combat.set_action("reply")
	p.animate(0,0)
	for frame in 32:
		p.combat.advance(1.0/60)
		p.animate(1.0/60,0)
		p.update_weapon_contacts()
		if target.health<hp and first_contact<0: first_contact = p.combat.elapsed
		if p.combat.elapsed>0.40 and p.combat.elapsed<0.46: late_active_cue = late_active_cue or "攻击生效" in p.feedback.phase(p.combat).text
	print("COUNTER_SIDE_CONTACT: time=",first_contact," damage=",hp-target.health," shadows=",p.combat.shadow_lifetimes.size())
	check(tip.x>1.0,"fixture is on the right-hand sweep arc, away from the final forward blade")
	check(first_contact>0 and first_contact<0.36,"physical side contact occurs during the sweeping arc")
	check(target.health<hp and p.combat.shadow_lifetimes.size()==1,"actual side contact earns exactly one intent")
	check(late_active_cue,"HUD keeps the whole late sweep contact interval active")
	check(not "攻击生效" in p.feedback.phase(p.combat).text,"HUD ends the active cue after physical sweep contact ends")
	print("COUNTER_SWEEP_ARC_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
