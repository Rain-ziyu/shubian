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
	var p = world.hunter
	p.set_physics_process(false)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for actor in get_nodes_in_group("monsters"): actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	p.global_position = Vector3(0,0.05,8)
	p.yaw = 0
	p.pitch = -0.25
	p.lock_target = null
	var arm: SpringArm3D = p.camera.get_parent()
	p.update_camera_framing(1.0/60)
	check(is_equal_approx(arm.spring_length,p.CAMERA_DISTANCE) and is_equal_approx(p.mount.rotation.x,p.pitch),"unlocked view retains its original distance and orbit")
	var target = get_nodes_in_group("monsters")[0]
	target.global_position = p.global_position+Vector3(0,0,-3)
	p.lock_target = target
	var previous: float = p.CAMERA_DISTANCE
	var peak_step := 0.0
	var hp: float = p.combat.health
	var stamina: float = p.combat.stamina
	var elapsed: float = p.combat.elapsed
	var weapon: Transform3D = p.rig.weapon.global_transform
	for frame in 120:
		p.update_camera_framing(1.0/60)
		peak_step = maxf(peak_step,absf(arm.spring_length-previous))
		previous = arm.spring_length
	check(arm.spring_length>5.6 and arm.spring_length<5.8,"near large target gains bounded framing distance")
	check(peak_step<0.12,"acquiring a close target eases the framing rather than jumping")
	check(p.mount.position.y>p.global_position.y+1.65 and p.mount.rotation.x< -0.30,"near framing raises the orbit for the large silhouette")
	check(p.pitch==-0.25 and p.yaw==0 and p.combat.health==hp and p.combat.stamina==stamina and p.combat.elapsed==elapsed and p.rig.weapon.global_transform.is_equal_approx(weapon),"framing does not change aiming, combat clocks, resources or weapon pose")
	for frame in 8: await physics_frame
	for frame in 8: await physics_frame
	var head: Vector2 = p.camera.unproject_position(p.global_position+Vector3.UP*1.8)
	var feet: Vector2 = p.camera.unproject_position(p.global_position)
	var hero_pixels := absf(feet.y-head.y)
	print("NEAR_HERO_PIXELS: ",hero_pixels)
	check(hero_pixels>160 and hero_pixels<280,"near creature framing keeps hunter large enough to read limb poses")
	check(p.camera.fov==62,"combat field of view matches the closer detail framing")
	# Compare the same physical pose and projection against the previous framing.
	arm.spring_length = 5.0+p.camera_pullback
	p.camera.fov = 68
	for frame in 8: await physics_frame
	var old_head: Vector2 = p.camera.unproject_position(p.global_position+Vector3.UP*1.8)
	var old_feet: Vector2 = p.camera.unproject_position(p.global_position)
	var old_pixels := absf(old_feet.y-old_head.y)
	check(hero_pixels/old_pixels>1.15,"same locked combat pose projects at least fifteen percent larger")
	print("HERO_FRAMING_RATIO: ",hero_pixels/old_pixels," before=",old_pixels," after=",hero_pixels)
	p.camera.fov = p.CAMERA_FOV
	p.update_camera_framing(1.0/60)
	for frame in 8: await physics_frame
	var wall = world.obstacle(Vector3(0,2.5,11),Vector3(8,6,0.3),Color.GRAY)
	for frame in 8: await physics_frame
	print("FRAMING_WALL: length=",arm.get_hit_length()," position=",p.camera.global_position," pivot=",p.mount.global_position)
	check(arm.get_hit_length()<arm.spring_length-0.1 and p.camera.global_position.z<10.85,"extended spring arm still retracts before a rear wall")
	wall.queue_free()
	target.global_position = p.global_position+Vector3(0,0,-20)
	for frame in 120: p.update_camera_framing(1.0/60)
	check(absf(arm.spring_length-p.CAMERA_DISTANCE)<0.001,"distant target returns to normal framing")
	target.global_position = p.global_position+Vector3(0,0,-3)
	p.pitch = 0.65
	for frame in 120: p.update_camera_framing(1.0/60)
	check(p.pitch==0.65,"high weakpoint aim is preserved independently of framing")
	p.lock_target = null
	for frame in 120: p.update_camera_framing(1.0/60)
	check(absf(arm.spring_length-p.CAMERA_DISTANCE)<0.001,"unlocking smoothly restores original distance")
	# Isolated geometry fixture across all species: the previous test only used
	# the first monster and missed the largest species shrinking the hunter.
	p.global_position=Vector3(100,.05,100)
	p.pitch=-.25
	p.yaw=0
	var viewport_rect=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	for monster in get_nodes_in_group("monsters"):
		for distance in [3.,6.,10.]:
			monster.global_position=p.global_position+Vector3(0,0,-distance)
			monster.rotation.y=PI
			monster.CreatureModel.animate(monster.mesh,monster.data,0,"idle",0,0)
			p.lock_target=monster
			for frame in range(180):p.update_camera_framing(1./60)
			await physics_frame
			await physics_frame
			var visible:=true
			var head_mesh: MeshInstance3D=monster.mesh.get_node("Neck/HeadSurface")
			for corner in range(8):
				var point=head_mesh.to_global(head_mesh.mesh.get_aabb().get_endpoint(corner))
				visible=visible and not p.camera.is_position_behind(point) and viewport_rect.has_point(p.camera.unproject_position(point))
			check(visible,"default lock view retains head bounds for "+str(monster.data.id)+" at "+str(distance))
			if distance<=6:
				var top=p.camera.unproject_position(p.global_position+Vector3.UP*1.8)
				var bottom=p.camera.unproject_position(p.global_position)
				check(absf(bottom.y-top.y)>=160,"near encounter retains readable hunter scale for "+str(monster.data.id))
		monster.global_position=Vector3(-100,0,-100)
	print("CAMERA_FRAMING_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
