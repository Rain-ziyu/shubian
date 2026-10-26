extends RefCounted
## Segmented skeletal skin with blended waist and flexible joint cloth.
static func bind(rig: Dictionary) -> Dictionary:
	var root: Node3D = rig.root
	var sources: Array[MeshInstance3D] = []
	collect(root,rig.weapon,sources)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	var skin := Skin.new()
	skin.add_bind(0,Transform3D.IDENTITY)
	var pelvis := skeleton.add_bone("Pelvis")
	var pelvis_rest: Transform3D = rig.pelvis.transform
	skeleton.set_bone_parent(pelvis,0)
	skeleton.set_bone_rest(pelvis,pelvis_rest)
	skeleton.set_bone_pose_position(pelvis,pelvis_rest.origin)
	skin.add_bind(pelvis,pelvis_rest.affine_inverse())
	var spine := skeleton.add_bone("Spine")
	var spine_rest: Transform3D = rig.torso.transform
	skeleton.set_bone_parent(spine,pelvis)
	skeleton.set_bone_rest(spine,pelvis_rest.affine_inverse()*spine_rest)
	skeleton.set_bone_pose_position(spine,(pelvis_rest.affine_inverse()*spine_rest).origin)
	skin.add_bind(spine,spine_rest.affine_inverse())
	var bindings := []
	var indices := {}
	var rests := {}
	rests[spine] = spine_rest
	rests[pelvis] = pelvis_rest
	var labels := {}
	for side in [-1,1]:
		var prefix := "Left" if side==-1 else "Right"
		var arm: Dictionary = rig.arms[side]
		var leg: Dictionary = rig.legs[side]
		for item in [[arm.upper,"UpperArm"],[arm.lower,"Forearm"],[arm.hand,"Hand"],[leg.thigh,"Thigh"],[leg.shin,"Shin"],[leg.boot,"Foot"]]:
			labels[item[0].get_instance_id()] = prefix+item[1]
	for i in sources.size():
		var source := sources[i]
		var global_rest := relative_transform(source,root)
		var rest := Transform3D(global_rest.basis.orthonormalized(),global_rest.origin)
		var bone := skeleton.add_bone(labels.get(source.get_instance_id(),"Part_%02d" % i))
		skeleton.set_bone_parent(bone,0)
		skeleton.set_bone_rest(bone,rest)
		skeleton.set_bone_pose_position(bone,rest.origin)
		skeleton.set_bone_pose_rotation(bone,rest.basis.get_rotation_quaternion())
		skin.add_bind(bone,rest.affine_inverse())
		var arrays := source.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		var normal_basis := global_rest.basis.inverse().transposed()
		for vertex in vertices.size():
			vertices[vertex] = global_rest*vertices[vertex]
			if vertex<normals.size(): normals[vertex] = (normal_basis*normals[vertex]).normalized()
			bones.append_array(PackedInt32Array([bone,pelvis,0,0]))
			var influence := smoothstep(0.98,1.20,vertices[vertex].y) if source.name=="Undercoat" else 1.0
			weights.append_array(PackedFloat32Array([influence,1-influence,0,0]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var mesh := ArrayMesh.new()
		var shapes: Array[Array] = []
		if source.mesh is ArrayMesh and source.mesh.get_blend_shape_count()>0:
			mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
			var originals: Array[Array] = source.mesh.surface_get_blend_shape_arrays(0)
			for index in originals.size():
				mesh.add_blend_shape(source.mesh.get_blend_shape_name(index))
				var shape: Array = originals[index].duplicate(true)
				var positions: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
				var directions: PackedVector3Array = shape[Mesh.ARRAY_NORMAL]
				for vertex in positions.size():
					positions[vertex] = global_rest*positions[vertex]
					directions[vertex] = (normal_basis*directions[vertex]).normalized()
				shape[Mesh.ARRAY_VERTEX] = positions
				shape[Mesh.ARRAY_NORMAL] = directions
				shapes.append(shape)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
		var rendered := MeshInstance3D.new()
		rendered.name = "SkinPart_%02d" % i
		rendered.set_meta("source_part",str(source.name))
		rendered.mesh = mesh
		rendered.material_override = source.material_override
		rendered.skeleton = NodePath("..")
		skeleton.add_child(rendered)
		rendered.skin = skin
		source.visible = false
		bindings.append({"source":source,"bone":bone,"rendered":rendered})
		indices[source.get_instance_id()] = bone
		rests[bone] = rest
	# The collar stays on the torso while the outer cloth yields to a raised arm.
	# Reuse the anatomical upper-arm bones instead of adding simulated cloth bones.
	for binding in bindings:
		var label := str(binding.source.name)
		if not label.begins_with("RainCape") and not label.begins_with("CapeHem"): continue
		var side := -1 if label.ends_with("-1") else 1
		var upper: int = indices[rig.arms[side].upper.get_instance_id()]
		var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for point in vertices:
			# The raised shoulder crown reaches 1.53 m. Do not pin its outer
			# vertices to the chest at the former, lower neckline.
			var shoulder_follow := lerpf(0.70,1.0,smoothstep(1.35,1.44,point.y))
			var arm_weight := shoulder_follow*smoothstep(0.16,0.29,absf(point.x))*(1-smoothstep(1.51,1.53,point.y))
			bones.append_array(PackedInt32Array([binding.bone,upper,0,0]))
			weights.append_array(PackedFloat32Array([1-arm_weight,arm_weight,0,0]))
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var mesh := ArrayMesh.new()
		var cape_shapes: Array[Array] = binding.rendered.mesh.surface_get_blend_shape_arrays(0)
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for shape_index in binding.rendered.mesh.get_blend_shape_count():
			mesh.add_blend_shape(binding.rendered.mesh.get_blend_shape_name(shape_index))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,cape_shapes)
		binding.rendered.mesh = mesh
	for source in sources:
		if rig.torso.is_ancestor_of(source): parent_bone(skeleton,indices[source.get_instance_id()],spine,rests)
		elif rig.pelvis.is_ancestor_of(source): parent_bone(skeleton,indices[source.get_instance_id()],pelvis,rests)
	# Forearm and hand are true descendants, rather than independent root transforms.
	for side in [-1,1]:
		var arm: Dictionary = rig.arms[side]
		var upper: int = indices[arm.upper.get_instance_id()]
		var lower: int = indices[arm.lower.get_instance_id()]
		var hand: int = indices[arm.hand.get_instance_id()]
		for pair in [[upper,spine],[lower,upper],[hand,lower]]: parent_bone(skeleton,pair[0],pair[1],rests)
		parent_bone(skeleton,indices[rig.shoulders[side].get_instance_id()],upper,rests)
		var leg: Dictionary = rig.legs[side]
		var thigh: int = indices[leg.thigh.get_instance_id()]
		var shin: int = indices[leg.shin.get_instance_id()]
		var boot: int = indices[leg.boot.get_instance_id()]
		for pair in [[thigh,pelvis],[shin,thigh],[boot,shin]]: parent_bone(skeleton,pair[0],pair[1],rests)
		# The shaft follows the calf while the sole remains rigid on the foot.
		# Blend only above the instep; support-plane and toe geometry stay intact.
		for binding in bindings:
			if binding.source!=leg.boot: continue
			var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
			var originals: PackedVector3Array = leg.boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			for point in originals:
				var shin_weight := smoothstep(0.43,1.13,point.y)
				bones.append_array(PackedInt32Array([boot,shin,0,0]))
				weights.append_array(PackedFloat32Array([1-shin_weight,shin_weight,0,0]))
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			binding.rendered.mesh = mesh
	for joint in rig.get("soft_joints",[]):
		for binding in bindings:
			if binding.source!=joint.source: continue
			var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for vertex in positions.size():
				var lower_weight := smoothstep(0,1,uv[vertex].y)
				bones.append_array(PackedInt32Array([indices[joint.upper.get_instance_id()],indices[joint.lower.get_instance_id()],0,0]))
				weights.append_array(PackedFloat32Array([1-lower_weight,lower_weight,0,0]))
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			binding.rendered.mesh = mesh
	# Some authored sources (shoulder armor) precede their later-created arm
	# parent. Global-pose setters must run parent-first, independent of mesh order.
	var depths := {}
	for binding in bindings:
		var depth := 0
		var parent := skeleton.get_bone_parent(int(binding.bone))
		while parent>=0:
			depth += 1
			parent = skeleton.get_bone_parent(parent)
		depths[binding.bone] = depth
	var pose_order := bindings.duplicate()
	pose_order.sort_custom(func(a: Dictionary, b: Dictionary): return int(depths[a.bone])<int(depths[b.bone]))
	return {"skeleton":skeleton,"skin":skin,"bindings":bindings,"pose_order":pose_order,"spine":spine,"pelvis":pelvis}

static func parent_bone(skeleton: Skeleton3D, child: int, parent: int, rests: Dictionary) -> void:
	var local: Transform3D = rests[parent].affine_inverse()*rests[child]
	skeleton.set_bone_parent(child,parent)
	skeleton.set_bone_rest(child,local)
	skeleton.set_bone_pose_position(child,local.origin)
	skeleton.set_bone_pose_rotation(child,local.basis.get_rotation_quaternion())

static func relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent!=root:
		transform = parent.transform*transform
		parent = parent.get_parent()
	return transform

static func collect(node: Node, excluded: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child==excluded: continue
		if child is MeshInstance3D: result.append(child)
		collect(child,excluded,result)

static func update(rig: Dictionary) -> void:
	if not rig.has("skinning"): return
	var data: Dictionary = rig.skinning
	var skeleton: Skeleton3D = data.skeleton
	skeleton.set_bone_global_pose(data.pelvis,rig.pelvis.transform)
	skeleton.set_bone_global_pose(data.spine,rig.torso.transform)
	for binding in data.pose_order:
		var pose := relative_transform(binding.source,rig.root)
		pose.basis = pose.basis.orthonormalized()
		skeleton.set_bone_global_pose(binding.bone,pose)
		for shape in binding.source.get_blend_shape_count():
			binding.rendered.set_blend_shape_value(shape,binding.source.get_blend_shape_value(shape))
