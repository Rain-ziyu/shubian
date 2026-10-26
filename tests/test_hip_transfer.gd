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
			# Heavy now pivots its heel around the physical forefoot, so an
			# ankle-space point is no longer the invariant support location.
			var sole: Vector3 = p.to_local(leg.boot.to_global(Vector3(0,-0.5,-0.3)))
			var width_ok := absf(sole.x-(-0.26 if side==-1 else 0.24))<0.002
			check(absf(sole.y)<0.002 and width_ok,"forefoot preserves ground and authored support width while pelvis turns")
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
			var boot: MeshInstance3D = p.rig.legs[side].boot
			var sole: Vector3 = p.to_local(boot.to_global(Vector3(0,-0.5,-0.3)))
			if sole.y>0.002: airborne += 1
			no_penetration = no_penetration and sole.y>= -0.002
			for vertex: Vector3 in boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if is_equal_approx(vertex.y,-0.5): no_penetration = no_penetration and p.to_local(boot.to_global(vertex)).y>= -0.002
			if p.combat.elapsed>=0.20 and p.combat.elapsed<=0.69:
				if planted.has(side): no_sliding = no_sliding and sole.distance_to(planted[side])<0.002
				else: planted[side] = sole
		support_preserved = support_preserved and airborne<2
	check(support_preserved,"heavy opening and closing steps retain at least one grounded support foot")
	check(no_penetration,"heavy stepping soles do not pass below flat ground")
	check(no_sliding,"both forefeet stay planted while heels pivot through the loaded sweep and follow-through")
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
	p.combat.set_action("light")
	p.combat.elapsed = 0.15
	p.animate(0,0)
	var light_load: Vector3 = p.rig.root.position
	p.combat.elapsed = 0.25
	p.animate(0,0)
	var light_contact: Vector3 = p.rig.root.position
	check(light_load.z-light_contact.z>0.20,"light drives the body forward from the rear support")
	check(light_contact.y-light_load.y>0.07,"light extends from a loaded rear leg at contact")
	p.combat.elapsed = 0.30
	p.animate(0,0)
	check(p.rig.root.position.distance_to(light_contact)<0.001,"light holds its delivered body weight briefly through follow-through")
	var light_support := true
	var light_floor := true
	var closing_lift := 0.0
	for frame in 80:
		p.combat.elapsed = float(frame)/120
		p.animate(0,0)
		var grounded := 0
		for side in [-1,1]:
			var sole: Vector3 = p.to_local(p.rig.legs[side].ankle.to_global(Vector3(0,-0.1,0)))
			if sole.y<0.003: grounded += 1
			light_floor = light_floor and sole.y>= -0.003
			if side==-1 and p.combat.elapsed>0.42: closing_lift = maxf(closing_lift,sole.y)
		light_support = light_support and grounded>=1
	check(light_support and light_floor,"light opening and return retain support without floor penetration")
	check(closing_lift>0.04,"light lifts the front foot when returning instead of dragging it")
	p.combat.set_action("flash")
	p.combat.elapsed = 0.08
	p.animate(0,0)
	var flash_load: Vector3 = p.rig.root.position
	p.combat.elapsed = 0.23
	p.animate(0,0)
	check(flash_load.z-p.rig.root.position.z>0.15,"flash drives the pelvis forward from its loaded support")
	check(p.rig.root.position.y-flash_load.y>0.05,"flash extends the loaded leg at contact")
	check(absf(p.rig.pelvis.rotation.y)>0.04,"flash hips turn with the chest")
	var flash_support := true
	var flash_floor := true
	var flash_return := {-1:0.0,1:0.0}
	for frame in 71:
		p.combat.elapsed = minf(float(frame)/120,0.58)
		p.animate(0,0)
		var grounded := 0
		for side in [-1,1]:
			var sole: Vector3 = p.to_local(p.rig.legs[side].ankle.to_global(Vector3(0,-0.1,0)))
			if sole.y<0.003: grounded += 1
			flash_floor = flash_floor and sole.y>= -0.003
			if p.combat.elapsed>0.30: flash_return[side] = maxf(flash_return[side],sole.y)
		flash_support = flash_support and grounded>=1
	check(flash_support and flash_floor,"flash staggered return steps retain grounded support without penetration")
	check(flash_return[-1]>0.035 and flash_return[1]>0.025,"both flash return steps lift instead of sliding")
	check(absf(p.rig.root.position.z)<0.001 and absf(p.rig.pelvis.rotation.y)<0.001,"flash settles body and hips to neutral at its actual end")
	p.combat.set_action("pull")
	p.combat.elapsed = 0.22
	p.animate(0,0)
	var pull_reach: Vector3 = p.rig.root.position
	var pull_feet := {}
	for side in [-1,1]: pull_feet[side] = p.rig.legs[side].ankle.global_position
	p.combat.elapsed = 0.56
	p.animate(0,0)
	check(p.rig.root.position.z-pull_reach.z>0.16,"hook pull shifts the body rearward with the returning shaft")
	check(p.rig.root.position.y<pull_reach.y-0.025,"hook pull sits into the support legs")
	check(absf(p.rig.pelvis.rotation.y)>0.04,"hook pull carries the pelvis with the chest")
	for side in [-1,1]:
		check(p.rig.legs[side].ankle.global_position.distance_to(pull_feet[side])<0.003,"hook pull preserves planted support feet")
	for sample in [["guard",0.18],["reply",0.12],["reply",0.26],["reply",0.42]]:
		p.combat.set_action(sample[0])
		p.combat.elapsed = sample[1]
		p.animate(0,0)
		check(absf(p.rig.pelvis.rotation.y)>0.04 and absf(p.rig.pelvis.rotation.y)<absf(p.rig.torso.rotation.y),"guard/reply hips support the chest turn without locking to it")
		var grounded := 0
		for side in [-1,1]:
			var leg: Dictionary = p.rig.legs[side]
			var sole: Vector3 = p.to_local(leg.ankle.to_global(Vector3(0,-0.1,0)))
			if sole.y<0.003: grounded += 1
			check(sole.y>= -0.003,"guard/reply pelvic rotation does not sink the support foot")
			check(leg.hip.position.distance_to(p.rig.pelvis.transform*Vector3(side*0.14,0,0))<0.001,"guard/reply thigh sockets follow the anatomical pelvis")
		check(grounded>=1,"guard/reply retain a support foot during the turn")
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	p.combat.set_action("reply")
	var counter_support := {}
	var counter_planted := true
	var counter_grounded := true
	var counter_drift := 0.0
	var counter_height := 0.0
	for frame in 65:
		p.combat.elapsed = 0.54*frame/64
		p.animate(0,0)
		for side in [-1,1]:
			var foot: Vector3 = p.to_local(p.rig.legs[side].boot.to_global(Vector3(0,-0.5,-0.3)))
			# The lead foot already takes a 6 cm opening step, with a 4.5 cm
			# lift. Measure its planted interval, not that intentional step.
			if side==-1 and (p.combat.elapsed<0.16 or p.combat.elapsed>0.42): continue
			if not counter_support.has(side): counter_support[side] = foot
			counter_planted = counter_planted and Vector2(foot.x,foot.z).distance_to(Vector2(counter_support[side].x,counter_support[side].z))<0.002
			counter_grounded = counter_grounded and absf(foot.y)<0.002
			counter_drift = maxf(counter_drift,Vector2(foot.x,foot.z).distance_to(Vector2(counter_support[side].x,counter_support[side].z)))
			counter_height = maxf(counter_height,absf(foot.y))
	print("COUNTER_SUPPORT_DEVIATION: horizontal=",counter_drift," vertical=",counter_height)
	check(counter_planted and counter_grounded,"counter pivots both heels around stationary grounded forefeet")
	check(p.rig.legs[1].sole_yaw>0.30 and p.rig.legs[-1].sole_yaw>0.10 and p.rig.legs[1].sole_yaw>p.rig.legs[-1].sole_yaw*2,"rear support turns farther to drive the tail-grip counter")
	p.combat.elapsed = 0.82
	p.animate(0,0)
	check(absf(p.rig.legs[1].sole_yaw)<0.001 and absf(p.rig.legs[-1].sole_yaw)<0.001,"counter restores ready foot direction at recovery end")
	world.add_child(saved)
	var saved_belt: MeshInstance3D = saved.get_node("Pelvis/Belt")
	var center := saved_belt.to_global(saved_belt.get_aabb().get_center())
	check(center.y>0.98 and center.y<1.02,"exported belt remains at the authored waist height")
	var saved_skeleton: Skeleton3D = saved.get_node("Skeleton3D")
	var saved_preview: AnimationPlayer = saved.get_node("AnimationPreview")
	var saved_skin: Skin
	for part in saved_skeleton.get_children():
		if part is MeshInstance3D: saved_skin = part.skin; break
	var saved_support := {}
	var saved_planted := true
	for frame in 33:
		saved_preview.play("reply")
		saved_preview.seek(0.18+0.22*frame/32,true)
		for side in [-1,1]:
			var boot: Node3D = saved.get_node("Leg"+str(side)+"/Knee/Ankle/ForestBoot")
			var rest_point: Vector3 = saved.to_local(boot.to_global(Vector3(0,-0.5,-0.3)))
			var bone := saved_skeleton.find_bone("LeftFoot" if side==-1 else "RightFoot")
			var point := saved_skeleton.to_global(saved_skeleton.get_bone_global_pose(bone)*saved_skin.get_bind_pose(bone)*rest_point)
			if frame==0: saved_support[side] = point
			saved_planted = saved_planted and point.distance_to(saved_support[side])<0.002 and absf(point.y)<0.002
	check(saved_planted,"saved counter clip preserves grounded forefeet between authored keys")
	check(saved_skeleton.get_bone_global_pose(saved_skeleton.find_bone("RightFoot")).basis.get_euler().y>0.30,"saved counter clip turns the rear foot with the body")
	print("HIP_TRANSFER_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
