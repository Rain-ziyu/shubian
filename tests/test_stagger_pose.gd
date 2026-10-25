extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func ankle(actor: CharacterBody3D, name: String) -> Vector3:
	var leg: Node3D = actor.mesh.get_node(name)
	var bones: Skeleton3D = leg.get_node("LegSkeleton")
	return actor.to_local(leg.to_global(bones.get_bone_global_pose(2).origin))
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	var monsters := get_nodes_in_group("monsters")
	for i in monsters.size():
		monsters[i].set_physics_process(false)
		monsters[i].global_position = Vector3(80+i*12,0,80)
	await physics_frame
	await physics_frame
	for m in monsters:
		m.global_position = Vector3(0,0.01,-16)
		m.rotation = Vector3.ZERO
		m.velocity = Vector3.ZERO
		p.global_position = Vector3(30,0,0)
		await physics_frame
		await physics_frame
		for frame in 4: m._physics_process(1.0/60)
		p.global_position = m.global_position+Vector3(4,0,0)
		m.phase = "windup"
		m.clock = m.data.windup*0.8
		m.CreatureModel.animate(m.mesh,m.data,1.1,"windup",m.clock,0,m.foot_ground_height,m.foot_ground_normal)
		m.rear_attack = m.data.has("rear_attack")
		m.rear_cooldown = 2
		m.mesh.get_node("Tail").rotation.y = -0.6
		var body: Transform3D = m.mesh.transform
		var neck: Transform3D = m.mesh.get_node("Neck").transform
		var jaw: Transform3D = m.mesh.get_node("Neck/Jaw").transform
		var foot := ankle(m,"Hind1")
		var tail: Skeleton3D = m.mesh.get_node("Tail/TailSkeleton")
		var tail_before := tail.get_bone_pose_rotation(3)
		m.receive_strike(1,p.global_position,"reply","body")
		var health: float = m.health
		m._physics_process(1.0/60)
		if m.data.pattern=="mist":
			var sac: MeshInstance3D = m.mesh.get_node("Neck/MistSac1")
			check(sac.scale.is_equal_approx(sac.get_meta("rest_scale")),"interrupting mist abandons the inflated pressure cue")
		check(m.mesh.transform.is_equal_approx(body) and m.mesh.get_node("Neck").transform.is_equal_approx(neck),"stagger begins from captured body and neck: "+str(m.data.id))
		check(m.mesh.get_node("Neck/Jaw").transform.is_equal_approx(jaw),"interruption starts from the actual loaded jaw pose")
		check(ankle(m,"Hind1").distance_to(foot)<0.003,"stagger entry preserves actual ankle position")
		check(absf(tail.get_bone_pose_rotation(3).dot(tail_before))>0.99999,"stagger entry preserves deformed tail bone")
		check(not m.rear_attack and not m.rear_tell.visible and m.rear_cooldown>0,"interruption cancels pending tail attack but preserves cooldown")
		for frame in 20: m._physics_process(1.0/60)
		check(m.mesh.get_node("Neck").rotation.x>0.02 and absf(m.mesh.get_node("Tail").rotation.y)<0.001,"stagger releases loaded neck into brace and releases the tail instead of freezing")
		var leg: Node3D = m.mesh.get_node("Hind1")
		var bones: Skeleton3D = leg.get_node("LegSkeleton")
		var foot_mesh: MeshInstance3D = leg.get_node("Foot")
		var sole := leg.to_global(bones.get_bone_global_pose(2)*bones.get_bone_global_rest(2).affine_inverse()*(foot_mesh.transform*Vector3(0,-0.5,0)))
		check(sole.y>= -0.003,"stagger keeps rendered sole above flat floor")
		check(absf(bones.get_bone_global_pose(0).origin.distance_to(bones.get_bone_global_pose(1).origin)-bones.get_bone_rest(1).origin.length())<0.001,"stagger preserves leg segment length")
		for frame in 18: m._physics_process(1.0/60)
		check(m.stagger==0 and m.phase=="recover" and m.mesh.get_node("Neck").rotation.length()<0.001,"recovery does not restart abandoned attack follow-through")
		check(m.mesh.get_node("Neck/Jaw").rotation.length()<0.001,"stagger closes the jaw smoothly and recovery does not restart the cancelled mouth action")
		check(m.health==health and p.combat.health==240,"pose blend injects no damage or health change")
		m.stagger = 1.3
		m.was_staggering = false
		m.velocity = Vector3.ZERO
		for frame in 25: m._physics_process(1.0/60)
		check(m.stagger>0.8 and m.mesh.get_node("Neck").rotation.x>0.08,"long stagger retains a lowered, braced head instead of standing ready: "+str(m.data.id))
		check(m.mesh.position.y-float(m.mesh.get_meta("ground_offset",0.0))< -float(m.data.size)*0.015,"long stagger keeps weight lowered until recovery")
		for frame in 65: m._physics_process(1.0/60)
		check(m.stagger==0 and m.mesh.get_node("Neck").rotation.length()<0.001,"long stagger releases brace without restarting attack")
		m.global_position = Vector3(80+monsters.find(m)*12,0,80)
		await physics_frame
		await physics_frame
	print("STAGGER_POSE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
