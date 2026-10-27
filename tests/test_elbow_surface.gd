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
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var skeleton: Skeleton3D = p.rig.skinning.skeleton
	for side in [-1,1]:
		var source: MeshInstance3D = p.rig.arms[side].upper
		var roles: PackedVector2Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		var blended := 0
		var seated := 0
		for role in roles:
			if role.x>0 and role.x<1: blended += 1
			if role.x==1: seated += 1
		check(blended>100 and seated>100,"upper-arm surface has a continuous blended elbow and forearm-bound end")
		var arrays: Array = source.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var shared := {}
		var rings := {}
		var smooth := true
		for index in vertices.size():
			if roles[index].x<=0: continue
			var key := Vector3i((vertices[index]*1000000).round())
			if shared.has(key): smooth = smooth and normals[index].distance_to(shared[key])<0.005
			else: shared[key] = normals[index]
			var row := roundi(uv[index].y*1000000)
			if not rings.has(row): rings[row] = []
			rings[row].append(source.transform*vertices[index])
		check(smooth,"shared elbow vertices keep matching normals across the UV seam")
		var rounded := true
		for ring: Array in rings.values():
			var center := Vector3.ZERO
			for point: Vector3 in ring: center += point
			center /= ring.size()
			for point: Vector3 in ring:
				var radius := point.distance_to(center)
				rounded = rounded and radius>0.030 and radius<0.070
		check(rounded,"bind elbow sections retain a rounded cross section without pinching")

	for binding in p.rig.skinning.bindings:
		var label := str(binding.source.name)
		if label.begins_with("Elbow") or label.begins_with("JointClothElbow"):
			check(not binding.rendered.visible,"former joint filler is replaced by continuous arm skin: "+label)
	for action in ["idle","light","heavy","pull","turn","guard","reply","flash","throw","fourfold","spin","plant","wait","counter_window","finisher","dodge","hurt","rising","advance_thrust","cleave","evade_thrust"]:
		p.combat.set_action(action)
		p.combat.drawn = true
		for fraction in [0.1,0.45,0.8]:
			p.combat.elapsed = float(p.Combat.MOVES.get(action,{"duration":1}).duration)*fraction
			p.animate(0,0)
			for side in [-1,1]:
				var arm: Dictionary = p.rig.arms[side]
				for binding in p.rig.skinning.bindings:
					if binding.source!=arm.upper: continue
					var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var roles: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
					var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
					var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
					var within := true
					var finite := true
					for index in vertices.size():
						var point := Vector3.ZERO
						for slot in 2:
							var bone := bones[index*4+slot]
							point += (skeleton.get_bone_global_pose(bone)*p.rig.skinning.skin.get_bind_pose(bone)*vertices[index])*weights[index*4+slot]
						finite = finite and point.is_finite()
						if roles[index].x<0.999: continue
						var local: Vector3 = arm.lower.transform.affine_inverse()*point
						within = within and local.y> -0.36 and local.y< -0.25 and Vector2(local.x,local.z).length()<0.047
					check(finite and within,"deformed skin end stays seated inside cuff: "+action+"/"+str(side)+"/"+str(fraction))
	var saved: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	stage.add_child(saved)
	for side in [-1,1]:
		var source: MeshInstance3D = p.rig.arms[side].upper
		var stored: MeshInstance3D = saved.get_node("UpperArmSurface"+str(side))
		check(source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==stored.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"saved continuous elbow matches source geometry")
	for node in saved.get_node("Skeleton3D").get_children():
		if not node is MeshInstance3D: continue
		var label := str(node.get_meta("source_part",""))
		if label.begins_with("Elbow") or label.begins_with("JointClothElbow"): check(not node.visible,"saved filler stays inactive: "+label)
	print("ELBOW_SURFACE_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
