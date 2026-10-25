extends RefCounted
## Original mesh profiles for the approved wet-forest costume. No third-party meshes.
const V = preload("res://scripts/visuals.gd")
const Profiles = preload("res://scripts/creature_surface.gd")
const MetalMesh = preload("res://scripts/trident_mesh.gd")
const SKIN_TONE := Color("bd9b80")

static func loft(parent: Node3D, label: String, rings: Array, color: Color, start := 0.0, end := TAU, segments := 28, caps := true) -> MeshInstance3D:
	var garment := label in ["Undercoat","TrouserThigh","TrouserShin"]
	if garment or label in ["Head","NoseBridge","HairKnot"] or label.begins_with("UpperArmSurface") or label.begins_with("RainCape"): rings = Profiles.smooth_profiles(rings)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var bottom: float = rings[0].x
	var span := maxf(0.0001,float(rings[-1].x)-bottom)
	for row in range(rings.size()-1):
		for column in segments:
			var a := profile_point(rings[row],lerpf(start,end,float(column)/segments))
			var b := profile_point(rings[row],lerpf(start,end,float(column+1)/segments))
			var c := profile_point(rings[row+1],lerpf(start,end,float(column)/segments))
			var d := profile_point(rings[row+1],lerpf(start,end,float(column+1)/segments))
			var u0 := float(column)/segments
			var u1 := float(column+1)/segments
			var v0 := (float(rings[row].x)-bottom)/span
			var v1 := (float(rings[row+1].x)-bottom)/span
			for item in [[a,Vector2(u0,v0)],[c,Vector2(u0,v1)],[b,Vector2(u1,v0)],[b,Vector2(u1,v0)],[c,Vector2(u0,v1)],[d,Vector2(u1,v1)]]:
				st.set_uv(item[1])
				var point: Vector3 = item[0]
				if garment: point = garment_drape(point,label,bottom,span)
				if label.begins_with("RainCape") or label.begins_with("CapeHem"): point = cape_drape(point)
				st.add_vertex(point)
	if caps:
		st.set_smooth_group(-1)
		for row in [0,rings.size()-1]:
			var ring: Vector4 = rings[row]
			var center := Vector3(0,ring.x,ring.w)
			for column in segments:
				var a := profile_point(ring,lerpf(start,end,float(column)/segments))
				var b := profile_point(ring,lerpf(start,end,float(column+1)/segments))
				for point in ([center,a,b] if row==0 else [center,b,a]):
					st.set_uv(Vector2(point.x/maxf(ring.y*2,0.0001)+0.5,(point.z-ring.w)/maxf(ring.z*2,0.0001)+0.5))
					st.add_vertex(point)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.material_override = V.mat(color)
	parent.add_child(mesh)
	return mesh

static func profile_point(ring: Vector4, angle: float) -> Vector3:
	return Vector3(sin(angle)*ring.y,ring.x,cos(angle)*ring.z+ring.w)

static func garment_drape(point: Vector3, label: String, bottom: float, span: float) -> Vector3:
	# Broad tension folds are geometry, not animated shader noise. Fade to the
	# original openings so the belt, knee underlayers and ankle stay registered.
	var t := clampf((point.y-bottom)/span,0,1)
	var envelope := pow(sin(t*PI),2)
	var angle := atan2(point.x,point.z)
	var trouser := label.begins_with("Trouser")
	var diagonal := sin(angle*4+t*11)*0.004
	var gathering := sin(t*TAU*3+sin(angle*2)*0.8)*(0.006 if trouser else 0.004)
	var slack := 0.004 if trouser else 0.001
	var fold := (slack+diagonal+gathering)*envelope
	return point+Vector3(sin(angle)*fold,0,cos(angle)*fold)

