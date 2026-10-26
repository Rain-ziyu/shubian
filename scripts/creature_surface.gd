extends RefCounted
## Original continuous ring surfaces. Profile = (z, half width, half height, center y).
static func point(ring: Vector4, angle: float) -> Vector3:
	return Vector3(sin(angle)*ring.y,cos(angle)*ring.z+ring.w,ring.x)

## Shape-preserving longitudinal curves: retain authored widths without bulging
## beyond adjacent sections, but remove abrupt cone-to-cone silhouette corners.
static func smooth_profiles(profiles: Array) -> Array:
	var result := []
	for row in range(profiles.size()-1):
		var a: Vector4 = profiles[row]
		var b: Vector4 = profiles[row+1]
		var span := b.x-a.x
		for subdivision in 4:
			var t := float(subdivision)/4.0
			var ring := a.lerp(b,t)
			for axis in range(1,4):
				var slope := (b[axis]-a[axis])/span
				var before := slope
				var after := slope
				if row>0:
					var previous: Vector4 = profiles[row-1]
					before = (a[axis]-previous[axis])/(a.x-previous.x)
				if row+2<profiles.size():
					var following: Vector4 = profiles[row+2]
					after = (following[axis]-b[axis])/(following.x-b.x)
				var left := 0.0 if before*slope<=0 else 2*before*slope/(before+slope)
				var right := 0.0 if after*slope<=0 else 2*after*slope/(after+slope)
				ring[axis] = (2*t*t*t-3*t*t+1)*a[axis]+(t*t*t-2*t*t+t)*span*left+(-2*t*t*t+3*t*t)*b[axis]+(t*t*t-t*t)*span*right
			result.append(ring)
	result.append(profiles[-1])
	return result

