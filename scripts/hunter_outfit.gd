extends RefCounted
## Original mesh profiles for the approved wet-forest costume. No third-party meshes.
const V = preload("res://scripts/visuals.gd")
const Profiles = preload("res://scripts/creature_surface.gd")
const MetalMesh = preload("res://scripts/trident_mesh.gd")
const SKIN_TONE := Color("bd9b80")
const Face = preload("res://scripts/hunter_face.gd")

static func loft(parent: Node3D, label: String, rings: Array, color: Color, start := 0.0, end := TAU, segments := 28, caps := true) -> MeshInstance3D:
	var garment := label in ["Undercoat","TrouserThigh","TrouserShin"]
	if garment or label in ["Head","NoseBridge","HairKnot"] or label.begins_with("UpperArmSurface") or label.begins_with("RainCape"): rings = Profiles.smooth_profiles(rings)
	if label=="Head":
		# Sample the small lip relief without increasing density over the full scalp.
		var refined := []
		for row in range(rings.size()-1):
			var steps := 4 if rings[row].x>=1.62 and rings[row].x<1.65 else 1
			for step in steps: refined.append(Vector4(rings[row]).lerp(rings[row+1],float(step)/steps))
		refined.append(rings[-1])
		rings = refined
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
				if label=="ForestBoot": point = boot_shape(point)
				if garment: point = garment_drape(point,label,bottom,span)
				if label.begins_with("RainCape") or label.begins_with("CapeHem"): point = cape_drape(point)
				st.add_vertex(equipment_shape(point,label))
	if caps:
		st.set_smooth_group(-1)
		for row in [0,rings.size()-1]:
			# The exposed elbow is closed by the deforming joint skin; an upper-arm
			# end disk cuts across it when the forearm bends. Retain the shoulder cap.
			if label.begins_with("UpperArmSurface") and row==rings.size()-1: continue
			if label.begins_with("Bracer") and row==0:
				bracer_lining(st,rings[0],segments)
				continue
			if label.begins_with("Bracer") and row==rings.size()-1:
				bracer_wrist_lining(st,rings[row],segments)
				continue
			var ring: Vector4 = rings[row]
			var center := Vector3(0,ring.x,ring.w)
			for column in segments:
				var a := profile_point(ring,lerpf(start,end,float(column)/segments))
				var b := profile_point(ring,lerpf(start,end,float(column+1)/segments))
				for point in ([center,a,b] if row==0 else [center,b,a]):
					st.set_uv(Vector2(point.x/maxf(ring.y*2,0.0001)+0.5,(point.z-ring.w)/maxf(ring.z*2,0.0001)+0.5))
					if label=="ForestBoot": point = boot_shape(point)
					st.add_vertex(equipment_shape(point,label))
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	if label.begins_with("RainCape"): shoulder_ease(mesh,label)
	mesh.material_override = V.mat(color)
	if label.begins_with("Bracer") or label.begins_with("BeltPouch"): finish_equipment(mesh,label)
	parent.add_child(mesh)
	return mesh

static func bracer_plate(parent: MeshInstance3D) -> MeshInstance3D:
	# Keep the existing attachment and child order so saved skeletal clips remain valid.
	var result := V.piece(parent,Vector3(0,-0.06,-0.063),Vector3(0.065,0.28,0.012),Color("626d61"))
	result.scale = Vector3.ONE
	var outline := [Vector2(-0.028,-0.36),Vector2(0.028,-0.36),Vector2(0.043,-0.27),Vector2(0.035,0.22),Vector2(0.022,0.292),Vector2(-0.022,0.292),Vector2(-0.035,0.22),Vector2(-0.043,-0.27)]
	var shell := parent.mesh.generate_triangle_mesh()
	var edge: Array[Vector3] = []
	for point: Vector2 in outline:
		var sample := Vector3(point.x,point.y+result.position.y,0)
		var hit: Dictionary = shell.intersect_segment(sample+Vector3(0,0,-0.15),sample)
		assert(not hit.is_empty(),"Forearm plate must seat on bracer")
		edge.append(hit.position-result.position+Vector3(0,0,-0.001))
	var center := Vector3(0,0,-0.004)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for index in edge.size():
		var a := edge[index]
		var b := edge[(index+1)%edge.size()]
		var inner_a := a.lerp(center,0.18)+Vector3(0,0,-0.002)
		var inner_b := b.lerp(center,0.18)+Vector3(0,0,-0.002)
		st.set_color(Color("c4cec6"))
		MetalMesh.bevel_triangle(st,center,inner_a,inner_b,Vector3.FORWARD)
		st.set_color(Color.WHITE)
		MetalMesh.bevel_triangle(st,a,b,inner_a,Vector3.FORWARD)
		MetalMesh.bevel_triangle(st,b,inner_b,inner_a,Vector3.FORWARD)
		st.set_color(Color("84938a"))
		var back := Vector3(0,0,0.004)
		var outward := ((a+b)*0.5-center).normalized()
		MetalMesh.bevel_triangle(st,a,a+back,b,outward)
		MetalMesh.bevel_triangle(st,b,a+back,b+back,outward)
		MetalMesh.bevel_triangle(st,center+back,b+back,a+back,Vector3.BACK)
	st.generate_normals()
	result.mesh = st.commit()
	result.material_override.vertex_color_use_as_albedo = true
	result.material_override.metallic = 0.45
	result.material_override.roughness = 0.62
	finish_metal(result,Vector2(0.20,0.20),Vector3(1,0.39,1))
	return result

