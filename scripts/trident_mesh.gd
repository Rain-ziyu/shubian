extends RefCounted
## Original trident geometry, preserving the combat rig's Y-axis endpoints and grips.
static func material(color: Color, metal := false, glow := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.35 if metal else 0
	result.roughness = 0.32 if metal else 0.8
	result.vertex_color_use_as_albedo = metal
	result.emission_enabled = glow
	result.emission = color
	return result

static func cylinder(parent: Node3D, label: String, y: float, radius: float, height: float, appearance: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	result.mesh = shape
	result.material_override = appearance
	result.position.y = y
	parent.add_child(result)
	return result

static func blade(parent: Node3D, label: String, outline: PackedVector2Array, appearance: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var inset := PackedVector2Array()
	var orientation := -1.0 if Geometry2D.is_polygon_clockwise(outline) else 1.0
	for index in outline.size():
		var incoming := (outline[index]-outline[posmod(index-1,outline.size())]).normalized()
		var outgoing := (outline[(index+1)%outline.size()]-outline[index]).normalized()
		var normal := Vector2(-incoming.y,incoming.x)*orientation
		var next_normal := Vector2(-outgoing.y,outgoing.x)*orientation
		var bisector := (normal+next_normal).normalized()
		inset.append(outline[index]+bisector*minf(0.010,0.003/maxf(0.15,bisector.dot(normal))))
	var indices := Geometry2D.triangulate_polygon(inset)
	for side in [-1,1]:
		# Dark forged flats and a honed bevel stay legible at the gameplay scale.
		st.set_color(Color(0.40,0.46,0.44))
		for index in range(0,indices.size(),3):
			var triangle := [indices[index],indices[index+1],indices[index+2]]
			if side==1: triangle.reverse()
			for vertex in triangle:
				st.add_vertex(Vector3(inset[vertex].x,inset[vertex].y,side*0.012))
		st.set_color(Color(0.95,0.98,1.0))
		for index in outline.size():
			var next := (index+1)%outline.size()
			var a := Vector3(outline[index].x,outline[index].y,0)
			var b := Vector3(outline[next].x,outline[next].y,0)
			var c := Vector3(inset[index].x,inset[index].y,side*0.012)
			var d := Vector3(inset[next].x,inset[next].y,side*0.012)
			var tangent := (outline[next]-outline[index]).normalized()
			var outward := Vector3(tangent.y*orientation,-tangent.x*orientation,side)
			bevel_triangle(st,a,b,c,outward)
			bevel_triangle(st,b,d,c,outward)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.material_override = appearance
	parent.add_child(mesh)

static func bevel_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot front faces use clockwise winding. Keep every concave hook bevel
	# facing outwards instead of averaging it into the broad blade face.
	for point in ([a,c,b] if (b-a).cross(c-a).dot(outward)>0 else [a,b,c]): st.add_vertex(point)

static func create(parent: Node3D, spectral: bool) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var metal := material(Color("9daaa3"),true)
	var shaft := material(Color("303c36"),true)
	var wrap := material(Color("68463c"))
	var jade := material(Color("9bd4b8"),false,true)
	if spectral:
		metal = jade
		shaft = jade
		wrap = jade
	cylinder(root,"Shaft",-0.04,0.024,1.72,shaft)
	cylinder(root,"Grip",-0.04,0.029,0.58,wrap)
	for y in [-0.32,0.24,0.77,-0.87]: cylinder(root,"Ferrule",y,0.034,0.045,metal)
	for index in 12: cylinder(root,"GripRib",-0.29+index*0.045,0.0305,0.007,shaft)
	cylinder(root,"ButtNeck",-0.90,0.034,0.08,metal)
	var butt := MeshInstance3D.new()
	butt.name = "Butt"
	var sphere := SphereMesh.new()
	sphere.radius = 0.058
	sphere.height = 0.096
	sphere.radial_segments = 16
	sphere.rings = 8
	butt.mesh = sphere
	butt.position.y = -0.93
	butt.material_override = metal
	root.add_child(butt)
	blade(root,"CenterBlade",PackedVector2Array([Vector2(-0.031,0.78),Vector2(-0.052,0.99),Vector2(0,1.21),Vector2(0.052,0.99),Vector2(0.031,0.78)]),metal)
	for side in [-1,1]:
		var outline := PackedVector2Array()
		for point in [Vector2(0.025,0.77),Vector2(0.12,0.83),Vector2(0.145,1.02),Vector2(0.19,1.13),Vector2(0.178,0.96),Vector2(0.20,0.87),Vector2(0.16,0.81),Vector2(0.135,0.70),Vector2(0.113,0.745),Vector2(0.12,0.80)]: outline.append(Vector2(point.x*side,point.y))
		blade(root,"Hook"+str(side),outline,metal)
	var cell := cylinder(root,"JadeCell",0.875,0.018,0.15,jade)
	cell.position.z = -0.023
	var contacts := {"TipContact":Vector3(0,1.2,0),"BladeContact":Vector3(0,0.95,0),"HeadBaseContact":Vector3(0,0.70,0),"LeftProngContact":Vector3(-0.17,1.06,0),"RightProngContact":Vector3(0.17,1.06,0),"LeftHookContact":Vector3(-0.135,0.70,0),"RightHookContact":Vector3(0.135,0.70,0),"ButtContact":Vector3(0,-0.98,0),"ButtNeckContact":Vector3(0,-0.88,0)}
	for label in contacts:
		var marker := Marker3D.new()
		marker.name = label
		marker.position = contacts[label]
		root.add_child(marker)
	if spectral:
		var spirit := ShaderMaterial.new()
		spirit.shader = preload("res://shaders/spectral_trident.gdshader")
		for child in root.get_children():
			if child is MeshInstance3D: child.material_override = spirit
		root.set_meta("spectral_material",spirit)
	return root
