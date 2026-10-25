extends SceneTree
## Observe ordinary AI approach -> windup; no forced attack transition.
const Model = preload("res://scripts/creature_model.gd")
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
	world.hunter.set_physics_process(false)
	world.hunter.set_process_unhandled_input(false)
	world.hunter.position = Vector3(200,0,200)
	await physics_frame
	await physics_frame
	var actors := get_nodes_in_group("monsters")
	for actor in actors: actor.set_physics_process(false)
	for actor in actors:
		world.hunter.position = actor.position+Vector3(0,0,-10)
		actor.set_physics_process(true)
		var prior_height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
		var prior_world_y: float = actor.mesh.global_position.y
		var prior_feet := feet(actor)
		var walked := false
		var walking_frames := 0
		var observed := false
		for frame in 900:
			await physics_frame
			var height: float = actor.mesh.position.y-float(actor.mesh.get_meta("ground_offset",0))
			var moving := Vector2(actor.velocity.x,actor.velocity.z).length()>1
			if moving and not walked:
				var current := feet(actor)
				var lift_jump := 0.0
				for name in prior_feet:
					var before: Vector3 = prior_feet[name]
					var after: Vector3 = current[name]
					var old_clearance: float = before.y-actor.global_position.y-actor.foot_ground_height(before)
					var new_clearance: float = after.y-actor.global_position.y-actor.foot_ground_height(after)
					lift_jump = maxf(lift_jump,absf(new_clearance-old_clearance))
				print("APPROACH_START: ",actor.data.id," body=",absf(height-prior_height)," lift=",lift_jump)
				check(absf(height-prior_height)<0.01,"starting pursuit builds the crouch instead of dropping instantly: "+str(actor.data.id))
				check(lift_jump<0.025,"starting pursuit builds the swing instead of lifting instantly: "+str(actor.data.id))
			walked = walked or moving
			if moving:
				walking_frames += 1
				if walking_frames==15:
					var canonical := Model.create(world,actor.data)
					Model.animate(canonical,actor.data,actor.gait,"idle",0,Vector2(actor.velocity.x,actor.velocity.z).length())
					check(absf(height-canonical.position.y)<0.002,"pursuit reaches authored walking load after the start blend: "+str(actor.data.id))
					canonical.queue_free()
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
