extends SceneTree
## Sample the actual skinned cloth, not the hidden rigid source mesh.
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func surface(part: MeshInstance3D, skeleton: Skeleton3D) -> TriangleMesh:
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var poses: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): poses.append(skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(bone))
	for i in points.size():
		var point := Vector3.ZERO
		for slot in 4: point += (poses[bones[i*4+slot]]*points[i])*weights[i*4+slot]
		points[i] = skeleton.to_global(point)
	var triangle_arrays := []
	triangle_arrays.resize(Mesh.ARRAY_MAX)
	triangle_arrays[Mesh.ARRAY_VERTEX] = points
	triangle_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle_arrays)
	return mesh.generate_triangle_mesh()
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := preload("res://scripts/player.gd").new()
	p.set_physics_process(false)
	stage.add_child(p)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	p.yaw = 0
	p.pitch = -0.25
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.combat.drawn = true
	p.combat.set_action("reply")
	var skeleton: Skeleton3D = p.rig.skinning.skeleton
	var crossings := {}
	var lengths_valid := true
	var longest := 0.0
	var longest_time := 0.0
	for frame in 100:
		p.combat.elapsed = 0.82*frame/99
		p.animate(0,0)
		for side in [-1,1]:
			lengths_valid = lengths_valid and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
			if p.rig.arms[side].upper.scale.y>longest:
				longest = p.rig.arms[side].upper.scale.y
				longest_time = p.combat.elapsed
		for part in skeleton.get_children():
			if not part is MeshInstance3D: continue
			var label: String = part.get_meta("source_part","")
			if label!="Undercoat" and not label.begins_with("RainCape"): continue
			var triangles := surface(part,skeleton)
			for ray in 9:
				var offset := Vector3.ZERO if ray==0 else Vector3(cos((ray-1)*TAU/8)*0.024,0,sin((ray-1)*TAU/8)*0.024)
				if not triangles.intersect_segment(p.rig.weapon.to_global(Vector3(0,-0.90,0)+offset),p.rig.weapon.to_global(Vector3(0,0.82,0)+offset)).is_empty():
					if not crossings.has(label): crossings[label] = []
					crossings[label].append(snappedf(p.combat.elapsed,0.001))
					break
	print("COUNTER_CLOTH_CROSSINGS: ",JSON.stringify(crossings))
	print("COUNTER_CLOTH_ARM: longest=",longest," time=",longest_time)
	check(crossings.is_empty(),"100 neutral-aim counter poses clear actual skinned cape and undercoat along nine shaft rays")
	check(lengths_valid,"counter route keeps both anatomical arm lengths")
	print("COUNTER_CLOTH_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