static func bracer_wrist_lining(tool: SurfaceTool, ring: Vector4, segments: int) -> void:
	# A hollow wrist cuff leaves the glove connector inside its visible rim.
	var inner := Vector4(ring.x,0.039,0.036,ring.w)
	for column in segments:
		var angle := TAU*float(column)/segments
		var next := TAU*float(column+1)/segments
		var a := profile_point(ring,angle)
		var b := profile_point(ring,next)
		var c := profile_point(inner,angle)
		var d := profile_point(inner,next)
		tool.set_uv(Vector2(float(column)/segments,1))
		MetalMesh.bevel_triangle(tool,a,c,b,Vector3.UP)
		MetalMesh.bevel_triangle(tool,b,c,d,Vector3.UP)
		var e := c-Vector3(0,0.08,0)
		var f := d-Vector3(0,0.08,0)
		var inward := -Vector3(sin(angle),0,cos(angle))
		MetalMesh.bevel_triangle(tool,c,e,d,inward)
		MetalMesh.bevel_triangle(tool,d,e,f,inward)

static func bracer_lining(tool: SurfaceTool, ring: Vector4, segments: int) -> void:
	# A real annular cuff and short inner wall replace the solid end disk.
	for column in segments:
		var angle := TAU*float(column)/segments
		var next := TAU*float(column+1)/segments
		var a := profile_point(ring,angle)
		var b := profile_point(ring,next)
		var inner := Vector4(ring.x,0.043,0.040,ring.w)
		var c := profile_point(inner,angle)
		var d := profile_point(inner,next)
		tool.set_uv(Vector2(float(column)/segments,0))
		MetalMesh.bevel_triangle(tool,a,b,c,Vector3.DOWN)
		MetalMesh.bevel_triangle(tool,b,d,c,Vector3.DOWN)
		var e := c+Vector3(0,0.16,0)
		var f := d+Vector3(0,0.16,0)
		var inward := -Vector3(sin(angle),0,cos(angle))
		MetalMesh.bevel_triangle(tool,c,d,e,inward)
		MetalMesh.bevel_triangle(tool,d,f,e,inward)

static func equipment_shape(point: Vector3, label: String) -> Vector3:
	if label.begins_with("BeltPouch"):
		# Rounded rectangular leather panels, with the original circular UV and anchors.
		var angle := atan2(point.x/0.06,point.z/0.035)
		var radius := Vector2(point.x/0.06,point.z/0.035).length()
		point.x = sign(sin(angle))*pow(absf(sin(angle)),0.45)*0.06*radius
		point.z = sign(cos(angle))*pow(absf(cos(angle)),0.45)*0.035*radius
	return point

static func finish_equipment(part: MeshInstance3D, label: String) -> void:
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var shade := Color.WHITE
		if label.begins_with("Bracer"):
			var cuff := point.y< -0.40 or point.y>0.16
			shade = Color("c75f47") if cuff else Color("d6dfd5")
			var panel := smoothstep(0.015,0.045,-point.z)*(1-smoothstep(0.38,0.45,absf(point.y)))
			shade = shade.lerp(Color("79877f"),panel*0.65)
		else:
			shade = Color("e1d6b8") if point.y>0.972 else Color("c0b59b")
			if point.y>0.957 and point.y<0.972: shade = Color("716653")
		colors.append(shade)
	arrays[Mesh.ARRAY_COLOR] = colors
	var detailed := ArrayMesh.new()
	detailed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	part.mesh = detailed
	part.material_override.vertex_color_use_as_albedo = true
	part.material_override.roughness = 0.58 if label.begins_with("Bracer") else 0.86
	part.material_override.metallic = 0.30 if label.begins_with("Bracer") else 0.0
	if label.begins_with("BeltPouch"): pouch_stitches(part)

static func pouch_stitches(part: MeshInstance3D) -> void:
	var surface := part.mesh.generate_triangle_mesh()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(part.mesh,0,Transform3D.IDENTITY)
	var paths := [[Vector2(-0.040,0.960),Vector2(-0.042,0.940),Vector2(-0.042,0.895),Vector2(-0.032,0.884),Vector2(0.032,0.884),Vector2(0.042,0.895),Vector2(0.042,0.940),Vector2(0.040,0.960)],[Vector2(-0.040,0.982),Vector2(-0.020,0.986),Vector2(0.020,0.986),Vector2(0.040,0.982)]]
	for path: Array in paths:
		for segment in range(path.size()-1):
			var a: Vector2 = path[segment]
			var b: Vector2 = path[segment+1]
			var steps := ceili(a.distance_to(b)/0.004)
			var across := Vector2(-(b-a).y,(b-a).x).normalized()*0.00045
			for step in steps:
				var first := a.lerp(b,float(step)/steps)
				var last := a.lerp(b,(step+0.58)/steps)
				var corners: Array[Vector3] = []
				for point: Vector2 in [first-across,first+across,last+across,last-across]:
					var hit := surface.intersect_segment(Vector3(point.x,point.y,-1),Vector3(point.x,point.y,1))
					assert(not hit.is_empty(),"Pouch stitching needs a real leather surface")
					corners.append(hit.position+Vector3(0,0,-0.0006))
				var back := Vector3(0,0,0.0008)
				tool.set_color(Color("f1e5c6"))
				tool.set_normal(Vector3.FORWARD)
				MetalMesh.bevel_triangle(tool,corners[0],corners[1],corners[2],Vector3.FORWARD)
				MetalMesh.bevel_triangle(tool,corners[0],corners[2],corners[3],Vector3.FORWARD)
				tool.set_normal(Vector3.BACK)
				MetalMesh.bevel_triangle(tool,corners[0]+back,corners[2]+back,corners[1]+back,Vector3.BACK)
				MetalMesh.bevel_triangle(tool,corners[0]+back,corners[3]+back,corners[2]+back,Vector3.BACK)
				var center := (corners[0]+corners[1]+corners[2]+corners[3])*0.25
				for edge in 4:
					var p := corners[edge]
					var q := corners[(edge+1)%4]
					var outward := Vector3((p.x+q.x)*0.5-center.x,(p.y+q.y)*0.5-center.y,0).normalized()
					tool.set_normal(outward)
					MetalMesh.bevel_triangle(tool,p,p+back,q,outward)
					MetalMesh.bevel_triangle(tool,q,p+back,q+back,outward)
	part.mesh = tool.commit()

