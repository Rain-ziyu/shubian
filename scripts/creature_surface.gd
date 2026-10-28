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
	if label.begins_with("BrowHorn"): profiles = smooth_profiles(profiles)
	if label in ["BodySurface","TailSurface","HeadSurface","Jaw","Palm","Finger","Talon"] or label.begins_with("Forelimb") or label.begins_with("EyeRidge") or label.begins_with("BrowHorn") or label.begins_with("MistSac") or label.begins_with("ArmorPlate") or label.begins_with("Crest"): profiles = smooth_profiles(profiles)
	for ring: Vector4 in profiles: rings.append(ring*scale)
	# Refine the broad torso silhouette without increasing the head convex hull.
	# Keep the authored profiles, UV layout, attachment frames and end caps.
	var segments := 56 if label=="BodySurface" or label.begins_with("ArmorPlate") or label.begins_with("MistSac") else 28
	return surface(parent,label,rings,color,start,end,segments,caps)

## Broad anatomical planes belong to the continuous skin, not floating detail meshes.
## Work in species-size coordinates so muscle relief has a consistent visual scale.
static func sculpt_anatomy(mesh_node: MeshInstance3D, size: float, part: String, species: String) -> void:
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for index in vertices.size():
		var p := vertices[index]/size
		var relief := 0.0
		if part=="body":
			var side := smoothstep(0.10,0.25,absf(p.x))*(1-smoothstep(0.14,0.25,p.y))
			var shoulder := exp(-pow((p.z+0.29)/0.12,2))*exp(-pow((p.y-0.01)/0.20,2))
			var scapula := exp(-pow((p.z+0.12+p.y*0.45)/0.055,2))*exp(-pow((p.y-0.03)/0.19,2))
			var waist := exp(-pow((p.z-0.17)/0.16,2))*exp(-pow((p.y+0.08)/0.18,2))
			var hip := exp(-pow((p.z-0.35)/0.10,2))*exp(-pow((p.y+0.02)/0.16,2))
			var lean := 1.25 if species=="reedclaw" else 0.85 if species=="mossback" else 1.0
			relief = (0.042*shoulder-0.018*scapula-0.025*waist+0.018*hip)*side*lean
			p.x += sign(p.x)*relief
			# A shallow abdominal tuck and a continuous sternum replace the barrel underside.
			var belly := (1-smoothstep(-0.22,-0.06,p.y))
			p.y += belly*(0.022*waist-0.009*exp(-pow((p.z+0.24)/0.20,2)))
			colors[index] = colors[index].darkened(clampf((scapula*0.10+waist*0.04)*side,0,0.13))
		else:
			# Cheek mass sits behind the eye, while the nasal ridge rises between the nostrils.
			var cheek := exp(-pow((p.z+0.25)/0.13,2))*exp(-pow((p.y-0.075)/0.09,2))
			var side := smoothstep(0.05,0.12,absf(p.x))
			var bridge := exp(-pow(p.x/0.065,2))*exp(-pow((p.z+0.57)/0.13,2))*smoothstep(0.07,0.14,p.y)
			var nasal_plane := exp(-pow((absf(p.x)-0.085)/0.045,2))*exp(-pow((p.z+0.57)/0.12,2))*smoothstep(0.07,0.13,p.y)
			relief = 0.018*cheek*side
			p.x += sign(p.x)*relief
			p.y += 0.018*bridge-0.009*nasal_plane
			colors[index] = colors[index].darkened(0.055*nasal_plane+0.045*cheek*side)
		vertices[index] = p*size
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var sculpted := ArrayMesh.new()
	sculpted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var normals := SurfaceTool.new()
	normals.create_from(sculpted,0)
	normals.generate_normals()
	mesh_node.mesh = normals.commit()

