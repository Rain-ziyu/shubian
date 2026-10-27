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
	var actors := get_nodes_in_group("monsters")
	for index in actors.size():
		actors[index].set_physics_process(false)
		actors[index].global_position = Vector3(100+index*15,0,100)
	for actor in actors:
		actor.global_position = Vector3(0,0.01,-16)
		actor.rotation.y = PI
		actor.CreatureModel.animate(actor.mesh,actor.data,0,"idle",0,0)
		p.global_position = actor.global_position+Vector3(0,0.01,float(actor.data.size)*1.4+1.5)
		var start: Vector3 = p.global_position
		var blocker = actor.get_node("HeadBlocker")
		var head_contact := false
		await physics_frame
		await physics_frame
		for frame in 180:
			p.velocity = Vector3(0,-1,-2)
			p.move_and_slide()
			for index in p.get_slide_collision_count():
				if p.get_slide_collision(index).get_collider()==blocker: head_contact = true
			await physics_frame
		check(not overlaps_head(p),"forward movement stops outside visible head: "+str(actor.data.id))
		check(p.global_position.distance_to(start)>0.5,"empty approach space remains traversable")
		if actor.data.id=="mossback": check(head_contact,"known long-snout penetration is stopped by actual head obstruction")
		check(blocker.collision_layer==4 and blocker.collision_mask==0,"head obstruction affects player mask without changing terrain/AI body motion")
		actor.CreatureModel.animate(actor.mesh,actor.data,0,"windup",float(actor.data.windup),0)
		await physics_frame
		await physics_frame
		var matching := true
		for part in blocker.parts: matching = matching and part.shape.global_transform.is_equal_approx(part.source.global_transform)
		check(matching,"head and open jaw blockers follow the current animated transforms")
		actor.health = 0
		blocker.sync_pose()
		check(blocker.collision_layer==0,"defeated head does not remain a movement obstruction")
		actor.health = actor.data.health
		actor.global_position = Vector3(100+actors.find(actor)*15,0,100)
		await physics_frame
	var target = actors[0]
	target.global_position = Vector3(0,0.01,-16)
	target.rotation.y = PI
	target.CreatureModel.animate(target.mesh,target.data,0,"idle",0,0)
	p.global_position = target.global_position+Vector3(0,0.01,6.5)
	await physics_frame
	await physics_frame
	p.finish_throw(target.global_position+Vector3(0,1.5,1.5))
	check(not overlaps_head(p),"throw arrival sweep cannot place the capsule inside a visible head")
	check(p.global_position.z>target.global_position.z+3.5,"blocked throw arrival remains on the near side of the head")
	print("CREATURE_HEAD_BLOCKING_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
func overlaps_head(p: CharacterBody3D) -> bool:
	var source: CollisionShape3D = p.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = source.shape
	query.transform = source.global_transform
	query.margin = 0
	query.collision_mask = 4
	return not p.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