static func shoulder_ease(part: MeshInstance3D, label: String) -> void:
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var side := -1.0 if label.ends_with("-1") else 1.0
	for i in points.size():
		var weight := smoothstep(0.14,0.27,absf(points[i].x))*smoothstep(1.22,1.40,points[i].y)*(1-smoothstep(1.46,1.53,points[i].y))*(1-smoothstep(-0.08,0.04,points[i].z))
		points[i] += Vector3(side*0.012,0,-0.06)*weight
	var expanded: Array = arrays.duplicate(true)
	expanded[Mesh.ARRAY_VERTEX] = points
	var temp := ArrayMesh.new()
	temp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,expanded)
	var tool := SurfaceTool.new()
	tool.create_from(temp,0)
	tool.generate_normals()
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = points
	shape[Mesh.ARRAY_NORMAL] = tool.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	result.add_blend_shape("ShoulderEase")
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape])
	part.mesh = result

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
					# Use panel coordinates for both cloth and trim, keeping their rounded
					# free edges registered while the waist remains unchanged.
					var across := clampf((point.x+0.105)/0.225,0,1)
					point.y += (0.018*pow(absf(across*2-1),4)-0.012*sin(across*PI))*smoothstep(0.70,1,hang)
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

static func fitted_collar(parent: Node3D, label: String, points: Array, width: float, color: Color) -> MeshInstance3D:
	var coat: MeshInstance3D = parent.get_node("Undercoat")
	var triangles := coat.mesh.generate_triangle_mesh()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rows: Array[PackedVector3Array] = []
	for segment in range(points.size()-1):
		for step in 13:
			if segment>0 and step==0: continue
			var t := float(step)/12
			var center: Vector3 = points[segment].lerp(points[segment+1],t)
			var before: Vector3 = points[maxi(segment-1,0)]
			var after: Vector3 = points[mini(segment+2,points.size()-1)]
			var tangent: Vector3 = (points[segment+1]-before).lerp(after-points[segment],t).normalized()
			var across := Vector3(-tangent.y,tangent.x,0).normalized()
			var row := PackedVector3Array()
			for column in 5:
				var point := center+across*width*(float(column)/4-0.5)
				var local := coat.transform.affine_inverse()*point
				var hit := triangles.intersect_segment(Vector3(local.x,local.y,-1),Vector3(local.x,local.y,1))
				if not hit.is_empty():
					var across_t := float(column)/4
					var rolled_edge := 0.001*pow(absf(across_t*2-1),3)
					var layer_gap := 0.0065 if label=="CrossedCollar" else 0.0035
					point = coat.transform*hit.position-Vector3(0,0,layer_gap+rolled_edge)
				row.append(point)
			rows.append(row)
	for row in range(rows.size()-1):
		for column in 4:
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				st.set_uv(Vector2(float(column+corner.y)/4,float(row+corner.x)/(rows.size()-1)))
				st.add_vertex(rows[row+corner.x][column+corner.y])
	st.generate_normals()
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = st.commit()
	result.material_override = V.mat(color)
	result.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(result)
	return result

static func ribbon(parent: Node3D, label: String, points: Array, width: float, color: Color) -> MeshInstance3D:
	if label in ["CrossedCollar","InnerCollar"]:
		return fitted_collar(parent,label,points,width,color)
	var outline := []
	var reverse := []
	for index in points.size():
		var before: Vector3 = points[maxi(0,index-1)]
		var after: Vector3 = points[mini(points.size()-1,index+1)]
		var tangent := (after-before).normalized()
		var taper := 1.0
		if label.begins_with("Brow"):
			var across := float(index)/maxi(1,points.size()-1)
			taper = 0.20+0.80*pow(sin(across*PI),0.5)
		var normal := Vector3(-tangent.y,tangent.x,0)*width*0.5*taper
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

static func finish_metal(part: MeshInstance3D, tile := Vector2(0.20,0.20), physical_scale := Vector3.ONE) -> void:
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var uv := PackedVector2Array()
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		uv.append(Vector2(point.x*physical_scale.x/tile.x,point.y*physical_scale.y/tile.y)+Vector2(0.5,0.5))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	part.mesh = mesh
	part.material_override.albedo_texture = preload("res://assets/textures/armor/ranger-metal-albedo.png")
	part.material_override.roughness_texture = preload("res://assets/textures/armor/ranger-metal-roughness.png")
	part.material_override.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

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
		st.set_color(Color("c4cec6"))
		st.set_smooth_group(0)
		# Four curved rings replace a single broad triangular face. Keep the
		# same solid rim and maximum rise so the armor retains its clearance.
		for row in 4:
			var t0 := float(row)/4
			var t1 := float(row+1)/4
			var a0 := center.lerp(inner_a,t0)+Vector3(0,0,-0.018*(1-t0*t0))
			var b0 := center.lerp(inner_b,t0)+Vector3(0,0,-0.018*(1-t0*t0))
			var a1 := center.lerp(inner_a,t1)+Vector3(0,0,-0.018*(1-t1*t1))
			var b1 := center.lerp(inner_b,t1)+Vector3(0,0,-0.018*(1-t1*t1))
			MetalMesh.bevel_triangle(st,a0,a1,b1,Vector3.FORWARD)
			if row>0: MetalMesh.bevel_triangle(st,a0,b1,b0,Vector3.FORWARD)
		st.set_smooth_group(-1)
		st.set_color(Color.WHITE)
		MetalMesh.bevel_triangle(st,a,b,inner_a,Vector3.FORWARD)
		MetalMesh.bevel_triangle(st,b,inner_b,inner_a,Vector3.FORWARD)
		st.set_color(Color("84938a"))
		var edge_out := ((a+b)*0.5-center).normalized()
		MetalMesh.bevel_triangle(st,a,a+Vector3(0,0,0.012),b,edge_out)
		MetalMesh.bevel_triangle(st,b,a+Vector3(0,0,0.012),b+Vector3(0,0,0.012),edge_out)
		MetalMesh.bevel_triangle(st,center+Vector3(0,0,0.012),b+Vector3(0,0,0.012),a+Vector3(0,0,0.012),Vector3.BACK)
	st.generate_normals()
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = st.commit()
	result.material_override = V.mat(color)
	result.material_override.vertex_color_use_as_albedo = true
	result.material_override.metallic = 0.45
	result.material_override.roughness = 0.62
	finish_metal(result)
	parent.add_child(result)
	return result

