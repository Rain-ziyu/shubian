extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func sole(leg: Node3D) -> Vector3:
	var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
	var foot: MeshInstance3D = leg.get_node("Foot")
	return leg.to_global(skeleton.get_bone_global_pose(2)*skeleton.get_bone_global_rest(2).affine_inverse()*(foot.transform*Vector3(0,-0.5,0)))
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in data.species:
		var actor := Node3D.new()
		root.add_child(actor)
		var model := Model.create(actor,species)
		var legs: Array[Node3D] = []
		for name in ["Hind-1","Hind1","Front-1","Front1"]:
			var leg := model.get_node_or_null(name) as Node3D
			if leg: legs.append(leg)
		var ground := func(point: Vector3) -> float: return point.z*0.12-actor.position.y
		var normal := func(_point: Vector3) -> Vector3: return Vector3(0,1,-0.12).normalized()
		var gait := 0.0
		var samples := 0
		var releases := 0
		var maximum_drift := 0.0
		var prior := {}
		for frame in 100:
			actor.position.z -= 0.04
			actor.position.y = actor.position.z*0.12
			gait += 0.04*Model.GAIT_PER_METER
			Model.animate(model,species,gait,"idle",0,2.4,ground,normal)
			for leg in legs:
				var id := leg.get_instance_id()
				if leg.has_meta("plant_world"):
					var anchor: Vector3 = leg.get_meta("plant_world")
					var point := sole(leg)
					maximum_drift = maxf(maximum_drift,point.distance_to(anchor))
					samples += 1
					prior[id] = true
				elif prior.get(id,false):
					releases += 1
					prior[id] = false
		check(samples>60 and releases>=4,"walking alternates planted and swing phases: "+str(species.id))
		check(maximum_drift<0.003,"moving body preserves planted world foot position: "+str(species.id))
		Model.animate(model,species,0,"windup",0.3,0,ground,normal)
		var released := true
		for leg in legs: released = released and not leg.has_meta("plant_world")
		check(released,"attack preparation releases locomotion anchors")
		Model.animate(model,species,0,"idle",0,2.4,ground,normal)
		var leg: Node3D = model.get_node("Hind-1")
		var old: Vector3 = leg.get_meta("plant_world")
		actor.rotation.y = 1.0
		Model.animate(model,species,0,"idle",0,2.4,ground,normal)
		var forward: Vector3 = leg.get_meta("plant_forward")
		check(forward.dot(leg.global_basis.z.normalized())>0.999,"sharp turn refreshes old anchor direction")
		actor.position.z -= 10
		actor.position.y = actor.position.z*0.12
		Model.animate(model,species,0,"idle",0,2.4,ground,normal)
		check(leg.get_meta("plant_world").distance_to(old)>5,"large reposition does not stretch a stale anchor")
		Model.animate(model,species,0,"idle",0,2.4)
		check(not leg.has_meta("plant_world"),"missing ground releases world lock")
		# Measure the rendered ankle rather than repeating the authored sine formula.
		actor.transform = Transform3D.IDENTITY
		var swing_leg: Node3D = model.get_node("Hind1")
		Model.animate(model,species,-PI/3,"idle",0,2.4)
		var swing_start := sole(swing_leg)
		Model.animate(model,species,PI/3,"idle",0,2.4)
		var swing_end := sole(swing_leg)
		print("FORWARD_STRIDE: ",species.id," swing_z=",swing_end.z-swing_start.z)
		check(swing_end.z<swing_start.z-0.1,"lifted foot advances toward the creature facing direction: "+str(species.id))
		Model.animate(model,species,PI/2,"idle",0,2.4)
		var touchdown := sole(swing_leg)
		Model.animate(model,species,PI*1.5,"idle",0,2.4)
		var liftoff := sole(swing_leg)
		check(touchdown.z<liftoff.z-0.1,"foot lands ahead and finishes support behind the hip: "+str(species.id))
		actor.queue_free()
	await process_frame
	print("CREATURE_FOOT_LOCK_CHECKS: ",checks," FAILURES: ",failures)
	quit(1 if failures else 0)
