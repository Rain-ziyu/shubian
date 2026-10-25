extends RefCounted
static func shape_attachment(surface: MeshInstance3D, size: float, side: int) -> void:
	var arrays: Array = surface.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertex_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Sweep the upper thigh into the flank rather than ending in a separate dome.
	for i in vertices.size():
		var point := surface.transform*vertices[i]
		var t := clampf((point.y+size*0.10)/(size*0.29),0,1)
		var normal := surface.basis*vertex_normals[i]
		normal.y += side*size*0.20*6*t*(1-t)/(size*0.29)*normal.x
		vertex_normals[i] = (surface.basis.inverse()*normal).normalized()
		point.x -= side*size*0.20*smoothstep(-size*0.10,size*0.19,point.y)
		vertices[i] = surface.transform.affine_inverse()*point
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = vertex_normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	surface.mesh = mesh

static func bind(leg: Node3D, size: float) -> void:
	var foot: MeshInstance3D = leg.get_node("Foot")
	var ankle := Vector3(0,foot.position.y,0)
	var knee := Vector3(0,ankle.y*0.5,-size*0.12)
	var rests: Array[Vector3] = [Vector3.ZERO,knee,ankle]
	var skeleton := Skeleton3D.new()
	skeleton.name = "LegSkeleton"
	var skin := Skin.new()
	leg.add_child(skeleton)
	for i in 3:
		skeleton.add_bone(["Hip","Knee","Ankle"][i])
		if i>0: skeleton.set_bone_parent(i,i-1)
		var local := rests[i]-(rests[i-1] if i>0 else Vector3.ZERO)
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,local))
		skeleton.set_bone_pose_position(i,local)
		skin.add_bind(i,Transform3D(Basis.IDENTITY,rests[i]).affine_inverse())
	# Independent torso anchor keeps the buried attachment from rotating out
	# of the body when the thigh swings. Hip/Knee/Ankle remain the IK chain.
	skeleton.add_bone("Pelvis")
	skin.add_bind(3,Transform3D.IDENTITY)
	for source in leg.get_children():
		if not source is MeshInstance3D: continue
		var arrays: Array = source.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		var normal_basis: Basis = source.basis.inverse().transposed()
		for i in vertices.size():
			vertices[i] = source.transform*vertices[i]
			normals[i] = (normal_basis*normals[i]).normalized()
			var upper := vertices[i].y>=knee.y
			var first := 0 if upper else 1
			var second := first+1
			var fraction := clampf((vertices[i].y-rests[first].y)/(rests[second].y-rests[first].y),0,1)
			if source.name!="LegSurface":
				first = 2
				second = 2
				fraction = 0
			var anchor := smoothstep(-size*0.16,size*0.08,vertices[i].y) if source.name=="LegSurface" else 0.0
			bones.append_array(PackedInt32Array([first,second,3,0]))
			weights.append_array(PackedFloat32Array([(1-fraction)*(1-anchor),fraction*(1-anchor),anchor,0]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var rendered := MeshInstance3D.new()
		rendered.name = "Skin_"+source.name
		rendered.mesh = mesh
		rendered.skin = skin
		rendered.skeleton = NodePath("..")
		rendered.material_override = source.material_override
		skeleton.add_child(rendered)
		source.hide()
static func pose(leg: Node3D, target: Vector3, foot_basis: Basis = Basis.IDENTITY) -> void:
	var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
	var first := skeleton.get_bone_rest(1).origin
	var second := skeleton.get_bone_rest(2).origin
	var a := first.length()
	var b := second.length()
	var distance := clampf(target.length(),absf(a-b)+0.001,a+b-0.0001)
	var direction := target.normalized()
	var along := (a*a+distance*distance-b*b)/(2*distance)
	var bend := (Vector3.FORWARD-direction*Vector3.FORWARD.dot(direction)).normalized()
	var knee := direction*along+bend*sqrt(maxf(0,a*a-along*along))
	var hip_rotation := Quaternion(first.normalized(),knee.normalized())
	var shin_rotation := Quaternion(second.normalized(),(direction*distance-knee).normalized())
	skeleton.set_bone_pose_rotation(0,hip_rotation)
	skeleton.set_bone_pose_rotation(1,hip_rotation.inverse()*shin_rotation)
	skeleton.set_bone_pose_rotation(2,shin_rotation.inverse()*foot_basis.get_rotation_quaternion())
	var body: Node3D = leg.get_parent().get_node("BodySurface")
	var rest := Transform3D(Basis.from_scale(body.scale),body.position)
	var torso_delta := body.transform*rest.affine_inverse()
	var anchor := leg.transform.affine_inverse()*torso_delta*leg.transform
	skeleton.set_bone_pose_position(3,anchor.origin)
	skeleton.set_bone_pose_rotation(3,anchor.basis.get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
