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
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.combat.drawn = true
	p.animate(0,0)
	var neutral: Transform3D = p.rig.weapon.transform
	p.combat.set_action("fourfold")
	for t in [0.0,1.25]:
		p.combat.elapsed = t
		p.animate(0,0)
		check(p.rig.weapon.transform.is_equal_approx(neutral),"fourfold begins and finishes at ready pose")
	for hit in p.Combat.MOVES.fourfold.hits:
		p.combat.elapsed = hit
		p.animate(0,0)
		var forward: float = p.rig.weapon.position.z
		var body_contact: Vector3 = p.rig.root.position
		var support := {}
		for side in [-1,1]: support[side] = p.rig.legs[side].ankle.global_position
		check(absf(p.rig.pelvis.rotation.y)>0.06,"each stab transfers twist into the pelvis")
		check(absf(forward-(neutral.origin.z-0.15))<0.001,"each beat retains intended contact extension")
		p.combat.elapsed = hit+0.10
		p.animate(0,0)
		check(p.rig.weapon.position.z>neutral.origin.z+0.02,"each stab visibly recoils before next beat")
		check(p.rig.root.position.z>body_contact.z+0.035,"each stab recovers body mass before the next drive")
		for side in [-1,1]: check(p.rig.legs[side].ankle.global_position.distance_to(support[side])<0.003,"rapid stabs retain planted support")
	print("FOURFOLD_TRAJECTORY_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