static func seat_forelimb(arm: MeshInstance3D, size: float, side: int) -> void:
	var arrays: Array = arm.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in points.size():
		var point := points[index]
		var root := smoothstep(-size*0.14,size*0.02,point.z)
		point.x = lerpf(point.x,point.x*0.65-side*size*0.18,root)
		point.y *= lerpf(1.0,0.75,root)
		points[index] = point
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var normals := SurfaceTool.new()
	normals.create_from(mesh,0)
	normals.generate_normals()
	arm.mesh = normals.commit()

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

static func mouth_lining(jaw: MeshInstance3D, hinge: Vector3, scale: float, head_width: float, upper := false) -> MeshInstance3D:
	# Fit a shallow inner lining to the actual jaw surface, rather than suspending
	# a flat slab above it. No per-frame projection or new contact geometry.
	var sections := [Vector2(-0.65,0.006),Vector2(-0.60,0.055*head_width),Vector2(-0.53,0.085*head_width),Vector2(-0.44,0.11*head_width),Vector2(-0.34,0.115*head_width),Vector2(-0.24,0.09*head_width),Vector2(-0.16,0.045*head_width),Vector2(-0.125,0.008)]
	var sampled: Array[Vector2] = []
	for segment in range(sections.size()-1):
		for step in 6:
			sampled.append(Vector2(sections[segment]).lerp(sections[segment+1],float(step)/6))
	sampled.append(sections[-1])
	var surface_mesh := jaw.mesh.generate_triangle_mesh()
	var rows := []
	for section: Vector2 in sampled:
		var row := []
		for column in 17:
			var across := float(column)/16*2-1
			var x := across*section.y*scale
			var z := section.x*scale-hinge.z
			var contact := surface_mesh.intersect_segment(Vector3(x,-scale*0.25 if upper else scale*0.25,z),Vector3(x,scale*0.40 if upper else -scale*0.25,z))
			assert(not contact.is_empty(),"Mouth lining must stay on its corresponding jaw surface")
			var central := 1-smoothstep(0.2,0.9,absf(across))
			var tongue := central*smoothstep(-0.65,-0.53,section.x)*(1-smoothstep(-0.26,-0.125,section.x))
			var groove := exp(-pow(across/0.12,2))*tongue
			var point: Vector3 = contact.position+hinge+Vector3.UP*scale*(0.0015+0.004*tongue-0.0006*groove)
			var color := Color("51454d").lerp(Color("89757c"),tongue*0.75).darkened(groove*0.06)
			if upper:
				var depth := smoothstep(-0.65,-0.125,section.x)
				var fold := pow(0.5+0.5*cos((section.x+0.65)*TAU*18+absf(across)*1.2),4)
				var relief := fold*central*(1-depth)
				point.y = contact.position.y+hinge.y-scale*(0.0012+0.0013*relief)
				color = Color("6b5963").lerp(Color("302a33"),depth).lightened(0.07*relief)
			row.append({"point":point,"color":color,"uv":Vector2(float(column)/16,(section.x+0.65)/0.525)})
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for row in range(rows.size()-1):
		for column in 16:
			var quad: Array = [rows[row][column],rows[row][column+1],rows[row+1][column],rows[row][column+1],rows[row+1][column+1],rows[row+1][column]]
			if upper: quad.reverse()
			for item in quad:
				st.set_color(item.color)
				st.set_uv(item.uv)
				st.add_vertex(item.point)
	st.generate_normals()
	var result := MeshInstance3D.new()
	result.name = "MouthRoof" if upper else "MouthFloor"
	result.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.40
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.material_override = material
	jaw.add_child(result)
	return result