static func surface(parent: Node3D, label: String, rings: Array, color: Color, start := 0.0, end := TAU, segments := 28, caps := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for row in range(rings.size()-1):
		for column in segments:
			var a := point(rings[row],lerpf(start,end,float(column)/segments))
			var b := point(rings[row],lerpf(start,end,float(column+1)/segments))
			var c := point(rings[row+1],lerpf(start,end,float(column)/segments))
			var d := point(rings[row+1],lerpf(start,end,float(column+1)/segments))
			for index in [0,1,2,1,3,2]:
				var vertex: Vector3 = [a,b,c,d][index]
				var ring: Vector4 = rings[row if index<2 else row+1]
				var height := clampf((vertex.y-ring.w)/maxf(ring.z,0.001),-1,1)
				var shade := color.lightened(0.20).lerp(color.darkened(0.22),smoothstep(-0.8,0.9,height))
				shade = shade.lightened(sin(vertex.z*19+vertex.x*7)*sin(vertex.y*13)*0.035)
				st.set_color(shade)
				var u := float(column+(1 if index in [1,3] else 0))/segments
				var v: float = (vertex.z-rings[0].x)/maxf(rings[-1].x-rings[0].x,0.001)
				st.set_uv(Vector2(u,v))
				st.add_vertex(vertex)
	if caps:
		st.set_smooth_group(-1)
		st.set_color(color)
		for row in [0,rings.size()-1]:
			var ring: Vector4 = rings[row]
			var center := Vector3(0,ring.w,ring.x)
			for column in segments:
				var a := point(ring,lerpf(start,end,float(column)/segments))
				var b := point(ring,lerpf(start,end,float(column+1)/segments))
				for vertex in ([center,b,a] if row==0 else [center,a,b]):
					st.set_uv(Vector2(float(column)/segments,0.0 if row==0 else 1.0))
					st.add_vertex(vertex)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.62
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

static func profile(parent: Node3D, label: String, profiles: Array, scale: float, color: Color, start := 0.0, end := TAU, caps := true) -> MeshInstance3D:
	var rings := []
	if label in ["BodySurface","TailSurface","HeadSurface","Jaw","Palm","Finger","Talon"] or label.begins_with("Forelimb") or label.begins_with("EyeRidge") or label.begins_with("BrowHorn") or label.begins_with("MistSac"): profiles = smooth_profiles(profiles)
	for ring: Vector4 in profiles: rings.append(ring*scale)
	return surface(parent,label,rings,color,start,end,28,caps)

static func tooth_root(surface_mesh: TriangleMesh, x: float, z: float, radius: float, scale: float, upper: bool) -> Vector3:
	# Seat the whole circular root cap, including its edge on a curved jaw.
	var height := -INF if upper else INF
	for sample in 21:
		var angle := TAU*float(sample)/20
		var offset := Vector2.ZERO if sample==20 else Vector2(sin(angle),cos(angle))*radius
		var start := Vector3(x+offset.x,-scale*0.25 if upper else scale*0.25,z+offset.y)
		var end := Vector3(start.x,scale*0.40 if upper else -scale*0.25,start.z)
		var contact := surface_mesh.intersect_segment(start,end)
		assert(not contact.is_empty(),"Tooth root must remain over its jaw surface")
		height = maxf(height,contact.position.y) if upper else minf(height,contact.position.y)
	return Vector3(x,height+scale*(0.003 if upper else -0.003),z)

static func mouth_lining(jaw: MeshInstance3D, hinge: Vector3, scale: float, head_width: float) -> MeshInstance3D:
	# Fit a shallow inner lining to the real mandible, rather than suspending
	# a flat slab above it. No per-frame projection or new contact geometry.
	var sections := [Vector2(-0.65,0.006),Vector2(-0.60,0.055*head_width),Vector2(-0.53,0.085*head_width),Vector2(-0.44,0.11*head_width),Vector2(-0.34,0.115*head_width),Vector2(-0.24,0.09*head_width),Vector2(-0.16,0.045*head_width),Vector2(-0.125,0.008)]
	var surface_mesh := jaw.mesh.generate_triangle_mesh()
	var rows := []
	for section: Vector2 in sections:
		var row := []
		for column in 9:
			var across := float(column)/8*2-1
			var x := across*section.y*scale
			var z := section.x*scale-hinge.z
			var contact := surface_mesh.intersect_segment(Vector3(x,scale*0.25,z),Vector3(x,-scale*0.25,z))
			assert(not contact.is_empty(),"Mouth lining must stay inside its mandible")
			var central := 1-smoothstep(0.2,0.9,absf(across))
			var tongue := central*smoothstep(-0.65,-0.53,section.x)*(1-smoothstep(-0.26,-0.125,section.x))
			var point: Vector3 = contact.position+hinge+Vector3.UP*scale*(0.0015+0.004*tongue)
			var color := Color("1c2b23").lerp(Color("52614b"),tongue*0.75)
			row.append({"point":point,"color":color,"uv":Vector2(float(column)/8,(section.x+0.65)/0.525)})
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for row in range(rows.size()-1):
		for column in 8:
			for item in [rows[row][column],rows[row][column+1],rows[row+1][column],rows[row][column+1],rows[row+1][column+1],rows[row+1][column]]:
				st.set_color(item.color)
				st.set_uv(item.uv)
				st.add_vertex(item.point)
	st.generate_normals()
	var result := MeshInstance3D.new()
	result.name = "MouthFloor"
	result.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.40
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.material_override = material
	jaw.add_child(result)
	return result

static func seat_orbital_ridge(ridge: MeshInstance3D, skull: TriangleMesh, side: int, scale: float) -> void:
	# Each longitudinal section follows its own skull cross-section; a single
	# eye-center offset leaves the upper ridge floating above a curved cranium.
	var arrays: Array = ridge.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cache := {}
	for index in vertices.size():
		var point := ridge.transform*vertices[index]
		var yz := Vector2(point.y,point.z)
		if not cache.has(yz): cache[yz] = skull.intersect_segment(Vector3(side*2*scale,point.y,point.z),Vector3(0,point.y,point.z))
		var contact: Dictionary = cache[yz]
		if contact.is_empty(): continue
		point.x = contact.position.x+vertices[index].x*0.70-side*0.006*scale
		vertices[index] = ridge.transform.affine_inverse()*point
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var projected := ArrayMesh.new()
	projected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface := SurfaceTool.new()
	surface.create_from(projected,0)
	surface.generate_normals()
	ridge.mesh = surface.commit()

static func vertical(parent: Node3D, label: String, profiles: Array, scale: float, color: Color) -> MeshInstance3D:
	var rings := []
	profiles = smooth_profiles(profiles)
	for ring: Vector4 in profiles: rings.append(Vector4(ring.x,ring.y,ring.z,-ring.w)*scale)
	var result := surface(parent,label,rings,color)
	result.rotation.x = -PI/2
	return result

static func frill(parent: Node3D, scale: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	# A bowed membrane with radial tension folds, rather than a flat triangle fan.
	# Keep the authored outer envelope and existing whole-frill animation pivot.
	for ring in 5:
		for column in 64:
			var cells := [Vector2i(0,column),Vector2i(1,column),Vector2i(1,column+1)] if ring==0 else [Vector2i(ring,column),Vector2i(ring+1,column),Vector2i(ring,column+1),Vector2i(ring,column+1),Vector2i(ring+1,column),Vector2i(ring+1,column+1)]
			for cell in cells:
				var radius := float(cell.x)/5
				var angle := float(cell.y)/64*TAU
				var scallop := 0.96+0.04*cos(angle*16)
				var fold := sin(radius*PI)
				var depth := 0.055-0.005*radius+absf(sin(angle))*0.045*radius+(0.065+0.010*cos(angle*16))*fold
				var point := Vector3(sin(angle)*0.46*scallop*radius,0.18+cos(angle)*0.36*scallop*radius,depth)*scale
				var ridge := pow(0.5+0.5*cos(angle*16),6)*fold
				# Dark structural veins and a continuous rim distinguish membrane
				# from the spotted hide without copying the yellow sac weak point.
				var membrane := color.darkened(0.22).lerp(color.lightened(0.18),smoothstep(0.15,0.80,radius))
				var vein := pow(0.5+0.5*cos(angle*16),10)*smoothstep(0.15,0.45,radius)
				var rim := smoothstep(0.86,1.0,radius)
				st.set_color(membrane.lerp(Color("354f57"),maxf(vein*0.65,rim*0.85)))
				st.set_uv(Vector2(0.5+sin(angle)*radius*0.5,0.5+cos(angle)*radius*0.5))
				st.add_vertex(point)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Frill"
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.75
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

static func finish_horn(horn: MeshInstance3D, side: int, size: float) -> void:
	var arrays: Array = horn.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in points.size():
		var seat := smoothstep(-0.49,-0.34,points[i].z/size)
		points[i].x -= side*size*0.03*seat
		points[i].y -= size*0.08*seat
		var growth := smoothstep(0.04,0.95,uv[i].y)
		var band := 0.96+0.04*cos(uv[i].y*TAU*5)
		colors[i] = Color("d6ccb5").lerp(Color("6b624f"),growth)*Color(band,band,band,1)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	var fitted := ArrayMesh.new()
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var normals := SurfaceTool.new()
	normals.create_from(fitted,0)
	normals.generate_normals()
	horn.mesh = normals.commit()
	horn.material_override.roughness = 0.82
