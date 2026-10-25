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
	for monster in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	p.yaw = 0
	p.rig.root.rotation = Vector3.ZERO
	p.combat.drawn = true
	p.combat.set_action("heavy")
	p.animate(0,0)
	var skeleton: Skeleton3D = p.rig.skinning.skeleton
	var pelvis: int = skeleton.find_bone("Pelvis")
	check(pelvis>=0 and skeleton.get_bone_parent(skeleton.find_bone("Spine"))==pelvis,"spine is connected to the pelvis")
	check(skeleton.get_bone_parent(skeleton.find_bone("LeftThigh"))==pelvis and skeleton.get_bone_parent(skeleton.find_bone("RightThigh"))==pelvis,"both femurs attach to the pelvis")
	var coat_blend := false
	for binding in p.rig.skinning.bindings:
		if binding.source.name!="Undercoat": continue
		var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for vertex in weights.size()/4:
			if bones[vertex*4+1]==pelvis and weights[vertex*4+1]>0.1: coat_blend = true
	check(coat_blend,"lower coat follows pelvis through blended waist weights")
	for time in [0.18,0.43,0.61,0.70]:
		p.combat.elapsed = time
		p.animate(0,0)
		check(absf(p.rig.pelvis.rotation.y)>0.1 and absf(p.rig.pelvis.rotation.y)<absf(p.rig.torso.rotation.y),"hips participate with less twist than chest")
		for side in [-1,1]:
			var leg: Dictionary = p.rig.legs[side]
			var expected: Vector3 = p.rig.pelvis.transform*Vector3(side*0.14,0,0)
			check(leg.hip.position.distance_to(expected)<0.001,"hip socket follows actual rotating pelvis")
			var sole: Vector3 = p.to_local(leg.ankle.to_global(Vector3(0,-0.1,0)))
			var width_ok := absf(sole.x-(-0.26 if side==-1 else 0.24))<0.002
			check(absf(sole.y)<0.002 and width_ok,"sole preserves ground and authored support width while pelvis turns")
		var belt: Node3D = p.rig.pelvis.get_node("Belt")
		check(belt.global_basis.is_equal_approx(p.rig.pelvis.global_basis),"belt follows hip rotation")
	p.combat.elapsed = 0.30
	p.animate(0,0)
	var loaded: Vector3 = p.rig.root.position
	var rear_knee: float = absf(p.rig.legs[1].knee.rotation.x)
	p.combat.elapsed = 0.43
	p.animate(0,0)
	check(loaded.z-p.rig.root.position.z>0.20,"heavy visibly transfers body mass from rear support toward forward support")
	check(loaded.y<p.rig.root.position.y-0.08,"heavy extends out of the loaded crouch during release")
	check(rear_knee>absf(p.rig.legs[1].knee.rotation.x)+0.08,"rear leg extends to drive the sweep")
	var support_preserved := true
	var no_penetration := true
	var no_sliding := true
	var planted := {}
	for frame in 111:
		p.combat.elapsed = minf(float(frame)/120,0.92)
		p.animate(0,0)
		var airborne := 0
		for side in [-1,1]:
			var sole: Vector3 = p.to_local(p.rig.legs[side].ankle.to_global(Vector3(0,-0.1,0)))
			if sole.y>0.002: airborne += 1
			no_penetration = no_penetration and sole.y>= -0.002
			if p.combat.elapsed>=0.20 and p.combat.elapsed<=0.69:
				if planted.has(side): no_sliding = no_sliding and sole.distance_to(planted[side])<0.002
				else: planted[side] = sole
		support_preserved = support_preserved and airborne<2
	check(support_preserved,"heavy opening and closing steps retain at least one grounded support foot")
	check(no_penetration,"heavy stepping soles do not pass below flat ground")
	check(no_sliding,"both soles stay planted through the loaded sweep and follow-through")
	p.combat.elapsed = 0.92
	p.animate(0,0)
	check(p.rig.pelvis.rotation.length()<0.001,"heavy recovery returns pelvis to neutral")
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.61
	p.animate(0,0)
	p.combat.set_action("guard")
	p.animate(1.0/60,0)
	check(p.rig.pelvis.rotation.y>0.1,"action handoff does not snap hips to neutral")
	for frame in 60: p.animate(1.0/60,0)
	check(absf(p.rig.pelvis.rotation.y)<0.001,"handoff settles to the new neutral stance")
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	world.add_child(saved)
	var saved_belt: MeshInstance3D = saved.get_node("Pelvis/Belt")
	var center := saved_belt.to_global(saved_belt.get_aabb().get_center())
	check(center.y>0.98 and center.y<1.02,"exported belt remains at the authored waist height")
	print("HIP_TRANSFER_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
