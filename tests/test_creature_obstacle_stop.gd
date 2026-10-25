extends "res://tests/test_creature_approach.gd"
## Real temporary collision wall; ordinary AI stops and resumes without state injection.
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	world.hunter.set_physics_process(false)
	world.hunter.set_process_unhandled_input(false)
	world.hunter.position = Vector3(200,0,200)
	for frame in 20: await physics_frame
	var actors := get_nodes_in_group("monsters")
	for actor in actors: actor.set_physics_process(false)
	for actor in actors:
		for hold_frames in [2,15]: await obstacle_case(world,actor,hold_frames)
	print("CREATURE_OBSTACLE_STOP_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
func obstacle_case(world: Node3D, actor: CharacterBody3D, hold_frames: int) -> void:
	var label := str(actor.data.id)+" hold="+str(hold_frames)
	world.hunter.position = actor.position+Vector3(0,0,-10)
	actor.set_physics_process(true)
	var moving_frames := 0
	for frame in 600:
		await physics_frame
		if actor.phase=="idle" and Vector2(actor.velocity.x,actor.velocity.z).length()>1: moving_frames += 1
		if moving_frames>=20: break
	check(moving_frames>=20,"ordinary AI pursues before obstruction: "+label)
	if moving_frames<20:
		actor.set_physics_process(false)
		return
	var direction := Vector3(actor.velocity.x,0,actor.velocity.z).normalized()
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.position = actor.position+direction*(float(actor.data.size)*0.54+0.2)+Vector3.UP*3
	wall.rotation.y = atan2(-direction.x,-direction.z)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,8,0.2)
	collider.shape = box
	wall.add_child(collider)
	world.add_child(wall)
	var stopped := false
	var prior_height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
	var prior_feet := feet(actor)
	var prior_position := actor.global_position
	for frame in 180:
		await physics_frame
		var height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
		if actor.phase=="idle" and Vector2(actor.velocity.x,actor.velocity.z).length()<0.1:
			stopped = true
			var jump := relative_foot_jump(actor,prior_feet,prior_position)
			print("OBSTACLE_STOP: ",label," body=",absf(height-prior_height)," foot=",jump)
			check(absf(height-prior_height)<0.01,"obstacle stop preserves body posture: "+label)
			check(jump<0.02,"obstacle stop preserves ankles after actual actor travel: "+label)
			break
		prior_height = height
		prior_feet = feet(actor)
		prior_position = actor.global_position
	check(stopped,"collision wall stops ordinary pursuit: "+label)
	if not stopped:
		wall.queue_free()
		actor.set_physics_process(false)
		return
	for frame in hold_frames: await physics_frame
	check(Vector2(actor.velocity.x,actor.velocity.z).length()<0.1,"fixture remains physically blocked: "+label)
	if hold_frames>=15:
		var height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
		check(absf(height)<0.002,"longer stop reaches authored resting height: "+label)
	prior_height = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
	prior_feet = feet(actor)
	prior_position = actor.global_position
	wall.queue_free()
	var resumed := false
	for frame in 180:
		await physics_frame
		var height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
		if actor.phase=="idle" and Vector2(actor.velocity.x,actor.velocity.z).length()>1:
			resumed = true
			var jump := relative_foot_jump(actor,prior_feet,prior_position)
			print("OBSTACLE_RESUME: ",label," body=",absf(height-prior_height)," foot=",jump)
			check(absf(height-prior_height)<0.01,"brief or settled stop resumes without a body pop: "+label)
			check(jump<0.02,"resume preserves ankles after actual actor travel: "+label)
			break
		prior_height = height
		prior_feet = feet(actor)
		prior_position = actor.global_position
	check(resumed,"ordinary pursuit resumes after wall removal: "+label)
	actor.set_physics_process(false)
func relative_foot_jump(actor: CharacterBody3D, before: Dictionary, position_before: Vector3) -> float:
	var current := feet(actor)
	var travel := actor.global_position-position_before
	var result := 0.0
	for name in before: result = maxf(result,(current[name]-before[name]-travel).length())
	return result