static func shin_straps(plate: MeshInstance3D, cloth: MeshInstance3D) -> void:
	var surface := cloth.mesh.generate_triangle_mesh()
	var arrays: Array = plate.mesh.surface_get_arrays(0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		tool.set_color(arrays[Mesh.ARRAY_COLOR][index])
		tool.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
		tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][index])
	var base: Color = plate.material_override.albedo_color
	var leather := Color("624532")
	tool.set_color(Color(leather.r/base.r,leather.g/base.g,leather.b/base.b))
	tool.set_smooth_group(0)
	for height in [-0.16,-0.27]:
		for segment in 32:
			var corners: Array[Vector3] = []
			for end in 2:
				var angle := TAU*float(segment+end)/32
				var radial := Vector3(sin(angle),0,cos(angle))
				for edge in 2:
					var y: float = height+(-0.011 if edge==0 else 0.011)
					var hit: Dictionary = surface.intersect_segment(Vector3(0,y,0)+radial*0.15,Vector3(0,y,0))
					assert(not hit.is_empty(),"Shin straps must seat on the trouser surface")
					corners.append(hit.position+radial*0.0028)
					corners.append(hit.position+radial*0.0006)
			# Two radial walls and two narrow bound edges make each strip closed.
			for face in [[0,4,2,6],[1,3,5,7],[0,1,4,5],[2,6,3,7]]:
				var a: Vector3 = corners[face[0]]
				var b: Vector3 = corners[face[1]]
				var c: Vector3 = corners[face[2]]
				var d: Vector3 = corners[face[3]]
				var normal := (b-a).cross(c-a).normalized()
				MetalMesh.bevel_triangle(tool,a,b,c,normal)
				MetalMesh.bevel_triangle(tool,b,d,c,normal)
	# Preserve the already generated plate normals; only the new strips need
	# explicit flat normals, emitted by bevel_triangle.
	plate.mesh = tool.commit()
	finish_metal(plate)

static func blob(parent: Node3D, label: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var result := V.piece(parent,center,size,color,true)
	result.name = label
	result.mesh.radial_segments = 24
	result.mesh.rings = 12
	return result

static func shoulder_plate(root: Node3D, side: int) -> MeshInstance3D:
	# A folded shield with a rolled crown, rather than a round joint cover.
	# The symmetric outline keeps front/back registration on both mirrored arms.
	var plate := armor_plate(root,"ShoulderPlate"+str(side),[
		Vector3(-0.085,-0.065,0),Vector3(-0.085,0.015,0.008),
		Vector3(-0.045,0.060,0.025),Vector3(0,0.075,0.030),
		Vector3(0.045,0.060,0.025),Vector3(0.085,0.015,0.008),
		Vector3(0.085,-0.065,0),Vector3(0,-0.095,-0.005)
	],Color("626d61"))
	shoulder_fasteners(plate)
	var arrays: Array = plate.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := Basis(Vector3.UP,-side*PI/2)
	for index in vertices.size():
		vertices[index] = turn*vertices[index]+Vector3(side*0.115,0,0)
		normals[index] = turn*normals[index]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	plate.mesh = mesh
	plate.position = Vector3(side*0.27,1.43,0)
	plate.material_override.metallic = 0.35
	plate.material_override.roughness = 0.65
	return plate

static func shoulder_fasteners(plate: MeshInstance3D) -> void:
	# Integrate the concept's two dark-red retention tabs into the existing
	# shoulder attachment, keeping bone order and all saved animation paths.
	var arrays: Array = plate.mesh.surface_get_arrays(0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		tool.set_color(arrays[Mesh.ARRAY_COLOR][index])
		tool.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
		tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][index])
	var metal: Color = plate.material_override.albedo_color
	var leather := Color("604034")
	for side in [-1,1]:
		var center_x: float = side*0.045
		var outline: Array[Vector3] = [Vector3(center_x-0.012,-0.035,-0.022),Vector3(center_x+0.012,-0.035,-0.022),Vector3(center_x+0.012,-0.099,-0.022),Vector3(center_x+0.007,-0.105,-0.022),Vector3(center_x-0.007,-0.105,-0.022),Vector3(center_x-0.012,-0.099,-0.022)]
		var center := Vector3(center_x,-0.070,-0.022)
		tool.set_color(Color(leather.r/metal.r,leather.g/metal.g,leather.b/metal.b))
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index+1)%outline.size()]
			var back := Vector3(0,0,0.004)
			MetalMesh.bevel_triangle(tool,center,a,b,Vector3.FORWARD)
			MetalMesh.bevel_triangle(tool,center+back,b+back,a+back,Vector3.BACK)
			var outward := ((a+b)*0.5-center).normalized()
			MetalMesh.bevel_triangle(tool,a,a+back,b,outward)
			MetalMesh.bevel_triangle(tool,b,a+back,b+back,outward)
		# A small domed metal rivet binds the strap near the lower plate edge.
		tool.set_color(Color("d6c9a9"))
		var rivet := Vector3(center_x,-0.048,-0.024)
		for segment in 16:
			var angle := TAU*float(segment)/16
			var next := TAU*float(segment+1)/16
			var a := rivet+Vector3(cos(angle),sin(angle),0)*0.0035
			var b := rivet+Vector3(cos(next),sin(next),0)*0.0035
			MetalMesh.bevel_triangle(tool,rivet+Vector3(0,0,-0.0015),a,b,Vector3.FORWARD)
			MetalMesh.bevel_triangle(tool,rivet+Vector3(0,0,0.001),b,a,Vector3.BACK)
	plate.mesh = tool.commit()
	finish_metal(plate)

