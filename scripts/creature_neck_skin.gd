extends RefCounted
## A torso-to-neck transition on the existing body surface, not an extra collar.
static func bind(body: MeshInstance3D, neck: Node3D, size: float, cut := -0.28, center_height := 0.14) -> void:
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Bake the authored narrow torso scale before skinning. Otherwise a rotating
	# neck relative to a nonuniformly scaled torso introduces a sheared bone frame.
	if not body.scale.is_equal_approx(Vector3.ONE):
		var scale_basis := Basis.from_scale(body.scale)
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			vertices[index] = scale_basis*vertices[index]
			source_normals[index] = (scale_basis.inverse().transposed()*source_normals[index]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = source_normals
		body.scale = Vector3.ONE
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var original_uv := uv.duplicate()
	var transition := PackedVector2Array()
	transition.resize(vertices.size())
	var front := INF
	for point in vertices: front = minf(front,point.z)
	var rows := {}
	for point in vertices:
		var key := roundi(point.z/size*1000000)
		var row: Vector3 = rows.get(key,Vector3(0,INF,-INF))
		rows[key] = Vector3(maxf(row.x,absf(point.x)),minf(row.y,point.y),maxf(row.z,point.y))
	var original_front: Vector3 = rows[roundi(front/size*1000000)]
	var head: MeshInstance3D = neck.get_node("HeadSurface")
	var surface := head.mesh.generate_triangle_mesh()
	var head_arrays: Array = head.mesh.surface_get_arrays(0)
	var boundary := {}
	for index in head_arrays[Mesh.ARRAY_VERTEX].size():
		var point: Vector3 = head_arrays[Mesh.ARRAY_VERTEX][index]
		if absf(point.z-size*cut)>0.00001: continue
		boundary[point.snapped(Vector3.ONE*0.00001)] = {"point":point,"normal":head_arrays[Mesh.ARRAY_NORMAL][index],"color":head_arrays[Mesh.ARRAY_COLOR][index]}
	assert(not boundary.is_empty(),"Neck seam must coincide with an authored skull ring")
	var seam_normals := {}
	var head_center := Vector3(0,size*center_height,size*cut)
	var head_to_body := body.transform.affine_inverse()*neck.transform*head.transform
	var seam_z := (head_to_body*head_center).z
	for index in vertices.size():
		var point := vertices[index]
		if point.z>=-size*0.44: continue
		var row: Vector3 = rows[roundi(point.z/size*1000000)]
		var center_y := (row.y+row.z)*0.5
		var radial := Vector2(point.x/maxf(row.x,0.001),(point.y-center_y)/maxf((row.z-row.y)*0.5,0.001))
		var direction := Vector3(radial.x,radial.y,0).normalized()
		var old_front := Vector3(direction.x*original_front.x,(original_front.y+original_front.z)*0.5+direction.y*(original_front.z-original_front.y)*0.5,front)
		var t := clampf((point.z-front)/(-size*0.44-front),0,1)
		var weight := pow(1-t,2)
		transition[index] = Vector2(weight,0)
		if radial.length()<0.01:
			vertices[index] += (head_to_body*head_center-old_front)*weight
			continue
		var hit := surface.intersect_segment(head_center+direction*size*2,head_center)
		assert(not hit.is_empty(),"Neck transition requires a closed head section")
		vertices[index] += (head_to_body*Vector3(hit.position)-old_front)*weight
		var nearest: Dictionary = {}
		var second: Dictionary = {}
		var distance := INF
		var second_distance := INF
		for sample: Dictionary in boundary.values():
			var candidate: float = Vector3(hit.position).distance_to(sample.point)
			if candidate<distance:
				second = nearest
				second_distance = distance
				nearest = sample
				distance = candidate
			elif candidate<second_distance:
				second = sample
				second_distance = candidate
		var fraction := distance/maxf(distance+second_distance,0.000001)
		var color: Color = Color(nearest.color).lerp(second.color,fraction)
		var normal: Vector3 = Vector3(nearest.normal).lerp(second.normal,fraction).normalized()
		colors[index] = colors[index].lerp(color,weight)
		if t<0.0001: seam_normals[vertices[index].snapped(Vector3.ONE*0.00001)] = (head_to_body.basis.inverse().transposed()*normal).normalized()
	# Continue the head's longitudinal texture scale through the chest instead
	# of folding UV.y backward into the old torso chart at the neck.
	for index in vertices.size():
		transition[index].y = 1-smoothstep(0.90,0.98,uv[index].y)
		uv[index].y = ((head_to_body.affine_inverse()*vertices[index]).z/size+0.715)/0.835
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = transition
	var fitted := ArrayMesh.new()
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool := SurfaceTool.new()
	tool.create_from(fitted,0)
	tool.generate_normals()
	arrays = tool.commit().surface_get_arrays(0)
	vertices = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in vertices.size():
		var key := vertices[index].snapped(Vector3.ONE*0.00001)
		if seam_normals.has(key): normals[index] = seam_normals[key]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var fitted_body := ArrayMesh.new()
	var source_arrays := arrays.duplicate()
	# Anatomical source coordinates retain their original authoring chart.
	# The rendered skin below uses the continuous head/chest texture chart.
	source_arrays[Mesh.ARRAY_TEX_UV] = original_uv
	fitted_body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source_arrays)
	body.mesh = fitted_body
	# Keep source geometry available to anatomical queries; render an open seam
	# at the exact skull ring instead of two intersecting capped surfaces.
	arrays = selected_triangles(arrays,func(points: Array) -> bool: return not (absf(points[0].z-seam_z)<0.00001 and absf(points[1].z-points[0].z)<0.00001 and absf(points[2].z-points[0].z)<0.00001))
	vertices = arrays[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for point in vertices:
		# Concentrate rotation in the neck and taper its influence before the
		# broad shoulder. A linear falloff shears the wide chest during recoil.
		var weight := pow(clampf((-size*0.27-point.z)/(-size*0.27-seam_z),0,1),1.2)
		bones.append_array(PackedInt32Array([0,1,0,0]))
		weights.append_array(PackedFloat32Array([1-weight,weight,0,0]))
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var skeleton := Skeleton3D.new()
	skeleton.name = "NeckSkeleton"
	body.add_child(skeleton)
	var skin := Skin.new()
	var neck_rest := body.transform.affine_inverse()*neck.transform
	for index in 2:
		skeleton.add_bone("Torso" if index==0 else "Neck")
		var rest := Transform3D.IDENTITY if index==0 else neck_rest
		skeleton.set_bone_rest(index,rest)
		skeleton.set_bone_pose_position(index,rest.origin)
		skeleton.set_bone_pose_rotation(index,rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index,rest.basis.get_scale())
		skin.add_bind(index,rest.affine_inverse())
	var torso := MeshInstance3D.new()
	torso.name = "Skin_BodySurface"
	torso.mesh = mesh
	torso.skin = skin
	torso.skeleton = NodePath("..")
	skeleton.add_child(torso)
	copy_material(body,torso)
	torso.set_instance_shader_parameter("neck_transition",1.0)
	body.layers = 0
	var skull := MeshInstance3D.new()
	skull.name = "Skin_HeadSurface"
	skull.mesh = ArrayMesh.new()
	skull.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,selected_triangles(head.mesh.surface_get_arrays(0),func(points: Array) -> bool: return maxf(points[0].z,maxf(points[1].z,points[2].z))<=size*cut+0.00001))
	head.add_child(skull)
	copy_material(head,skull)
	head.layers = 0
	skeleton.force_update_all_bone_transforms()