static func cape_drape(point: Vector3) -> Vector3:
	# Cloth falls farther behind the shoulders. The collar stays fixed and
	# both halves keep their central equipment slit; hem uses the same shape.
	var weight := 1-smoothstep(1.20,1.49,point.y)
	var angle := atan2(point.x,point.z-0.018)
	var fold := sin(angle*6)*0.012*weight
	# The shorter front clears the waist-level staff; the back sheds rain below it.
	var hem_height := -0.055*maxf(0,cos(angle))+0.065*maxf(0,-cos(angle))
	point += Vector3(sin(angle)*fold,hem_height*weight,cos(angle)*fold)
	return point

static func patch(parent: Node3D, label: String, points: Array, color: Color) -> MeshInstance3D:
	if label in ["CoatPanel","PanelTrim"]: return cloth_panel(parent,label,points,color)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lower := Vector2(INF,INF)
	var upper := Vector2(-INF,-INF)
	for point in points:
		lower = lower.min(Vector2(point.x,point.y))
		upper = upper.max(Vector2(point.x,point.y))
	var extent := (upper-lower).max(Vector2(0.0001,0.0001))
	for index in range(1,points.size()-1):
		for vertex in [points[0],points[index],points[index+1]]:
			st.set_uv((Vector2(vertex.x,vertex.y)-lower)/extent)
			st.add_vertex(vertex)
	st.generate_normals()
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = st.commit()
	result.material_override = V.mat(color)
	result.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(result)
	return result