static func nostril_relief(part: MeshInstance3D, skull: TriangleMesh, size: float, side: int, skin: Color) -> void:
	var contact := skull.intersect_segment(Vector3(side*size*2,part.position.y,part.position.z),Vector3(0,part.position.y,part.position.z))
	assert(not contact.is_empty(),"Nostril must remain on the real skull")
	var normal: Vector3 = contact.normal
	if normal.x*side<0: normal = -normal
	var along := (Vector3.FORWARD-normal*Vector3.FORWARD.dot(normal)).normalized()
	var across := normal.cross(along).normalized()
	var rows: Array[PackedVector3Array] = []
	var radii := [1.0,0.82,0.60,0.28,0.0]
	var lifts := [0.0005,0.005,0.0038,0.0008,0.0008]
	var tints := [skin.darkened(0.58),skin.darkened(0.45),skin.darkened(0.85),Color("08100b"),Color("050c08")]
	for row in radii.size():
		var points := PackedVector3Array()
		for column in 25:
			var angle := TAU*float(column)/24
			var plane: Vector3 = contact.position+(along*cos(angle)*0.022+across*sin(angle)*0.009)*size*float(radii[row])
			var hit := skull.intersect_segment(plane+normal*size*0.1,plane-normal*size*0.1)
			assert(not hit.is_empty(),"Nasal rim must follow the curved skull surface")
			var up: Vector3 = hit.normal
			if up.dot(normal)<0: up = -up
			points.append(hit.position+up*size*float(lifts[row])-part.position)
		rows.append(points)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for row in range(rows.size()-1):
		for column in 24:
			var quad := [rows[row][column],rows[row][column+1],rows[row+1][column],rows[row+1][column+1]]
			var faces := [Vector3i(0,1,2),Vector3i(1,3,2)] if row<rows.size()-2 else [Vector3i(0,1,2)]
			for face: Vector3i in faces:
				var a: Vector3 = quad[face.x]
				var b: Vector3 = quad[face.y]
				var c: Vector3 = quad[face.z]
				var order := [face.x,face.z,face.y] if (b-a).cross(c-a).dot(normal)>0 else [face.x,face.y,face.z]
				for index: int in order:
					tool.set_color(tints[row+(1 if index>=2 else 0)])
					tool.add_vertex(quad[index])
	tool.generate_normals()
	part.mesh = tool.commit()
	part.scale = Vector3.ONE
	part.material_override.albedo_color = Color.WHITE
	part.material_override.vertex_color_use_as_albedo = true
	part.material_override.roughness = 0.82
	part.material_override.metallic_specular = 0.15

