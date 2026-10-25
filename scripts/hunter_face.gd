extends RefCounted
## Small anatomical planes and surface-seated features for the authored ranger.
## Construction only: existing head anchors, bones and animation channels remain.
static func sculpt(point: Vector3) -> Vector3:
	var front := 1-smoothstep(-0.075,-0.025,point.z)
	var x := absf(point.x)
	var cheek := exp(-pow((x-0.075)/0.038,2)-pow((point.y-1.675)/0.026,2))
	var orbit := exp(-pow((x-0.056)/0.024,2)-pow((point.y-1.713)/0.010,2))
	var hood := exp(-pow((x-0.056)/0.033,2)-pow((point.y-1.733)/0.012,2))
	var bridge := exp(-pow(x/0.019,2)-pow((point.y-1.697)/0.032,2))
	var mouth := exp(-pow(x/0.038,2)-pow((point.y-1.637)/0.018,2))
	var chin := exp(-pow(x/0.050,2)-pow((point.y-1.579)/0.019,2))
	point.z += front*(0.0015*orbit-0.0045*cheek-0.0025*hood-0.004*bridge-0.003*mouth-0.005*chin)
	return point

static func seat_features(root: Node3D) -> void:
	var head: MeshInstance3D = root.get_node("Head")
	var surface := head.mesh.generate_triangle_mesh()
	var cache := {}
	for part in root.get_children():
		if not part is MeshInstance3D: continue
		var label := str(part.name)
		var white := label.begins_with("EyeWhite")
		var iris := label.begins_with("Iris")
		var glint := label.begins_with("EyeGlint")
		var lip := label in ["UpperLip","LowerLip"]
		var upper_lid := label.begins_with("UpperLid")
		var lower_lid := label.begins_with("LowerLid")
		var brow := label.begins_with("Brow")
		if not white and not iris and not glint and not lip and not upper_lid and not lower_lid and not brow: continue
		var side := -1.0 if label.ends_with("-1") else 1.0
		var arrays: Array = (refine_patch(part.mesh) if brow or upper_lid or lower_lid else part.mesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var inverse: Transform3D = part.transform.affine_inverse()
		for index in vertices.size():
			var original := vertices[index]
			var local := original
			if white:
				# Taper the corners into an almond opening instead of an ellipsoid.
				local.y *= pow(maxf(0,1-pow(clampf(local.x*2,-1,1),2)),0.20)
			var point: Vector3 = part.transform*local
			if white: point.y += side*original.x*0.0016
			var xy := Vector2(point.x,point.y)
			if not cache.has(xy): cache[xy] = surface.intersect_segment(Vector3(point.x,point.y,-1),Vector3(point.x,point.y,1))
			var hit: Dictionary = cache[xy]
			if hit.is_empty(): continue
			var offset := -0.0012
			if white: offset = 0.0007+original.z*0.0064
			elif iris: offset = -0.0030+original.z*0.0010
			elif glint: offset = -0.0043+original.z*0.0006
			elif lip: offset = 0.0005+original.z*0.004
			elif upper_lid: offset = -0.0015
			elif lower_lid: offset = -0.0010
			point.z = hit.position.z+offset
			vertices[index] = inverse*point
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var projected := ArrayMesh.new()
		projected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool := SurfaceTool.new()
		tool.create_from(projected,0)
		tool.generate_normals()
		part.mesh = tool.commit()

static func refine_patch(mesh: ArrayMesh) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0,points.size(),3):
		refine_triangle(tool,points[index],points[index+1],points[index+2],uv[index],uv[index+1],uv[index+2],3)
	tool.generate_normals()
	return tool.commit()

static func refine_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, depth: int) -> void:
	if depth==0:
		for point in [[a,ua],[b,ub],[c,uc]]:
			tool.set_uv(point[1])
			tool.add_vertex(point[0])
		return
	var ab := (a+b)*0.5
	var bc := (b+c)*0.5
	var ca := (c+a)*0.5
	var uab := (ua+ub)*0.5
	var ubc := (ub+uc)*0.5
	var uca := (uc+ua)*0.5
	refine_triangle(tool,a,ab,ca,ua,uab,uca,depth-1)
	refine_triangle(tool,ab,b,bc,uab,ub,ubc,depth-1)
	refine_triangle(tool,ca,bc,c,uca,ubc,uc,depth-1)
	refine_triangle(tool,ab,bc,ca,uab,ubc,uca,depth-1)