static func boot_shape(point: Vector3) -> Vector3:
	# A narrower heel and fuller forefoot read as footwear, rather than a tube.
	# Fade above the welt so the original broad planar sole is unchanged.
	var heel := smoothstep(0.02,0.35,point.z)*smoothstep(-0.30,0.05,point.y)
	point.x *= 1-0.22*heel
	return point

static func boot(parent: Node3D) -> MeshInstance3D:
	# Normalized shoe coordinates retain the existing ankle/sole anchor and dimensions.
	# Closed bottom cap is a real planar sole, not the tangent point of an ellipsoid.
	var result := loft(parent,"ForestBoot",[
		Vector4(-0.50,0.48,0.49,0),Vector4(-0.43,0.50,0.50,0),
		Vector4(-0.32,0.50,0.50,0),Vector4(-0.24,0.47,0.48,0),
		Vector4(0.04,0.46,0.46,0.015),Vector4(0.14,0.45,0.45,0.015),
		Vector4(0.26,0.41,0.40,0.05),Vector4(0.43,0.35,0.31,0.13),
		Vector4(0.54,0.33,0.27,0.16),Vector4(0.61,0.34,0.28,0.16),
		Vector4(0.71,0.34,0.28,0.16),Vector4(0.77,0.32,0.25,0.17),
		Vector4(1.13,0.32,0.25,0.17),Vector4(1.20,0.35,0.28,0.17),
		Vector4(1.35,0.35,0.28,0.17)
	],Color.WHITE,0,TAU,28)
	var arrays := result.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for point in vertices:
		var color := Color("303834")
		if point.y< -0.32: color = Color("171e1b")
		elif point.y< -0.24: color = Color("665f49")
		elif point.z< -0.18 and point.y<0.27: color = Color("626d63")
		elif point.y>=0.61 and point.y<=0.71: color = Color("59473a")
		elif point.y>=1.20: color = Color("65705e")
		elif point.y>0.20 and point.z<0 and absf(point.x)<0.19: color = Color("504b3c")
		colors.append(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.mesh = mesh
	result.material_override.vertex_color_use_as_albedo = true
	result.position = Vector3(0,-0.025,-0.06)
	result.scale = Vector3(0.18,0.15,0.30)
	boot_details(result)
	return result

static func boot_details(part: MeshInstance3D) -> void:
	# Build small closed leather ribbons on the actual shoe, in the same mesh and
	# bone binding. Ray seating follows the rising instep rather than a flat decal.
	var surface := part.mesh.generate_triangle_mesh()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var original: Array = part.mesh.surface_get_arrays(0)
	for index in original[Mesh.ARRAY_VERTEX].size():
		tool.set_uv(original[Mesh.ARRAY_TEX_UV][index])
		tool.set_color(original[Mesh.ARRAY_COLOR][index])
		tool.set_normal(original[Mesh.ARRAY_NORMAL][index])
		tool.add_vertex(original[Mesh.ARRAY_VERTEX][index])
	tool.set_smooth_group(-1)
	for row in 5:
		var height := 0.28+row*0.16
		for direction in [-1,1]:
			var a := Vector2(-0.18,height+(0.10 if direction==1 else 0))
			var b := Vector2(0.18,height+(0.10 if direction==-1 else 0))
			boot_ribbon(tool,surface,a,b,0.008,Color("79684d"),0.006 if direction==1 else 0.011)
	# A stitched toe cap border sits below the lacing and follows the vamp curve.
	boot_ribbon(tool,surface,Vector2(-0.34,0.10),Vector2(0.34,0.10),0.009,Color("81765e"))
	tool.generate_normals()
	part.mesh = tool.commit()

static func boot_ribbon(tool: SurfaceTool, surface: TriangleMesh, a: Vector2, b: Vector2, width: float, color: Color, lift := 0.006) -> void:
	var sideways := (b-a).normalized().orthogonal()*width
	for step in 12:
		var p := a.lerp(b,float(step)/12)
		var q := a.lerp(b,float(step+1)/12)
		var points: Array[Vector3] = []
		for sample: Vector2 in [p-sideways,p+sideways,q+sideways,q-sideways]:
			var hit: Dictionary = surface.intersect_segment(Vector3(sample.x,sample.y,-1),Vector3(sample.x,sample.y,1))
			assert(not hit.is_empty(),"Boot stitching must sit on the shoe")
			points.append(hit.position+Vector3(0,0,-lift))
		tool.set_color(color)
		MetalMesh.bevel_triangle(tool,points[0],points[1],points[2],Vector3.FORWARD)
		MetalMesh.bevel_triangle(tool,points[0],points[2],points[3],Vector3.FORWARD)
		var back := Vector3(0,0,0.008)
		MetalMesh.bevel_triangle(tool,points[0]+back,points[2]+back,points[1]+back,Vector3.BACK)
		MetalMesh.bevel_triangle(tool,points[0]+back,points[3]+back,points[2]+back,Vector3.BACK)
		for edge in 4:
			var first := points[edge]
			var second := points[(edge+1)%4]
			var outward := Vector3((second-first).y,-(second-first).x,0).normalized()
			MetalMesh.bevel_triangle(tool,first,first+back,second,outward)
			MetalMesh.bevel_triangle(tool,second,first+back,second+back,outward)

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
	ribbon(root,"CrossedCollar",[Vector3(-0.07,1.47,-0.067),Vector3(0,1.40,-0.13),Vector3(0.10,1.32,-0.106)],0.030,Color("666952"))
	ribbon(root,"InnerCollar",[Vector3(0.07,1.47,-0.075),Vector3(0.012,1.412,-0.139),Vector3(-0.012,1.392,-0.132)],0.024,Color("454e41"))
	loft(root,"WaistSash",[Vector4(0.94,0.181,0.123,0),Vector4(1.025,0.177,0.12,0)],red)
	loft(root,"Belt",[Vector4(0.982,0.188,0.131,0),Vector4(1.012,0.184,0.127,0)],Color("34322b"))
	V.piece(root,Vector3(0.055,0.997,-0.133),Vector3(0.07,0.044,0.013),Color("928d74"))
	V.piece(root,Vector3(0.055,0.997,-0.141),Vector3(0.046,0.025,0.008),dark)
	var shoulders := {}
	var fasteners := {}
	for side in [-1,1]:
		var begin := 0.22 if side==1 else -PI+0.22
		var finish := PI-0.22 if side==1 else -0.22
		var cape := loft(root,"RainCape"+str(side),[
			Vector4(1.14,0.43,0.245,0.018),Vector4(1.25,0.385,0.225,0.018),
			Vector4(1.34,0.35,0.195,0.018),Vector4(1.39,0.34,0.18,0.012),
			Vector4(1.44,0.34,0.16,0.008),Vector4(1.48,0.34,0.14,0.004),
			Vector4(1.515,0.23,0.10,0),Vector4(1.53,0.10,0.08,0)
		],green,begin,finish,24,false)
		cape.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		cape.material_override.roughness = 0.92
		loft(root,"CapeHem"+str(side),[Vector4(1.141,0.431,0.246,0.018),Vector4(1.154,0.426,0.244,0.018)],hem,begin,finish,24,false).material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		var shoulder := shoulder_plate(root,side)
		shoulders[side] = shoulder
		var fastener := V.piece(root,shoulder.position+Vector3(side*0.093,-0.025,0),Vector3(0.006,0.055,0.022),red)
		fastener.name = "ShoulderFastener"+str(side)
		fastener.set_meta("shoulder_bind",shoulder.transform.affine_inverse()*fastener.transform)
		fasteners[side] = fastener
	# Separate front panels allow the legs to swing and leave a central split.
	var skirts := {}
	for side in [-1,1]:
		var pivot := V.pivot(root,"Skirt"+str(side),Vector3(side*0.12,0.98,-0.10))
		patch(pivot,"CoatPanel",[Vector3(-0.105,0,-0.018),Vector3(0.105,0,-0.018),Vector3(0.12,-0.25,-0.075),Vector3(-0.08,-0.29,-0.068)],Color("77725a"))
		ribbon(pivot,"PanelTrim",[Vector3(side*0.09,-0.01,-0.021),Vector3(side*0.09,-0.23,-0.077)],0.015,red)
		skirts[side] = pivot
		var pouch := loft(root,"BeltPouch"+str(side),[Vector4(0.865,0.043,0.025,0),Vector4(0.875,0.055,0.034,0),Vector4(0.950,0.060,0.035,0),Vector4(0.960,0.057,0.032,0),Vector4(0.970,0.061,0.037,0),Vector4(0.992,0.061,0.037,0),Vector4(1.00,0.055,0.030,0)],Color("67644d"),0,TAU,48)
		pouch.position = Vector3(side*0.215,0,0.04)
		var clasp := V.piece(root,Vector3(side*0.215,0.96,-0.003),Vector3(0.035,0.045,0.015),Color("8b8b73"))
		clasp.mesh = preload("res://scripts/equipment_box.gd").create(Vector3(0.035,0.045,0.015),0.002)
		clasp.scale = Vector3.ONE
		clasp.material_override.metallic = 0.45
		clasp.material_override.roughness = 0.62
		finish_metal(clasp)
	back_mount(root)
	create_head(root,skin)
	var upper_parts: Array[MeshInstance3D] = []
	var lower_parts: Array[Node3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and (child.transform*child.get_aabb().get_center()).y>1.1: upper_parts.append(child)
		elif child is MeshInstance3D or child in skirts.values(): lower_parts.append(child)
	return {"skirts":skirts,"upper_parts":upper_parts,"lower_parts":lower_parts,"shoulders":shoulders,"fasteners":fasteners}

static func back_mount(root: Node3D) -> void:
	# Same shaft axis as the sheathed weapon. Side-open saddles release toward
	# the existing positive-X equipment arc rather than enclosing the shaft.
	var carry := Transform3D(Basis(Vector3.BACK,0.35),Vector3(0,1.05,0.26))
	var center := carry*Vector3(-0.06,0.50,0)
	var rail := V.piece(root,Vector3(center.x,center.y,center.z),Vector3(0.055,0.24,0.10),Color("586157"))
	rail.name = "BackMountRail"
	rail.rotation.z = 0.35
	rail.mesh = preload("res://scripts/equipment_box.gd").create(Vector3(0.055,0.24,0.10),0.004)
	rail.scale = Vector3.ONE
	# Two short stand-offs visibly secure the raised rail through the cape to
	# the upper-back harness; combine them into the existing rail skin part.
	var support := SurfaceTool.new()
	support.begin(Mesh.PRIMITIVE_TRIANGLES)
	support.append_from(rail.mesh,0,Transform3D.IDENTITY)
	for pair in [[Vector3(-0.12,1.44,0.10),Vector3(-0.16,1.60,0.15)],[Vector3(-0.16,1.60,0.15),carry*Vector3(-0.06,0.60,0)],[Vector3(-0.16,1.44,0.07),Vector3(-0.20,1.58,0.16)],[Vector3(-0.20,1.58,0.16),carry*Vector3(-0.08,0.48,0)]]:
		var axis: Vector3 = pair[1]-pair[0]
		var strut := Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())),(pair[0]+pair[1])*0.5)
		var fitting := preload("res://scripts/equipment_box.gd").create(Vector3(0.018,axis.length(),0.018),0.0025)
		support.append_from(fitting,0,rail.transform.affine_inverse()*strut)
	rail.mesh = support.commit()
	rail.material_override.metallic = 0.35
	rail.material_override.roughness = 0.62
	finish_metal(rail)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for seat in [0.40,0.60]:
		for segment in 24:
			var a := deg_to_rad(70+220*float(segment)/24)
			var b := deg_to_rad(70+220*float(segment+1)/24)
			# Inner wall, outer wall, and both axial faces form a solid open clip.
			for face in 4:
				var corners: Array[Vector3] = []
				for pair in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
					var angle := lerpf(a,b,pair.x)
					var radius := 0.033 if face==0 else (0.045 if face==1 else lerpf(0.033,0.045,pair.y))
					var y := lerpf(-0.018,0.018,pair.y) if face<2 else (-0.018 if face==2 else 0.018)
					corners.append(carry*Vector3(cos(angle)*radius,seat+y,sin(angle)*radius))
				var radial := Vector3(cos((a+b)/2),0,sin((a+b)/2))
				var outward := carry.basis*(-radial if face==0 else (radial if face==1 else (Vector3.DOWN if face==2 else Vector3.UP)))
				MetalMesh.bevel_triangle(st,corners[0],corners[1],corners[2],outward)
				MetalMesh.bevel_triangle(st,corners[0],corners[2],corners[3],outward)
		for angle in [deg_to_rad(70),deg_to_rad(290)]:
			var corners: Array[Vector3] = []
			for pair in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var radius := lerpf(0.033,0.045,pair.x)
				corners.append(carry*Vector3(cos(angle)*radius,seat+lerpf(-0.018,0.018,pair.y),sin(angle)*radius))
			var outward := carry.basis*Vector3(-sin(angle),0,cos(angle))*(1.0 if angle<PI else -1.0)
			MetalMesh.bevel_triangle(st,corners[0],corners[1],corners[2],outward)
			MetalMesh.bevel_triangle(st,corners[0],corners[2],corners[3],outward)
	st.generate_normals()
	var clips := MeshInstance3D.new()
	clips.name = "BackMountClips"
	clips.mesh = st.commit()
	clips.material_override = V.mat(Color("777c70"))
	clips.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	clips.material_override.metallic = 0.50
	clips.material_override.roughness = 0.58
	finish_metal(clips)
	root.add_child(clips)

