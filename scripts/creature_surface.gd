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
	if label in ["BodySurface","TailSurface","HeadSurface","Jaw","Palm","Finger","Talon"] or label.begins_with("Forelimb") or label.begins_with("EyeRidge") or label.begins_with("BrowHorn"): profiles = smooth_profiles(profiles)
	for ring: Vector4 in profiles: rings.append(ring*scale)
	return surface(parent,label,rings,color,start,end,28,caps)

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
	var center := Vector3(0,0.18,0.055)*scale
	for index in 32:
		st.set_color(color.darkened(0.18))
		st.add_vertex(center)
		for edge in [index,index+1]:
			var angle := float(edge)/32*TAU
			var scallop := 1.0 if edge%2==0 else 0.92
			st.set_color(color.lightened(0.12 if edge%2==0 else 0.0))
			st.add_vertex(Vector3(sin(angle)*0.46*scallop,0.18+cos(angle)*0.36*scallop,0.05+absf(sin(angle))*0.045)*scale)
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
