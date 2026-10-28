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
	var pattern_seed := float(str(plate.name).trim_prefix("ArmorPlate").to_int())
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
		var along := uv[index].y
		var across := uv[index].x
		var growth := pow(sin(PI*along),2)
		var keel := pow(maxf(0,cos((across-0.5)*PI)),10)
		var scute := pow(0.5+0.5*cos(TAU*(across*7+sin(along*PI)*0.40+pattern_seed*0.43)),3)
		point.y = hit.position.y+size*(lerpf(0.012,0.006,along)+growth*(0.0022*scute+0.0013*keel))
		vertices[index] = into_plate*point
		var rim := 1-smoothstep(0.03,0.12,minf(uv[index].y,1-uv[index].y))
		colors[index] = colors[index].darkened(rim*0.22)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var normals := solid_shell(vertices,uv,colors,size*0.002)
	normals.generate_normals()
	normals.index()
	plate.mesh = normals.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/creature_armor.gdshader")
	material.set_shader_parameter("pattern_seed",pattern_seed)
	plate.material_override = material

static func solid_shell(points: PackedVector3Array, uv: PackedVector2Array, colors: PackedColorArray, thickness: float) -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	var edges := {}
	var down := Vector3(0,-thickness,0)
	for triangle in range(0,points.size(),3):
		for bottom in [false,true]:
			for corner in ([0,2,1] if bottom else [0,1,2]):
				var index: int = triangle+corner
				tool.set_uv(uv[index])
				tool.set_color(colors[index].darkened(0.12) if bottom else colors[index])
				tool.add_vertex(points[index]+(down if bottom else Vector3.ZERO))
		for edge in 3:
			var a := triangle+edge
			var b := triangle+(edge+1)%3
			var ka := str(Vector3i((points[a]*1000000).round()))
			var kb := str(Vector3i((points[b]*1000000).round()))
			var key := ka+"|"+kb if ka<kb else kb+"|"+ka
			if edges.has(key): edges[key].count += 1
			else: edges[key] = {"count":1,"a":a,"b":b}
	tool.set_smooth_group(-1)
	for edge: Dictionary in edges.values():
		if edge.count!=1: continue
		for vertex in [[edge.b,false],[edge.a,false],[edge.a,true],[edge.b,false],[edge.a,true],[edge.b,true]]:
			var index: int = vertex[0]
			tool.set_uv(uv[index])
			tool.set_color(colors[index].darkened(0.18))
			tool.add_vertex(points[index]+(down if vertex[1] else Vector3.ZERO))
	return tool