static func create_head(root: Node3D, skin: Color) -> void:
	var first_part := root.get_child_count()
	loft(root,"Head",[
		Vector4(1.535,0.046,0.055,-0.008),Vector4(1.55,0.063,0.064,-0.012),Vector4(1.57,0.079,0.073,-0.012),Vector4(1.60,0.094,0.088,-0.01),Vector4(1.62,0.106,0.097,-0.009),
		Vector4(1.65,0.127,0.110,-0.003),Vector4(1.68,0.137,0.118,0),Vector4(1.705,0.139,0.119,0.002),Vector4(1.73,0.137,0.118,0.004),Vector4(1.76,0.135,0.119,0.008),Vector4(1.79,0.13,0.117,0.012),
		Vector4(1.85,0.105,0.093,0.015),Vector4(1.88,0.04,0.04,0.015)
	],skin,0,TAU,160)
	for side in [-1,1]:
		blob(root,"Ear"+str(side),Vector3(side*0.138,1.685,0.005),Vector3(0.045,0.078,0.035),skin.darkened(0.04))
		blob(root,"EyeWhite"+str(side),Vector3(side*0.056,1.712,-0.106),Vector3(0.042,0.014,0.008),Color("c4c1ac"))
		blob(root,"Iris"+str(side),Vector3(side*0.056,1.713,-0.111),Vector3(0.016,0.013,0.004),Color("332d24"))
		blob(root,"EyeGlint"+str(side),Vector3(side*0.053,1.716,-0.114),Vector3(0.0018,0.0018,0.0014),Color("ddd7bd"))
		Face.create_lid(root,"UpperLid"+str(side),skin)
		Face.create_lid(root,"LowerLid"+str(side),skin)
		ribbon(root,"Brow"+str(side),[Vector3(side*0.025,1.744,-0.115),Vector3(side*0.039,1.747,-0.115),Vector3(side*0.054,1.748,-0.114),Vector3(side*0.069,1.745,-0.108),Vector3(side*0.086,1.739,-0.101)],0.005,Color("494036"))
	loft(root,"NoseBridge",[Vector4(1.652,0.004,0.005,-0.117),Vector4(1.658,0.015,0.009,-0.121),Vector4(1.667,0.018,0.013,-0.126),Vector4(1.676,0.015,0.012,-0.126),Vector4(1.691,0.011,0.009,-0.120),Vector4(1.708,0.010,0.008,-0.116),Vector4(1.723,0.006,0.005,-0.112)],skin,0,TAU,24)
	blob(root,"UpperLip",Vector3(0,1.634,-0.1085),Vector3(0.055,0.006,0.008),Color("9a7262"))
	blob(root,"LowerLip",Vector3(0,1.6285,-0.1085),Vector3(0.050,0.006,0.008),Color("b28a74"))
	detail_face(root,skin)
	Face.seat_features(root)
	create_hair(root)
	# Adult ranger proportions: reduce the head assembly around the neck joint,
	# preserving the face/hair registration and leaving the collar anchor intact.
	var scale := 0.74
	var pivot := Vector3(0,1.535,0)
	var proportion := Transform3D(Basis.from_scale(Vector3(scale*0.90,scale,scale)),pivot*(1-scale))
	for index in range(first_part,root.get_child_count()):
		var part := root.get_child(index) as Node3D
		part.transform = proportion*part.transform
		part.set_meta("head_assembly",true)

