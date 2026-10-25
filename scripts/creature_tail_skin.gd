extends RefCounted
const Contact = preload("res://scripts/tail_contact.gd")
static func weights(depth: float, rings: Array[Vector4]) -> Vector3:
	for i in range(rings.size()-1):
		if depth<=rings[i+1].x:
			return Vector3(i,i+1,clampf((depth-rings[i].x)/(rings[i+1].x-rings[i].x),0,1))
	return Vector3(rings.size()-1,rings.size()-1,0)
static func bind(tail: Node3D) -> void:
	var source: MeshInstance3D = tail.get_node("TailSurface")
	var rings := Contact.profile(source.mesh)
	var skeleton := Skeleton3D.new()
	skeleton.name = "TailSkeleton"
	tail.add_child(skeleton)
	var skin := Skin.new()
	for i in rings.size():
		skeleton.add_bone("Tail_%02d" % i)
		var position := Vector3(0,rings[i].y,rings[i].x)
		var rest := Transform3D(Basis.IDENTITY,position)
		if i>0:
			skeleton.set_bone_parent(i,i-1)
			position -= Vector3(0,rings[i-1].y,rings[i-1].x)
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,position))
		skeleton.set_bone_pose_position(i,position)
		skin.add_bind(i,rest.affine_inverse())
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array()
	var influences := PackedFloat32Array()
	for vertex in vertices:
		var weight := weights(vertex.z,rings)
		bones.append_array(PackedInt32Array([int(weight.x),int(weight.y),0,0]))
		influences.append_array(PackedFloat32Array([1-weight.z,weight.z,0,0]))
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = influences
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var rendered := MeshInstance3D.new()
	rendered.name = "SkinnedTail"
	rendered.mesh = mesh
	rendered.skin = skin
	rendered.skeleton = NodePath("..")
	rendered.material_override = source.material_override
	skeleton.add_child(rendered)
	source.hide()
static func animate(tail: Node3D, gait: float, phase: String, clock: float) -> void:
	var skeleton: Skeleton3D = tail.get_node("TailSkeleton")
	for i in range(1,skeleton.get_bone_count()):
		var angle := sin(gait*0.65-i*0.8)*0.07
		if phase=="active": angle += sin(clampf(clock/0.65,0,1)*PI)*0.09
		skeleton.set_bone_pose_rotation(i,Quaternion(Vector3.UP,angle))
	skeleton.force_update_all_bone_transforms()
static func deform(skeleton: Skeleton3D, point: Vector3, rings: Array[Vector4]) -> Vector3:
	var weight := weights(point.z,rings)
	var first := skeleton.get_bone_global_pose(int(weight.x))*skeleton.get_bone_global_rest(int(weight.x)).affine_inverse()*point
	var last := skeleton.get_bone_global_pose(int(weight.y))*skeleton.get_bone_global_rest(int(weight.y)).affine_inverse()*point
	return first.lerp(last,weight.z)
static func top_anchor(mesh: Mesh, depth: float) -> Vector3:
	# Choose an actual rest-surface vertex once; its skin weights remain valid.
	var anchor := Vector3.ZERO
	var closest := INF
	for point: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var distance := absf(point.z-depth)
		if distance<closest-0.00001:
			closest = distance
			anchor = point
		elif absf(distance-closest)<0.00001 and point.y>anchor.y:
			anchor = point
	return anchor

static func contact_profile(tail: Node3D, rings: Array[Vector4]) -> Array[Vector4]:
	var skeleton: Skeleton3D = tail.get_node("TailSkeleton")
	var result: Array[Vector4] = []
	for ring in rings:
		var center := deform(skeleton,Vector3(0,ring.y,ring.x),rings)
		result.append(Vector4(center.z,center.y,ring.z,center.x))
	return result
