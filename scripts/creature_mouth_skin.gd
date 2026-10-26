extends RefCounted
## Thin inner cheek folds: upper roots follow the skull, lower roots the jaw.
static func create(neck: Node3D, skull: MeshInstance3D, jaw: MeshInstance3D, size: float, width: float) -> void:
	var skeleton := Skeleton3D.new()
	skeleton.name = "MouthSkeleton"
	neck.add_child(skeleton)
	var skin := Skin.new()
	for index in 2:
		skeleton.add_bone("Skull" if index==0 else "Mandible")
		var rest := Transform3D.IDENTITY if index==0 else jaw.transform
		skeleton.set_bone_rest(index,rest)
		skeleton.set_bone_pose_position(index,rest.origin)
		skeleton.set_bone_pose_rotation(index,rest.basis.get_rotation_quaternion())
		skin.add_bind(index,rest.affine_inverse())
	var head_surface := skull.mesh.generate_triangle_mesh()
	var jaw_surface := jaw.mesh.generate_triangle_mesh()
	var sections := [Vector2(-0.42,0.105),Vector2(-0.34,0.115),Vector2(-0.28,0.105),Vector2(-0.22,0.075),Vector2(-0.16,0.040),Vector2(-0.125,0.008)]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.62
	for side in [-1,1]:
		var rows := []
		for section: Vector2 in sections:
			var x: float = side*section.y*width*size
			var z := section.x*size
			var high := head_surface.intersect_segment(Vector3(x,-size*0.25,z),Vector3(x,size*0.40,z))
			var lower_z := z-jaw.position.z
			var low := jaw_surface.intersect_segment(Vector3(x,size*0.25,lower_z),Vector3(x,-size*0.25,lower_z))
			assert(not high.is_empty() and not low.is_empty(),"Cheek roots require both actual mouth surfaces")
			var upper: Vector3 = high.position+Vector3.UP*size*0.03
			var lower: Vector3 = jaw.transform*(low.position-Vector3.UP*size*0.005)
			var row := []
			for level in 5:
				var t := float(level)/4
				var point := upper.lerp(lower,t)
				point.x += side*size*0.008*sin(PI*t)
				row.append({"point":point,"weight":t})
			rows.append(row)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(0)
		for section in range(rows.size()-1):
			for level in 4:
				var indices := [Vector2i(section,level),Vector2i(section+1,level),Vector2i(section,level+1),Vector2i(section,level+1),Vector2i(section+1,level),Vector2i(section+1,level+1)]
				if side==1: indices.reverse()
				for cell in indices:
					var vertex: Dictionary = rows[cell.x][cell.y]
					tool.set_bones(PackedInt32Array([0,1,0,0]))
					tool.set_weights(PackedFloat32Array([1-vertex.weight,vertex.weight,0,0]))
					tool.set_uv(Vector2(float(cell.x)/(rows.size()-1),vertex.weight))
					var fold := sin(PI*vertex.weight)
					tool.set_color(Color("30292c").lerp(Color("65524f"),fold*0.40))
					tool.add_vertex(vertex.point)
		tool.generate_normals()
		var cheek := MeshInstance3D.new()
		cheek.name = "Cheek"+str(side)
		cheek.mesh = tool.commit()
		cheek.skin = skin
		cheek.skeleton = NodePath("..")
		cheek.material_override = material
		cheek.set_meta("mouth_membrane",true)
		skeleton.add_child(cheek)
static func animate(neck: Node3D) -> void:
	var skeleton: Skeleton3D = neck.get_node("MouthSkeleton")
	var jaw: Node3D = neck.get_node("Jaw")
	skeleton.set_bone_global_pose(1,jaw.transform)
	skeleton.force_update_all_bone_transforms()

static func transform_of(part: MeshInstance3D, bone: int) -> Transform3D:
	var skeleton := part.get_parent() as Skeleton3D
	return skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(bone)
static func bounds(part: MeshInstance3D) -> AABB:
	var box := part.mesh.get_aabb()
	return (transform_of(part,0)*box).merge(transform_of(part,1)*box)
static func triangles(part: MeshInstance3D) -> TriangleMesh:
	var upper := transform_of(part,0)
	var lower := transform_of(part,1)
	if part.has_meta("mouth_pose_cache"):
		var cache: Dictionary = part.get_meta("mouth_pose_cache")
		if upper==cache.upper and lower==cache.lower: return cache.triangles
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for index in points.size():
		points[index] = (upper*points[index])*weights[index*4]+(lower*points[index])*weights[index*4+1]
	var result := TriangleMesh.new()
	var built := result.create_from_faces(points)
	assert(built,"Cheek occlusion requires a valid triangle surface")
	part.set_meta("mouth_pose_cache",{"upper":upper,"lower":lower,"triangles":result})
	return result
