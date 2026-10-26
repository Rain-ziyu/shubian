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
	var stage := Node3D.new()
	root.add_child(stage)
	var p = load("res://scripts/player.gd").new()
	stage.add_child(p)
	p.set_physics_process(false)
	await process_frame
	var skeleton: Skeleton3D = p.rig.skinning.skeleton
	for side in [-1,1]:
		var plate: MeshInstance3D = p.rig.shoulders[side]
		var points: PackedVector3Array = plate.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var edges := {}
		var volume := 0.0
		for triangle in range(0,points.size(),3):
			volume += points[triangle].dot(points[triangle+1].cross(points[triangle+2]))/6
			for edge in 3:
				var a := str(Vector3i((points[triangle+edge]*1000000).round()))
				var b := str(Vector3i((points[triangle+(edge+1)%3]*1000000).round()))
				var key := a+"|"+b if a<b else b+"|"+a
				edges[key] = int(edges.get(key,0))+1
		var closed := true
		for count in edges.values(): closed = closed and count==2
		check(closed,"shoulder shell has a closed rim and inner surface")
		check(volume< -0.000001,"shoulder shell encloses outward-facing physical thickness")
		var binding: Dictionary = {}
		for candidate in p.rig.skinning.bindings:
			if candidate.source==plate: binding = candidate
		var parent_name := "LeftUpperArm" if side==-1 else "RightUpperArm"
		check(skeleton.get_bone_parent(binding.bone)==skeleton.find_bone(parent_name),"shoulder armor belongs to the upper-arm skeleton chain")
		var worst_anchor := 0.0
		var worst_radius := 0.0
		var worst_step := 0.0
		var worst_pose := ""
		var fastener: MeshInstance3D = p.rig.fasteners[side]
		var fastener_binding := {}
		for candidate in p.rig.skinning.bindings:
			if candidate.source==fastener: fastener_binding = candidate
		var fastener_drift := 0.0
		var armor_rotation_error := 0.0
		for action in ["heavy","guard","throw","plant","finisher"]:
			p.combat.set_action(action)
			p.combat.drawn = true
			var frames := ceili(float(p.Combat.MOVES[action].duration)*60)
			var previous := Quaternion.IDENTITY
			for frame in frames+1:
				p.combat.elapsed = float(p.Combat.MOVES[action].duration)*frame/frames
				p.animate(0,0)
				var rotation := plate.basis.get_rotation_quaternion()
				if frame>0 and previous.angle_to(rotation)>worst_step:
					worst_step = previous.angle_to(rotation)
					worst_pose = action+" "+str(p.combat.elapsed)
				previous = rotation
				var shoulder: Vector3 = p.rig.arms[side].shoulder.position
				worst_anchor = maxf(worst_anchor,skeleton.get_bone_global_pose(binding.bone).origin.distance_to(shoulder))
				var deformation: Transform3D = skeleton.get_bone_global_pose(binding.bone)*p.rig.skinning.skin.get_bind_pose(binding.bone)
				var rendered_plate := skeleton.get_bone_global_pose(binding.bone)
				armor_rotation_error = maxf(armor_rotation_error,rendered_plate.basis.get_rotation_quaternion().angle_to(plate.basis.get_rotation_quaternion()))
				var expected_fastener: Transform3D = rendered_plate*fastener.get_meta("shoulder_bind")
				fastener_drift = maxf(fastener_drift,skeleton.get_bone_global_pose(fastener_binding.bone).origin.distance_to(expected_fastener.origin))
				for vertex in binding.rendered.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					worst_radius = maxf(worst_radius,(deformation*vertex).distance_to(shoulder))
		check(worst_anchor<0.002,"rendered shoulder pivot stays attached during raised and rotated arm poses")
		check(worst_radius<0.20,"shoulder armor remains compact around its joint instead of orbiting the torso")
		# The 0.18 s guard turn is deliberately fast; reject pole-switch jumps,
		# rather than imposing a slow armor turn on that authored action.
		check(worst_step<0.6,"continuous poses avoid sudden shoulder-armor roll flips")
		check(fastener_drift<0.002,"rendered fastening strap stays on the articulated shoulder armor")
		check(armor_rotation_error<0.002,"rendered armor rotation matches the authored source pose")
		print("SHOULDER_BINDING_DEVIATION: ",side," rotation=",armor_rotation_error," fastener=",fastener_drift)
		print("SHOULDER_ROTATION_STEP: ",side," ",worst_step," ",worst_pose)
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	stage.add_child(saved)
	var saved_skeleton: Skeleton3D = saved.get_node("Skeleton3D")
	var preview: AnimationPlayer = saved.get_node("AnimationPreview")
	for side in [-1,1]:
		var plate_bone := -1
		var strap_bone := -1
		for part in saved_skeleton.get_children():
			if not part is MeshInstance3D: continue
			var label := str(part.get_meta("source_part",""))
			if label=="ShoulderPlate"+str(side): plate_bone = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES][0]
			if label=="ShoulderFastener"+str(side): strap_bone = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES][0]
		var drift := INF
		var drift_case := ""
		if plate_bone>=0 and strap_bone>=0:
			drift = 0.0
			var bind: Transform3D = saved.get_node("Torso/ShoulderFastener"+str(side)).get_meta("shoulder_bind")
			for action in ["heavy","guard","throw","plant","finisher"]:
				for time in [0.2,0.4,0.6]:
					preview.play(action)
					preview.seek(time,true)
					var expected: Vector3 = (saved_skeleton.get_bone_global_pose(plate_bone)*bind).origin
					var actual: Vector3 = saved_skeleton.get_bone_global_pose(strap_bone).origin
					var error := actual.distance_to(expected)
					if error>drift:
						drift = error
						drift_case = "%s %.2f actual %s expected %s" % [action,time,actual,expected]
		check(drift<0.002,"saved animation keeps the fastening strap attached to its armor")
		print("SAVED_SHOULDER_FASTENER_DRIFT: ",side," ",drift," ",drift_case)
	print("SHOULDER_RIG_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
