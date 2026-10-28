extends RefCounted
## Small anatomical planes and surface-seated features for the authored ranger.
## Surface-seated features and eyelid shapes share the existing head anchors.
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
		if upper_lid or lower_lid:
			part.mesh = eyelid_mesh(part,surface,upper_lid)
			part.material_override.albedo_color = Color.WHITE
			part.material_override.vertex_color_use_as_albedo = true
			add_blink(part,surface,true)
			continue
		var side := -1.0 if label.ends_with("-1") else 1.0
		var arrays: Array = (refine_patch(part.mesh) if brow or upper_lid or lower_lid else part.mesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV].duplicate()
		var inverse: Transform3D = part.transform.affine_inverse()
		for index in vertices.size():
			var original := vertices[index]
			if iris: uv[index] = Vector2(original.x+0.5,0.5-original.y)
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
		if iris: arrays[Mesh.ARRAY_TEX_UV] = uv
		var projected := ArrayMesh.new()
		projected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool := SurfaceTool.new()
		tool.create_from(projected,0)
		tool.generate_normals()
		part.mesh = tool.commit()
		if iris:
			var eye_material := ShaderMaterial.new()
			eye_material.shader = preload("res://shaders/hunter_iris.gdshader")
			eye_material.set_shader_parameter("iris_tint",Color("6a503b"))
			part.material_override = eye_material
		if white or iris or glint or upper_lid or lower_lid: add_blink(part,surface,upper_lid or lower_lid)

static func create_lid(parent: Node3D, label: String, skin: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var material := StandardMaterial3D.new()
	material.albedo_color = skin
	material.roughness = 0.65
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	part.material_override = material
	parent.add_child(part)

static func eyelid_mesh(part: MeshInstance3D, head: TriangleMesh, upper: bool) -> ArrayMesh:
	# A rounded skin roll follows the same almond boundary as the eyeball.
	# The outside and back of the roll disappear into the orbital skin.
	var side := -1.0 if str(part.name).ends_with("-1") else 1.0
	var direction := 1.0 if upper else -1.0
	var width := 0.0035 if upper else 0.0025
	var skin := part.material_override.albedo_color as Color
	var inverse := part.transform.affine_inverse()
	var rows: Array[PackedVector3Array] = []
	var shades: Array[PackedColorArray] = []
	for row in 41:
		var t := float(row)/40
		var x := (t*2-1)*0.021
		var almond := pow(maxf(0,1-pow(x/0.021,2)),0.70)
		var boundary := 1.712+direction*0.007*almond+side*x*(0.0016/0.042)
		var taper := 0.06+0.94*pow(sin(t*PI),0.40)
		var ring := PackedVector3Array()
		var colors := PackedColorArray()
		for column in 12:
			var angle := TAU*column/12
			var across := (cos(angle)+1)*0.5
			var point := Vector3(side*0.056+x,boundary+direction*width*across*taper,0)
			var hit := head.intersect_segment(Vector3(point.x,point.y,-1),Vector3(point.x,point.y,1))
			var offset := lerpf(-0.0028,0.001,across)-sin(angle)*0.0018*taper
			point.z = hit.position.z+offset if not hit.is_empty() else -0.11+offset
			ring.append(inverse*point)
			colors.append(skin.lerp(Color("ad8372"),(1-across)*0.25))
		rows.append(ring)
		shades.append(colors)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for row in 40:
		for column in 12:
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1)]:
				var ring_index: int = row+corner.x
				var across_index: int = (column+corner.y)%12
				st.set_uv(Vector2(float(ring_index)/40,float(column+corner.y)/12))
				st.set_color(shades[ring_index][across_index])
				st.add_vertex(rows[ring_index][across_index])
	for end in [0,40]:
		for column in range(1,11):
			for index in ([0,column+1,column] if end==0 else [0,column,column+1]):
				st.set_uv(Vector2(float(end)/40,0.5))
				st.set_color(shades[end][index])
				st.add_vertex(rows[end][index])
	st.generate_normals()
	return st.commit()

static func add_blink(part: MeshInstance3D, head: TriangleMesh, lid: bool) -> void:
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var inverse := part.transform.affine_inverse()
	var side := -1.0 if str(part.name).ends_with("-1") else 1.0
	for index in points.size():
		var point: Vector3 = part.transform*points[index]
		var crease := 1.712+side*(point.x-side*0.056)*0.04
		point.y = lerpf(crease,point.y,0.12 if lid else 0.025)
		var hit := head.intersect_segment(Vector3(point.x,point.y,-1),Vector3(point.x,point.y,1))
		if not hit.is_empty(): point.z = hit.position.z+(-0.0016 if lid else 0.001)
		points[index] = inverse*point
	var closed: Array = arrays.duplicate(true)
	closed[Mesh.ARRAY_VERTEX] = points
	var temporary := ArrayMesh.new()
	temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,closed)
	var normals := SurfaceTool.new()
	normals.create_from(temporary,0)
	normals.generate_normals()
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = points
	shape[Mesh.ARRAY_NORMAL] = normals.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	mesh.add_blend_shape("Blink")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape])
	part.mesh = mesh

static func animate(rig: Dictionary, action: String, elapsed: float, delta: float) -> void:
	rig.blink_clock = float(rig.get("blink_clock",0.0))+maxf(delta,0)
	var clock := fposmod(float(rig.blink_clock),8.3)
	var blink := blink_pulse(clock-3.2)+blink_pulse(clock-7.6)
	if delta<=0: blink = 0.0 # Static pose samples and baked clips use only authored reactions.
	if action=="hurt": blink = maxf(blink,smoothstep(0,0.04,elapsed)*(1-smoothstep(0.10,0.22,elapsed)))
	for part in rig.head_parts:
		var mesh := part.source as MeshInstance3D
		if mesh==null: continue
		var channel := mesh.find_blend_shape_by_name("Blink")
		if channel>=0: mesh.set_blend_shape_value(channel,clampf(blink,0,1))

static func blink_pulse(age: float) -> float:
	return smoothstep(0,0.055,age)*(1-smoothstep(0.085,0.20,age))

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
