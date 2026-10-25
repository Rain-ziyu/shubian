extends SceneTree
## Observe ordinary AI approach -> windup; no forced attack transition.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func feet(actor: Node3D) -> Dictionary:
	var result := {}
	for name in ["Hind-1","Hind1","Front-1","Front1"]:
		var leg := actor.mesh.get_node_or_null(name) as Node3D
		if leg==null: continue
		var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
		result[name] = leg.to_global(skeleton.get_bone_global_pose(2).origin)
	return result
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.hunter.set_physics_process(false)
	world.hunter.set_process_unhandled_input(false)
	var actors := get_nodes_in_group("monsters")
	for actor in actors: actor.set_physics_process(false)
	for actor in actors:
		world.hunter.position = actor.position+Vector3(0,0,-10)
		actor.set_physics_process(true)
		var prior_height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
		var prior_world_y: float = actor.mesh.global_position.y
		var prior_feet := feet(actor)
		var walked := false
		var observed := false
		for frame in 900:
			await physics_frame
			var height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
			walked = walked or Vector2(actor.velocity.x,actor.velocity.z).length()>1
			if actor.phase=="windup":
				observed = true
				var current := feet(actor)
				var displacement := 0.0
				for name in prior_feet: displacement = maxf(displacement,prior_feet[name].distance_to(current[name]))
				var world_jump: float = absf(actor.mesh.global_position.y-prior_world_y)
				print("APPROACH_HANDOFF: ",actor.data.id," body=",absf(height-prior_height)," world=",world_jump," foot=",displacement)
				check(walked,"ordinary AI walked before preparing: "+str(actor.data.id))
				check(absf(height-prior_height)<0.01,"approach does not pop body height at windup entry: "+str(actor.data.id))
				check(world_jump<0.01,"terrain adjustment also preserves visible world body height: "+str(actor.data.id))
				check(displacement<0.015,"approach carries actual ankle positions into preparation: "+str(actor.data.id))
				for settle in 18: await physics_frame
				check(actor.phase=="windup" and is_equal_approx(actor.clock,0.30),"pose handoff does not pause or advance the attack clock: "+str(actor.data.id))
				break
			prior_height = height
			prior_world_y = actor.mesh.global_position.y
			prior_feet = feet(actor)
		check(observed,"normal AI reaches attack preparation: "+str(actor.data.id))
		actor.set_physics_process(false)
	print("CREATURE_APPROACH_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
