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
				for vertex in binding.rendered.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					worst_radius = maxf(worst_radius,(deformation*vertex).distance_to(shoulder))
		check(worst_anchor<0.002,"rendered shoulder pivot stays attached during raised and rotated arm poses")
		check(worst_radius<0.20,"shoulder armor remains compact around its joint instead of orbiting the torso")
		# The 0.18 s guard turn is deliberately fast; reject pole-switch jumps,
		# rather than imposing a slow armor turn on that authored action.
		check(worst_step<0.6,"continuous poses avoid sudden shoulder-armor roll flips")
		print("SHOULDER_ROTATION_STEP: ",side," ",worst_step," ",worst_pose)
	print("SHOULDER_RIG_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