static func detail_face(root: Node3D, skin: Color) -> void:
	for label in ["Head","NoseBridge","Ear-1","Ear1"]:
		var part := root.get_node(label) as MeshInstance3D
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		var ear: bool = label.begins_with("Ear")
		for index in vertices.size():
			var point := vertices[index]
			var color := skin
			if ear:
				var bowl := exp(-pow(point.y/0.24,2)-pow(point.z/0.28,2))*smoothstep(0.20,0.45,absf(point.x))
				point.x -= signf(point.x)*0.12*bowl
				vertices[index] = point
				color = skin.darkened(0.04).lerp(Color("a87765"),bowl*0.55)
			elif label=="Head":
				point = Face.sculpt(point)
				vertices[index] = point
				var front := 1-smoothstep(-0.07,0.01,point.z)
				var cheek := exp(-pow((absf(point.x)-0.078)/0.042,2)-pow((point.y-1.673)/0.030,2))*front
				var socket := exp(-pow((absf(point.x)-0.057)/0.030,2)-pow((point.y-1.714)/0.015,2))*front
				color = skin.lerp(Color("b68873"),cheek*0.35).darkened(socket*0.055)
				var nostril := exp(-pow((absf(point.x)-0.010)/0.004,2)-pow((point.y-1.657)/0.003,2))*front
				color = color.lerp(Color("765b50"),nostril*0.50)
				var lips := Face.lip_weights(point)*front
				color = color.lerp(Color("9a7262"),lips.x*0.70).lerp(Color("b28a74"),lips.y*0.65).lerp(Color("57413b"),lips.z*0.65)
			else:
				var nostril := exp(-pow((absf(point.x)-0.010)/0.005,2)-pow((point.y-1.660)/0.005,2))*(1-smoothstep(-0.125,-0.117,point.z))
				color = skin.lerp(Color("765b50"),nostril*0.55)
			colors.append(color)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		if ear or label=="Head":
			var surface := SurfaceTool.new()
			surface.create_from(mesh,0)
			surface.generate_normals()
			mesh = surface.commit()
		if label=="Head":
			# Share duplicate triangle vertices after sculpting, preserving UV seams.
			var indexed := SurfaceTool.new()
			indexed.create_from(mesh,0)
			indexed.index()
			mesh = indexed.commit()
		part.mesh = mesh
		part.material_override = V.mat(Color.WHITE)
		part.material_override.vertex_color_use_as_albedo = true