static func copy_material(source: MeshInstance3D, target: MeshInstance3D) -> void:
	target.material_override = source.material_override
	for parameter in ["ventral_weight","fine_scale_weight"]:
		target.set_instance_shader_parameter(parameter,source.get_instance_shader_parameter(parameter))

static func selected_triangles(arrays: Array, keep: Callable) -> Array:
	assert(arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty(),"Neck source must contain unindexed triangles")
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	result[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	result[Mesh.ARRAY_COLOR] = PackedColorArray()
	result[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	var attributes := [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]
	if arrays[Mesh.ARRAY_TEX_UV2]!=null:
		result[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
		attributes.append(Mesh.ARRAY_TEX_UV2)
	for triangle in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
		var points := [arrays[Mesh.ARRAY_VERTEX][triangle],arrays[Mesh.ARRAY_VERTEX][triangle+1],arrays[Mesh.ARRAY_VERTEX][triangle+2]]
		if not keep.call(points): continue
		for index in range(triangle,triangle+3):
			for attribute in attributes: result[attribute].append(arrays[attribute][index])
	return result

static func animate(root: Node3D) -> void:
	var body: MeshInstance3D = root.get_node("BodySurface")
	var skeleton := body.get_node_or_null("NeckSkeleton") as Skeleton3D
	if skeleton==null: return
	var neck: Node3D = root.get_node("Neck")
	var pose := body.transform.affine_inverse()*neck.transform
	skeleton.set_bone_pose_position(1,pose.origin)
	skeleton.set_bone_pose_rotation(1,pose.basis.get_rotation_quaternion())
	skeleton.set_bone_pose_scale(1,pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
