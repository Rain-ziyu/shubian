extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
const Support = preload("res://scripts/creature_turn_support.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func feet(model: Node3D) -> Dictionary:
	var result := {}
	for name in ["Hind-1","Hind1","Front-1","Front1"]:
		var leg := model.get_node_or_null(name) as Node3D
		if leg:
			var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
			result[name] = leg.to_global(skeleton.get_bone_global_pose(2).origin)
	return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in data.species:
		for direction in [-1,1]:
			for slope in [Vector2.ZERO,Vector2(0.15,0),Vector2(0,-0.15)]:
				var actor := Node3D.new()
				root.add_child(actor)
				var model := Model.create(actor,species)
				var ground := func(point: Vector3) -> float: return point.x*slope.x+point.z*slope.y
				var normal := func(_point: Vector3) -> Vector3: return Vector3(-slope.x,1,-slope.y).normalized()
				Model.animate(model,species,0,"windup",0.2,0,ground,normal,false,{},1.0/120)
				var initial := feet(model)
				var previous := initial.duplicate()
				var previous_group := -1
				var drift := 0.0
				var lift := 0.0
				var peak := 0.0
				var planted_samples := 0
				var penetration := 0.0
				for frame in range(1,ceili((float(species.windup)-0.2)*120)+1):
					var clock := minf(float(species.windup),0.2+frame/120.0)
					actor.rotation.y = direction*0.65*minf(frame/36.0,1)
					Model.animate(model,species,0,"windup",clock,0,ground,normal,false,{},1.0/120)
					var current := feet(model)
					var state: Dictionary = model.get_meta("turn_support")
					var active: int = state.active_group
					for name in current:
						var point: Vector3 = current[name]
						var before: Vector3 = previous[name]
						var start: Vector3 = initial[name]
						var leg: Node3D = model.get_node(name)
						var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
						var foot: MeshInstance3D = leg.get_node("Foot")
						var sole: Vector3 = leg.to_global(skeleton.get_bone_global_pose(2)*skeleton.get_bone_global_rest(2).affine_inverse()*(foot.transform*Vector3(0,-0.5,0)))
						penetration = maxf(penetration,ground.call(sole)-sole.y)
						var group := Support.group_for(leg)
						peak = maxf(peak,point.distance_to(before))
						lift = maxf(lift,point.y-start.y)
						if group!=active and group!=previous_group:
							drift = maxf(drift,point.distance_to(before))
							planted_samples += 1
					previous=current
					previous_group=active
				print("CREATURE_TURN_SUPPORT: ",species.id," direction=",direction," slope=",slope," penetration=",penetration," planted_step=",drift," lift=",lift," max_step=",peak)
				check(planted_samples>40 and drift<0.003,"Turning holds the actual supporting ankles in world space: "+str(species.id))
				check(lift>float(species.size)*0.02,"Turning visibly lifts a replacement foot: "+str(species.id))
				check(peak<0.12,"Replacement feet move without a single-frame teleport: "+str(species.id))
				check(absf(angle_difference(actor.rotation.y,direction*0.65))<0.0001,"Foot presentation preserves authoritative actor heading")
				check(penetration<0.003,"Actual foot soles remain above the slope throughout replacement steps")
				actor.queue_free()
				# Release each native fixture before allocating the next species.
				await process_frame
	await process_frame
	print("CREATURE_TURN_SUPPORT_CHECKS: ",checks," FAILURES: ",failures)
	quit(1 if failures else 0)
