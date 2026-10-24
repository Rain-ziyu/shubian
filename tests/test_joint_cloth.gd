extends SceneTree
const Player = preload("res://scripts/player.gd")
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
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	await process_frame
	var skeleton: Skeleton3D = p.rig.skinning.skeleton
	check(p.rig.soft_joints.size()==4,"both elbows and knees have continuous joint cloth")
	for binding in p.rig.skinning.bindings:
		if not str(binding.source.name).begins_with("JointCloth"): continue
		var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var blended := 0
		var valid := true
		var weight_error := 0.0
		for i in positions.size():
			# ArrayMesh stores these weights at 16-bit precision; allow one quantization step.
			valid = valid and bones[i*4]!=bones[i*4+1] and absf(weights[i*4]+weights[i*4+1]-1)<1.1/65535
			weight_error = maxf(weight_error,absf(weights[i*4]+weights[i*4+1]-1))
			if weights[i*4]>0.01 and weights[i*4+1]>0.01: blended += 1
		check(valid and blended>20,"joint cloth has normalized weights blending its two anatomical bones")
		print("JOINT_WEIGHT: ",binding.source.name," BLENDED=",blended," ERROR=",weight_error," BONES=",bones[0],",",bones[1])
	for action in ["heavy","plant","finisher","guard"]:
		p.combat.set_action(action)
		p.combat.elapsed = 0.95 if action=="finisher" else 0.3
		p.animate(0,0)
		for binding in p.rig.skinning.bindings:
			if not str(binding.source.name).begins_with("JointCloth"): continue
			var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var finite := true
			for i in positions.size():
				var point := Vector3.ZERO
				for slot in 2:
					var bone := bones[i*4+slot]
					point += (skeleton.get_bone_global_pose(bone)*p.rig.skinning.skin.get_bind_pose(bone)*positions[i])*weights[i*4+slot]
				finite = finite and point.is_finite() and point.distance_to(skeleton.get_bone_global_pose(bones[i*4]).origin)<0.8
			check(finite,"deformed joint cloth stays finite and near its limb through "+action)
	print("JOINT_CLOTH_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