static func seat_orbital_ridge(ridge: MeshInstance3D, skull: TriangleMesh, side: int, scale: float, eye: MeshInstance3D, skin: Color) -> void:
	# Upper and lower eyelids share the same longitudinal sections and embed
	# both outer roots in the skull. The middle remains an actual eye opening.
	var rows: Array[PackedVector3Array] = []
	for row in 25:
		var u := float(row)/24*2-1
		var z := eye.position.z+u*scale*0.035
		var outside := sqrt(maxf(0,1-u*u))
		var aperture := sqrt(maxf(0,1-pow(u*0.035/0.020,2)))
		var y := eye.position.y+u*scale*0.002
		var ys := [y+scale*0.018*outside,y+scale*(0.010*outside+0.0035*aperture),y+scale*0.0075*aperture,y-scale*0.0075*aperture,y-scale*(0.007*outside+0.0035*aperture),y-scale*0.013*outside]
		var points := PackedVector3Array()
		for index in 6:
			var hit := skull.intersect_segment(Vector3(side*scale*2,ys[index],z),Vector3(0,ys[index],z))
			assert(not hit.is_empty(),"Orbital socket must stay attached to the skull")
			var x: float = hit.position.x-side*scale*0.0005
			if index in [1,4]: x = lerpf(x,eye.position.x+side*scale*(0.008 if index==1 else 0.007),0.85*outside)
			if index in [2,3]: x = lerpf(x,eye.position.x+side*scale*0.009,outside)
			points.append(Vector3(x,ys[index],z))
		rows.append(points)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for row in 24:
		for column in [0,1,3,4]:
			for face in [[Vector2i(row,column),Vector2i(row+1,column),Vector2i(row,column+1)],[Vector2i(row+1,column),Vector2i(row+1,column+1),Vector2i(row,column+1)]]:
				var a: Vector3 = rows[face[0].x][face[0].y]
				var b: Vector3 = rows[face[1].x][face[1].y]
				var c: Vector3 = rows[face[2].x][face[2].y]
				var order := [0,2,1] if (b-a).cross(c-a).dot(Vector3(side,0,0))>0 else [0,1,2]
				for index in order:
					var cell: Vector2i = face[index]
					var darkness := 0.65 if cell.y in [2,3] else 0.22 if cell.y in [1,4] else 0.25
					tool.set_color(skin.darkened(darkness))
					tool.set_uv(Vector2(float(cell.x)/24,float(cell.y)/5))
					tool.add_vertex(ridge.transform.affine_inverse()*rows[cell.x][cell.y])
	tool.generate_normals()
	ridge.mesh = tool.commit()
	ridge.material_override.roughness = 0.75
	ridge.material_override.metallic_specular = 0.20

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
	var sections := {}
	for point: Vector3 in points:
		var key := roundi(point.z/size*1000000)
		if not sections.has(key): sections[key] = Vector2(point.y,point.y)
		sections[key] = Vector2(minf(sections[key].x,point.y),maxf(sections[key].y,point.y))
	for i in points.size():
		var extent: Vector2 = sections[roundi(points[i].z/size*1000000)]
		var center := Vector3(0,(extent.x+extent.y)*0.5,points[i].z)
		var radial := points[i]-center
		var t := uv[i].y
		var angle := atan2(radial.x,radial.y)
		var relief := smoothstep(0.10,0.28,t)*(1-smoothstep(0.86,1.0,t))
		var ring := pow(0.5+0.5*cos(t*TAU*8+0.2*sin(angle*3)),6)
		if radial.length_squared()>0.00000001:
			points[i] += radial.normalized()*size*relief*(0.0018*ring+0.0007*cos(angle*7+t*1.4))
		# Bow the shaft outward between its fixed tip and buried root.
		points[i].x += side*size*0.035*pow(sin(t*PI),2)
		points[i].y -= size*0.020*pow(sin(t*PI),2)
		var seat := smoothstep(-0.49,-0.34,points[i].z/size)
		points[i].x -= side*size*0.03*seat
		points[i].y -= size*0.08*seat
		var growth := smoothstep(0.04,0.95,uv[i].y)
		var band := 0.91+0.09*ring
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

static func shape_foot(foot: MeshInstance3D) -> void:
	# One continuous pad with three toe lobes; keep its sole and ankle frame.
	var primitive := SphereMesh.new()
	primitive.radial_segments = 64
	primitive.rings = 24
	var arrays: Array = primitive.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for index in vertices.size():
		var point := vertices[index]
		var front := 1-smoothstep(-0.35,-0.05,point.z)
		var valley := 0.5-0.5*cos(TAU*point.x/0.262)
		var toe_center := clampf(roundf(point.x/0.262),-1,1)*0.262
		var digit := exp(-pow((point.x-toe_center)/0.085,2))
		var knuckle := digit*exp(-pow((point.z+0.22)/0.13,2))
		var crease := digit*exp(-pow((point.z+0.10)/0.025,2))
		var upper := smoothstep(0.0,0.25,point.y)
		var underside := 1-smoothstep(-0.40,-0.12,point.y)
		point.y += upper*(0.060*knuckle-0.022*crease)
		# A broad load-bearing pad retains the original lowest sole and ankle frame.
		if point.y< -0.20: point.y = lerpf(-0.5,point.y,smoothstep(-0.45,-0.20,point.y))
		point.z += 0.20*valley*front
		point.x *= 1-0.20*smoothstep(0.05,0.40,point.z)
		vertices[index] = point
		colors.append(Color.WHITE.darkened(0.15*valley*front*upper+0.14*crease*upper+0.18*underside).lightened(0.06*knuckle*upper))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var shaped := ArrayMesh.new()
	shaped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var normals := SurfaceTool.new()
	normals.create_from(shaped,0)
	normals.generate_normals()
	foot.mesh = normals.commit()
	foot.material_override.vertex_color_use_as_albedo = true
	foot.material_override.roughness = 0.85