static func cloth_panel(parent: Node3D, label: String, points: Array, color: Color) -> MeshInstance3D:
	var meshes: Array[Array] = []
	for flex in [0.0,1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(0)
		var corners := [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
		if (points[1]-points[0]).cross(points[3]-points[0]).z<0:
			corners = [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
		for row in 10:
			for column in 8:
				for corner: Vector2i in corners:
					var u := float(column+corner.x)/8
					var v := float(row+corner.y)/10
					var top: Vector3 = points[0].lerp(points[1],u)
					var bottom: Vector3 = points[3].lerp(points[2],u)
					var point := top.lerp(bottom,v)
					var hang := clampf(-point.y/0.29,0,1)
					point.z -= sin(hang*PI)*(0.010+0.006*sin(point.x*35+hang*2))
					point += Vector3(0,0.012,-0.035)*hang*hang*flex
					st.set_uv(Vector2((point.x+0.105)/0.225,1-hang))
					st.add_vertex(point)
		st.generate_normals()
		meshes.append(st.commit().surface_get_arrays(0))
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = meshes[1][Mesh.ARRAY_VERTEX]
	shape[Mesh.ARRAY_NORMAL] = meshes[1][Mesh.ARRAY_NORMAL]
	var mesh := ArrayMesh.new()
	mesh.add_blend_shape("HemFlex")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,meshes[0],[shape])
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.material_override = V.mat(color)
	result.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(result)
	return result

static func ribbon(parent: Node3D, label: String, points: Array, width: float, color: Color) -> MeshInstance3D:
	var outline := []
	var reverse := []
	for index in points.size():
		var before: Vector3 = points[maxi(0,index-1)]
		var after: Vector3 = points[mini(points.size()-1,index+1)]
		var tangent := (after-before).normalized()
		var normal := Vector3(-tangent.y,tangent.x,0)*width*0.5
		outline.append(points[index]+normal)
		reverse.push_front(points[index]-normal)
	outline.append_array(reverse)
	return patch(parent,label,outline,color)

static func thicken_plate(surface: ArrayMesh, thickness: float) -> ArrayMesh:
	var arrays := surface.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := {}
	for triangle in range(0,points.size(),3):
		for offset in [0,1,2]:
			var index: int = triangle+offset
			st.set_normal(normals[index])
			st.set_uv(uv[index])
			st.add_vertex(points[index])
		for offset in [2,1,0]:
			var index: int = triangle+offset
			st.set_normal(-normals[index])
			st.set_uv(uv[index])
			st.add_vertex(points[index]-normals[index]*thickness)
		for offset in 3:
			var first: int = triangle+offset
			var last: int = triangle+(offset+1)%3
			var a := str(Vector3i((points[first]*1000000).round()))
			var b := str(Vector3i((points[last]*1000000).round()))
			var key := a+"|"+b if a<b else b+"|"+a
			if not edges.has(key): edges[key] = {"count":0,"first":first,"last":last}
			edges[key].count += 1
	for edge in edges.values():
		if edge.count!=1: continue
		var a: Vector3 = points[edge.first]
		var b: Vector3 = points[edge.last]
		var c: Vector3 = a-normals[edge.first]*thickness
		var d: Vector3 = b-normals[edge.last]*thickness
		var outward: Vector3 = (normals[edge.first]+normals[edge.last]).normalized().cross(b-a).normalized()
		st.set_normal(outward)
		MetalMesh.bevel_triangle(st,a,b,c,outward)
		MetalMesh.bevel_triangle(st,b,d,c,outward)
	return st.commit()

static func armor_plate(parent: Node3D, label: String, points: Array, color: Color) -> MeshInstance3D:
	var center := Vector3.ZERO
	for point: Vector3 in points: center += point
	center /= points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for index in points.size():
		var a: Vector3 = points[index]
		var b: Vector3 = points[(index+1)%points.size()]
		var inner_a := a.lerp(center,0.15)+Vector3(0,0,-0.006)
		var inner_b := b.lerp(center,0.15)+Vector3(0,0,-0.006)
		MetalMesh.bevel_triangle(st,center+Vector3(0,0,-0.018),inner_a,inner_b,Vector3.FORWARD)
		MetalMesh.bevel_triangle(st,a,b,inner_a,Vector3.FORWARD)
		MetalMesh.bevel_triangle(st,b,inner_b,inner_a,Vector3.FORWARD)
		var edge_out := ((a+b)*0.5-center).normalized()
		MetalMesh.bevel_triangle(st,a,a+Vector3(0,0,0.012),b,edge_out)
		MetalMesh.bevel_triangle(st,b,a+Vector3(0,0,0.012),b+Vector3(0,0,0.012),edge_out)
		MetalMesh.bevel_triangle(st,center+Vector3(0,0,0.012),b+Vector3(0,0,0.012),a+Vector3(0,0,0.012),Vector3.BACK)
	st.generate_normals()
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = st.commit()
	result.material_override = V.mat(color)
	result.material_override.metallic = 0.45
	result.material_override.roughness = 0.62
	parent.add_child(result)
	return result

static func blob(parent: Node3D, label: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var result := V.piece(parent,center,size,color,true)
	result.name = label
	result.mesh.radial_segments = 24
	result.mesh.rings = 12
	return result

static func boot(parent: Node3D) -> MeshInstance3D:
	# Normalized shoe coordinates retain the existing ankle/sole anchor and dimensions.
	# Closed bottom cap is a real planar sole, not the tangent point of an ellipsoid.
	var result := loft(parent,"ForestBoot",[
		Vector4(-0.50,0.48,0.49,0),Vector4(-0.34,0.50,0.50,0),
		Vector4(0.10,0.46,0.46,0.015),Vector4(0.40,0.37,0.35,0.10),
		Vector4(0.95,0.33,0.25,0.17),Vector4(1.35,0.34,0.25,0.17)
	],Color.WHITE,0,TAU,20)
	var arrays := result.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for point in vertices:
		var color := Color("303834")
		if point.y< -0.30: color = Color("171e1b")
		elif point.z< -0.20 and point.y<0.41: color = Color("626d63")
		elif point.y>0.94: color = Color("576356")
		colors.append(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.mesh = mesh
	result.material_override.vertex_color_use_as_albedo = true
	result.position = Vector3(0,-0.025,-0.06)
	result.scale = Vector3(0.18,0.15,0.30)
	return result

static func create(root: Node3D) -> Dictionary:
	var dark := Color("303735")
	var green := Color("4c5e45")
	var hem := Color("807a5e")
	var red := Color("7e4b3c")
	var skin := SKIN_TONE
	loft(root,"Undercoat",[
		Vector4(0.96,0.16,0.105,0),Vector4(1.07,0.15,0.10,0),Vector4(1.18,0.17,0.115,0),
		Vector4(1.31,0.205,0.13,-0.006),Vector4(1.40,0.22,0.12,0),Vector4(1.46,0.185,0.09,0),Vector4(1.49,0.08,0.065,0)
	],dark)
	loft(root,"Neck",[Vector4(1.46,0.055,0.052,0),Vector4(1.58,0.054,0.052,0)],skin)
	loft(root,"Collar",[Vector4(1.43,0.10,0.076,0),Vector4(1.52,0.076,0.065,0)],Color("3b463a"))
	ribbon(root,"CrossedCollar",[Vector3(-0.07,1.50,-0.067),Vector3(0.02,1.40,-0.13),Vector3(0.17,1.27,-0.094)],0.045,hem)
	ribbon(root,"InnerCollar",[Vector3(0.07,1.49,-0.075),Vector3(-0.01,1.39,-0.139),Vector3(-0.15,1.30,-0.106)],0.026,Color("656b59"))
	loft(root,"WaistSash",[Vector4(0.94,0.181,0.123,0),Vector4(1.025,0.177,0.12,0)],red)
	loft(root,"Belt",[Vector4(0.982,0.188,0.131,0),Vector4(1.012,0.184,0.127,0)],Color("34322b"))
	V.piece(root,Vector3(0.055,0.997,-0.133),Vector3(0.07,0.044,0.013),Color("928d74"))
	V.piece(root,Vector3(0.055,0.997,-0.141),Vector3(0.046,0.025,0.008),dark)
	var shoulders := {}
	for side in [-1,1]:
		var begin := 0.22 if side==1 else -PI+0.22
		var finish := PI-0.22 if side==1 else -0.22
		var cape := loft(root,"RainCape"+str(side),[
			Vector4(1.14,0.43,0.245,0.018),Vector4(1.25,0.385,0.225,0.018),
			Vector4(1.34,0.335,0.195,0.018),Vector4(1.39,0.30,0.17,0.012),
			Vector4(1.44,0.245,0.147,0.008),Vector4(1.49,0.10,0.08,0)
		],green,begin,finish,24,false)
		cape.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		cape.material_override.roughness = 0.92
		loft(root,"CapeHem"+str(side),[Vector4(1.141,0.431,0.246,0.018),Vector4(1.154,0.426,0.244,0.018)],hem,begin,finish,24,false).material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		var shoulder := loft(root,"ShoulderPlate"+str(side),[
			Vector4(-0.08,0.065,0.060,0),Vector4(-0.05,0.095,0.085,0),
			Vector4(0,0.110,0.095,0),Vector4(0.025,0.095,0.085,0),
			Vector4(0.045,0.070,0.065,0),Vector4(0.055,0.035,0.032,0),
			Vector4(0.058,0.008,0.008,0)
		],Color("626d61"),0 if side==1 else -PI,PI if side==1 else 0,24,false)
		shoulder.position = Vector3(side*0.27,1.43,0)
		shoulder.mesh = thicken_plate(shoulder.mesh,0.004)
		shoulder.material_override.metallic = 0.35
		shoulder.material_override.roughness = 0.65
		shoulders[side] = shoulder
		V.piece(root,Vector3(side*0.25,1.425,-0.085),Vector3(0.028,0.055,0.018),red)
	# Separate front panels allow the legs to swing and leave a central split.
	var skirts := {}
	for side in [-1,1]:
		var pivot := V.pivot(root,"Skirt"+str(side),Vector3(side*0.12,0.98,-0.10))
		patch(pivot,"CoatPanel",[Vector3(-0.105,0,-0.018),Vector3(0.105,0,-0.018),Vector3(0.12,-0.25,-0.075),Vector3(-0.08,-0.29,-0.068)],Color("77725a"))
		ribbon(pivot,"PanelTrim",[Vector3(side*0.09,-0.01,-0.021),Vector3(side*0.09,-0.23,-0.077)],0.015,red)
		skirts[side] = pivot
		var pouch := loft(root,"BeltPouch"+str(side),[Vector4(0.865,0.055,0.035,0),Vector4(1.00,0.06,0.035,0)],Color("67644d"),0,TAU,12)
		pouch.position = Vector3(side*0.215,0,0.04)
		V.piece(root,Vector3(side*0.215,0.96,-0.003),Vector3(0.035,0.045,0.015),Color("8b8b73"))
	V.piece(root,Vector3(0,1.30,0.15),Vector3(0.07,0.31,0.055),Color("586157"))
	V.piece(root,Vector3(0,1.45,0.18),Vector3(0.09,0.065,0.025),red)
	create_head(root,skin)
	var upper_parts: Array[MeshInstance3D] = []
	var lower_parts: Array[Node3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and (child.transform*child.get_aabb().get_center()).y>1.1: upper_parts.append(child)
		elif child is MeshInstance3D or child in skirts.values(): lower_parts.append(child)
	return {"skirts":skirts,"upper_parts":upper_parts,"lower_parts":lower_parts,"shoulders":shoulders}

static func create_head(root: Node3D, skin: Color) -> void:
	var first_part := root.get_child_count()
	loft(root,"Head",[
		Vector4(1.535,0.046,0.055,-0.008),Vector4(1.55,0.063,0.064,-0.012),Vector4(1.57,0.079,0.073,-0.012),Vector4(1.60,0.094,0.088,-0.01),Vector4(1.62,0.106,0.097,-0.009),
		Vector4(1.65,0.127,0.110,-0.003),Vector4(1.68,0.137,0.118,0),Vector4(1.705,0.139,0.119,0.002),Vector4(1.73,0.137,0.118,0.004),Vector4(1.76,0.135,0.119,0.008),Vector4(1.79,0.13,0.117,0.012),
		Vector4(1.85,0.105,0.093,0.015),Vector4(1.88,0.04,0.04,0.015)
	],skin,0,TAU,32)
	for side in [-1,1]:
		blob(root,"Ear"+str(side),Vector3(side*0.138,1.685,0.005),Vector3(0.045,0.078,0.035),skin.darkened(0.04))
		blob(root,"EyeWhite"+str(side),Vector3(side*0.056,1.712,-0.106),Vector3(0.042,0.014,0.008),Color("c4c1ac"))
		blob(root,"Iris"+str(side),Vector3(side*0.056,1.713,-0.111),Vector3(0.013,0.013,0.004),Color("332d24"))
		blob(root,"EyeGlint"+str(side),Vector3(side*0.053,1.716,-0.114),Vector3(0.003,0.003,0.002),Color("ddd7bd"))
		ribbon(root,"UpperLid"+str(side),[Vector3(side*0.033,1.713,-0.109),Vector3(side*0.056,1.720,-0.112),Vector3(side*0.079,1.714,-0.099)],0.0035,skin.darkened(0.18))
		ribbon(root,"LowerLid"+str(side),[Vector3(side*0.034,1.709,-0.109),Vector3(side*0.056,1.705,-0.112),Vector3(side*0.076,1.709,-0.102)],0.0025,skin.darkened(0.06))
		ribbon(root,"Brow"+str(side),[Vector3(side*0.025,1.744,-0.115),Vector3(side*0.056,1.75,-0.114),Vector3(side*0.086,1.74,-0.101)],0.006,Color("3c342b"))
	loft(root,"NoseBridge",[Vector4(1.655,0.013,0.011,-0.117),Vector4(1.669,0.017,0.012,-0.128),Vector4(1.686,0.013,0.011,-0.123),Vector4(1.720,0.008,0.008,-0.117),Vector4(1.732,0.004,0.006,-0.113)],skin,0,TAU,24)
	blob(root,"UpperLip",Vector3(0,1.634,-0.1085),Vector3(0.055,0.006,0.008),Color("9a7262"))
	blob(root,"LowerLip",Vector3(0,1.6285,-0.1085),Vector3(0.050,0.006,0.008),Color("b28a74"))
	create_hair(root)
	# Adult ranger proportions: reduce the head assembly around the neck joint,
	# preserving the face/hair registration and leaving the collar anchor intact.
	var scale := 0.86
	var pivot := Vector3(0,1.535,0)
	var proportion := Transform3D(Basis.from_scale(Vector3.ONE*scale),pivot*(1-scale))
	for index in range(first_part,root.get_child_count()):
		var part := root.get_child(index) as Node3D
		part.transform = proportion*part.transform
		part.set_meta("head_assembly",true)

static func create_hair(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var hair_color := Color("252b28")
	var rows := 16
	var segments := 64
	for row in rows:
		for column in segments:
			var vertices := []
			var colors := []
			for pair in [[row,column],[row+1,column],[row,column+1],[row+1,column+1]]:
				var fraction: float = float(pair[0])/rows
				var angle: float = float(pair[1])/segments*TAU
				var hairline := 1.69+0.10*pow((1-cos(angle))*0.5,2)+0.003*sin(angle*9)
				var height := lerpf(hairline,1.915,fraction)
				var radius := 0.145
				if height>1.79: radius = maxf(0.001,0.145*sqrt(maxf(0,1-pow((height-1.79)/0.125,2))))
				var flow := angle*24+fraction*5
				radius += 0.0035*sin(flow)*sin(fraction*PI)
				var nape := 0.016*(1-smoothstep(1.69,1.80,height))*maxf(0,cos(angle))
				vertices.append(Vector3(sin(angle)*radius,height,cos(angle)*radius*0.95+0.015-nape))
				var strand := pow(0.5+0.5*cos(flow),6)
				colors.append(hair_color.darkened(0.12).lerp(hair_color.lightened(0.08),strand))
			for index in [0,1,2,2,1,3]:
				st.set_color(colors[index])
				st.add_vertex(vertices[index])
	st.set_color(hair_color)
	for side in [-1,1]:
		var centers := [Vector3(side*0.077,1.81,-0.089),Vector3(side*0.105,1.78,-0.090),Vector3(side*0.128,1.74,-0.075),Vector3(side*0.129,1.695,-0.060),Vector3(side*0.126,1.665,-0.050)]
		var widths := [0.010,0.008,0.006,0.0035,0.0005]
		var rings: Array[PackedVector3Array] = []
		for index in centers.size():
			var tangent: Vector3 = (centers[mini(index+1,centers.size()-1)]-centers[maxi(0,index-1)]).normalized()
			var across := tangent.cross(Vector3.FORWARD).normalized()
			var around := tangent.cross(across).normalized()
			var ring := PackedVector3Array()
			for column in 9:
				var angle := float(column)/8*TAU
				ring.append(centers[index]+(across*cos(angle)+around*sin(angle))*float(widths[index]))
			rings.append(ring)
		for row in rings.size()-1:
			for column in 8:
				for cell in [Vector2i(row,column),Vector2i(row+1,column),Vector2i(row,column+1),Vector2i(row,column+1),Vector2i(row+1,column),Vector2i(row+1,column+1)]: st.add_vertex(rings[cell.x][cell.y])
	st.generate_normals()
	var hair := MeshInstance3D.new()
	hair.name = "HairCap"
	hair.mesh = st.commit()
	hair.material_override = V.mat(Color.WHITE)
	hair.material_override.vertex_color_use_as_albedo = true
	hair.material_override.roughness = 0.65
	root.add_child(hair)
	loft(root,"HairKnot",[Vector4(1.80,0.05,0.045,0.13),Vector4(1.86,0.085,0.07,0.15),Vector4(1.93,0.065,0.055,0.15),Vector4(1.96,0.02,0.02,0.14)],Color("282e2a"),0,TAU,24)
	loft(root,"HairTie",[Vector4(1.82,0.058,0.051,0.13),Vector4(1.835,0.06,0.052,0.13)],Color("71473b"),0,TAU,24)