static func create_hair(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var hair_color := Color("252b28")
	var rows := 24
	var segments := 128
	for row in rows:
		for column in segments:
			var vertices := []
			var colors := []
			var uv := []
			for pair in [[row,column],[row+1,column],[row,column+1],[row+1,column+1]]:
				var fraction: float = float(pair[0])/rows
				var angle: float = float(pair[1])/segments*TAU
				var front := smoothstep(0.1,0.8,-cos(angle))
				var hairline := 1.69+0.10*pow((1-cos(angle))*0.5,2)+(1-front)*(0.0022*sin(angle*11+0.4)+0.0006*sin(angle*23+1.1))
				hairline += front*(0.004*sin(angle*5+0.4)+0.002*sin(angle*11-0.7))
				var height := lerpf(hairline,1.915,fraction)
				var radius := 0.145
				if height>1.79: radius = maxf(0.001,0.145*sqrt(maxf(0,1-pow((height-1.79)/0.125,2))))
				var flow := angle*18+fraction*3+0.7*sin(angle*3+fraction*2)
				radius += 0.0012*sin(flow)*sin(fraction*PI)
				var swept := angle+0.20*sin(angle-0.35)*sin(fraction*PI)
				var nape := 0.016*(1-smoothstep(1.69,1.80,height))*maxf(0,cos(angle))
				vertices.append(Vector3(sin(swept)*radius,height,cos(swept)*radius*0.95+0.015-nape))
				uv.append(Vector2(float(pair[1])/segments,fraction))
				var strand := pow(0.5+0.5*cos(flow),6)
				colors.append(hair_color.darkened(0.08).lerp(hair_color.lightened(0.055),strand))
			for index in [0,1,2,2,1,3]:
				st.set_color(colors[index])
				st.set_uv(uv[index])
				st.add_vertex(vertices[index])
	st.set_color(hair_color)
	for side in [-1,1]:
		var centers := [Vector3(side*0.077,1.81,-0.089),Vector3(side*0.105,1.78,-0.090),Vector3(side*0.128,1.74,-0.075),Vector3(side*0.129,1.695,-0.060),Vector3(side*0.126,1.665,-0.050)]
		var widths := [0.010,0.008,0.006,0.0035,0.0005]
		var rings: Array[PackedVector3Array] = []
		var sampled: Array[Vector3] = []
		var sampled_widths: Array[float] = []
		for segment in range(centers.size()-1):
			for step in 6:
				var t := float(step)/6
				sampled.append(Vector3(centers[segment]).cubic_interpolate(centers[segment+1],centers[maxi(0,segment-1)],centers[mini(centers.size()-1,segment+2)],t))
				sampled_widths.append(lerpf(widths[segment],widths[segment+1],t))
		sampled.append(centers[-1])
		sampled_widths.append(widths[-1])
		for index in sampled.size():
			var tangent: Vector3 = (sampled[mini(index+1,sampled.size()-1)]-sampled[maxi(0,index-1)]).normalized()
			var across := tangent.cross(Vector3.FORWARD).normalized()
			var around := tangent.cross(across).normalized()
			var ring := PackedVector3Array()
			for column in 9:
				var angle := float(column)/8*TAU
				ring.append(sampled[index]+(across*cos(angle)+around*sin(angle))*sampled_widths[index])
			rings.append(ring)
		for row in rings.size()-1:
			for column in 8:
				for cell in [Vector2i(row,column),Vector2i(row+1,column),Vector2i(row,column+1),Vector2i(row,column+1),Vector2i(row+1,column),Vector2i(row+1,column+1)]:
					st.set_uv(Vector2(float(cell.y)/8,float(cell.x)/(rings.size()-1)))
					st.add_vertex(rings[cell.x][cell.y])
	st.generate_normals()
	var hair := MeshInstance3D.new()
	hair.name = "HairCap"
	hair.mesh = st.commit()
	hair.material_override = hair_material(Color.WHITE)
	root.add_child(hair)
	var knot := loft(root,"HairKnot",[Vector4(1.80,0.05,0.045,0.13),Vector4(1.86,0.085,0.07,0.15),Vector4(1.93,0.065,0.055,0.15),Vector4(1.96,0.02,0.02,0.14)],Color("282e2a"),0,TAU,24)
	knot.material_override = hair_material(Color("282e2a"))
	loft(root,"HairTie",[Vector4(1.82,0.058,0.051,0.13),Vector4(1.835,0.06,0.052,0.13)],Color("71473b"),0,TAU,24)

static func hair_material(tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/hunter_hair.gdshader")
	material.set_shader_parameter("hair_tint",tint)
	return material
