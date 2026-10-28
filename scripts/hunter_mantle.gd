extends RefCounted
## Separate torso flaps and fitted shoulder covers. Overlapping pieces follow torso or upper arm via UV2.x.
static func vertex(tool: SurfaceTool, point: Vector3, uv: Vector2, arm_weight: float) -> void:
	tool.set_uv(uv)
	tool.set_uv2(Vector2(arm_weight,0))
	tool.add_vertex(point)

static func panel(tool: SurfaceTool, side: int, back: bool, hem: bool) -> void:
	var rows := 1 if hem else 20
	for row in rows:
		for column in 12:
			for corner in [Vector2i(column,row),Vector2i(column,row+1),Vector2i(column+1,row),Vector2i(column+1,row),Vector2i(column,row+1),Vector2i(column+1,row+1)]:
				var u: float = corner.x/12.0
				var v: float = lerpf(0.965,1.0,float(corner.y)/rows) if hem else float(corner.y)/rows
				# A sloping neckline and rounded free hem avoid rectangular chest tabs.
				# Keep each flap torso-bound and separate from the moving shoulder cap.
				var top := lerpf(1.51,1.46,u)
				var bottom := 1.17+0.035*pow(absf(u*2-1),3)+0.025*u*u
				var point := Vector3(side*lerpf(lerpf(0.045,0.075,v),lerpf(0.18,0.26,v),u),lerpf(top,bottom,v),(-1 if not back else 1)*lerpf(0.125,0.225,v))
				var tension := 0.004*sin(u*PI)*sin(v*PI)
				var crease := pow(0.5+0.5*cos(u*PI*3-v*1.8),4)
				var drape := tension+0.008*crease*sin(v*PI*0.85)
				point.z += (1 if back else -1)*(drape+(0.0012 if hem else 0.0))
				vertex(tool,point,Vector2(u,v),0.0)

static func shoulder(tool: SurfaceTool, arm_rest: Transform3D, hem: bool) -> void:
	var rings := [Vector4(-0.69,0.018,0.018,0),Vector4(-0.61,0.080,0.078,0),Vector4(-0.48,0.108,0.106,0),Vector4(-0.27,0.122,0.118,0),Vector4(0.0,0.145,0.132,0),Vector4(0.05,0.150,0.137,0)]
	if hem: rings = [Vector4(0.025,0.1475,0.1345,0),Vector4(0.05,0.150,0.137,0)]
	for row in range(rings.size()-1):
		for column in 48:
			for corner in [Vector2i(column,row),Vector2i(column,row+1),Vector2i(column+1,row),Vector2i(column+1,row),Vector2i(column,row+1),Vector2i(column+1,row+1)]:
				var ring: Vector4 = rings[corner.y]
				var angle: float = corner.x*TAU/48.0
				var gathering := smoothstep(-0.55,0.05,ring.x)
				var fold := 0.004*pow(0.5+0.5*cos(angle*4+ring.x*2.0),4)*gathering
				var point := Vector3(sin(angle)*(ring.y-fold+(0.0012 if hem else 0.0)),ring.x,cos(angle)*(ring.z-fold+(0.0012 if hem else 0.0)))
				vertex(tool,arm_rest*point,Vector2(corner.x/48.0,float(corner.y)/(rings.size()-1)),1.0)
	if not hem:
		var ring: Vector4 = rings[0]
		for column in 48:
			for angle in [float(column)*TAU/48,float(column+1)*TAU/48]:
				vertex(tool,arm_rest*Vector3(sin(angle)*ring.y,ring.x,cos(angle)*ring.z),Vector2(0.5+sin(angle)*0.5,0.5+cos(angle)*0.5),1.0)
			vertex(tool,arm_rest*Vector3(0,ring.x,0),Vector2(0.5,0.5),1.0)

static func mesh(rig: Dictionary, side: int, hem := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	panel(tool,side,false,hem)
	panel(tool,side,true,hem)
	shoulder(tool,rig.arms[side].upper.transform,hem)

	tool.generate_normals()
	var arrays := tool.commit().surface_get_arrays(0)
	# Loose hems gather toward the arm when it lifts. Torso panels retain
	# their independent rigid attachment, avoiding stretched connecting sheets.
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var roles: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var inverse: Transform3D = rig.arms[side].upper.transform.affine_inverse()
	for index in points.size():
		if roles[index].x<0.5: continue
		var local := inverse*points[index]
		var gathering := smoothstep(-0.35,0.05,local.y)
		var radius := Vector2(local.x,local.z)
		var reduced := radius*(1-0.45*gathering)
		if hem and radius.length()>0.00001: reduced += radius.normalized()*0.0015*gathering
		local.x = reduced.x
		local.z = reduced.y
		points[index] = rig.arms[side].upper.transform*local
	var folded: Array = arrays.duplicate(true)
	folded[Mesh.ARRAY_VERTEX] = points
	var temporary := ArrayMesh.new()
	temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,folded)
	var normals := SurfaceTool.new()
	normals.create_from(temporary,0)
	normals.generate_normals()
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = points
	shape[Mesh.ARRAY_NORMAL] = normals.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	result.add_blend_shape("ShoulderEase")
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape])
	return result

static func apply(rig: Dictionary) -> void:
	for side in [-1,1]:
		for hem in [false,true]:
			var part: MeshInstance3D = rig.torso.get_node(("CapeHem" if hem else "RainCape")+str(side))
			part.mesh = mesh(rig,side,hem)
			part.set_meta("segmented_mantle",true)
