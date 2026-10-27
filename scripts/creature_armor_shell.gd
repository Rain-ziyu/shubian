extends RefCounted
## Seat the shell on the actual trunk instead of embedding an independent arch.
static func fit(plate: MeshInstance3D, body: MeshInstance3D, surface: TriangleMesh, size: float) -> void:
	var arrays: Array = plate.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var into_body := body.transform.affine_inverse()*plate.transform
	var into_plate := into_body.affine_inverse()
	var widths := {}
	for index in vertices.size():
		var point := into_body*vertices[index]
		if not widths.has(point.z):
			var inner := 0.0
			var outer: float = body.mesh.get_aabb().end.x
			for step in 12:
				var x := (inner+outer)*0.5
				var sample := surface.intersect_segment(Vector3(x,size*2,point.z),Vector3(x,-size*2,point.z))
				if sample.is_empty(): outer=x
				else: inner=x
			# Keep the rim on the dorsal slope, away from the vertical flank.
			widths[point.z] = inner*0.85
		var width: float = widths[point.z]
		point.x = width*sin(lerpf(-PI/2,PI/2,uv[index].x))
		var hit := surface.intersect_segment(Vector3(point.x,size*2,point.z),Vector3(point.x,-size*2,point.z))
		assert(not hit.is_empty(),"Armor footprint must remain over its trunk")
		# Successive rear plates cover the lower edge of the forward plate.
		point.y = hit.position.y+size*lerpf(0.012,0.006,uv[index].y)
		vertices[index] = into_plate*point
		var rim := 1-smoothstep(0.03,0.12,minf(uv[index].y,1-uv[index].y))
		colors[index] = colors[index].darkened(rim*0.22)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var fitted := ArrayMesh.new()
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var normals := SurfaceTool.new()
	normals.create_from(fitted,0)
	normals.generate_normals()
	plate.mesh = normals.commit()
