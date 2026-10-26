extends RefCounted
## Separate torso flaps and fitted shoulder covers. UV2.x stores the authored torso/upper-arm blend.
static func vertex(tool: SurfaceTool, point: Vector3, uv: Vector2, arm_weight: float) -> void:
	tool.set_uv(uv)
	tool.set_uv2(Vector2(arm_weight,0))
	tool.add_vertex(point)

static func panel(tool: SurfaceTool, side: int, back: bool, hem: bool) -> void:
	var rows := 1 if hem else 10
	for row in rows:
		for column in 6:
			for corner in [Vector2i(column,row),Vector2i(column,row+1),Vector2i(column+1,row),Vector2i(column+1,row),Vector2i(column,row+1),Vector2i(column+1,row+1)]:
				var u: float = corner.x/6.0
				var v: float = lerpf(0.965,1.0,float(corner.y)/rows) if hem else float(corner.y)/rows
				var point := Vector3(side*lerpf(lerpf(0.045,0.075,v),lerpf(0.14,0.185,v),u),lerpf(1.48,1.17,v),(-1 if not back else 1)*lerpf(0.125,0.235,v))
				point.z += (1 if back else -1)*0.008*sin(u*PI)*sin(v*PI)
				vertex(tool,point,Vector2(u,v),0.0)

static func shoulder(tool: SurfaceTool, arm_rest: Transform3D, hem: bool) -> void:
	var rings := [Vector4(-0.69,0.018,0.018,0),Vector4(-0.61,0.082,0.080,0),Vector4(-0.48,0.118,0.114,0),Vector4(-0.27,0.115,0.108,0),Vector4(0.05,0.115,0.105,0)]
	if hem: rings = [Vector4(0.025,0.115,0.105,0),Vector4(0.05,0.115,0.105,0)]
	for row in range(rings.size()-1):
		for column in 24:
			for corner in [Vector2i(column,row),Vector2i(column,row+1),Vector2i(column+1,row),Vector2i(column+1,row),Vector2i(column,row+1),Vector2i(column+1,row+1)]:
				var ring: Vector4 = rings[corner.y]
				var angle: float = corner.x*TAU/24.0
				var point := Vector3(sin(angle)*ring.y,ring.x,cos(angle)*ring.z)
				vertex(tool,arm_rest*point,Vector2(corner.x/24.0,float(corner.y)/(rings.size()-1)),1.0)
	if not hem:
		var ring: Vector4 = rings[0]
		for column in 24:
			for angle in [float(column)*TAU/24,float(column+1)*TAU/24]:
				vertex(tool,arm_rest*Vector3(sin(angle)*ring.y,ring.x,cos(angle)*ring.z),Vector2(0.5+sin(angle)*0.5,0.5+cos(angle)*0.5),1.0)
			vertex(tool,arm_rest*Vector3(0,ring.x,0),Vector2(0.5,0.5),1.0)

static func cuff(tool: SurfaceTool, rig: Dictionary, side: int) -> void:
	var source: MeshInstance3D = rig.root.get_node("JointClothShoulder"+str(side))
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var hinge: Vector3 = rig.arms[side].shoulder.position
	var upper := Vector3(side*0.16,1.40,0)
	var lower: Vector3 = rig.arms[side].elbow.position
	var start := hinge+(upper-hinge).normalized()*0.11
	var end := hinge+(lower-hinge).normalized()*0.11
	for i in points.size():
		var t := uv[i].y
		var center := start*(1-t)*(1-t)+hinge*2*t*(1-t)+end*t*t
		var radius := lerpf(0.075,0.12,t)+0.045*sin(t*PI)
		var point := center+(points[i]-center)*(radius/(0.055*(1+0.1*sin(t*PI))))
		vertex(tool,point,uv[i],smoothstep(0,1,t))

static func mesh(rig: Dictionary, side: int, hem := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	panel(tool,side,false,hem)
	panel(tool,side,true,hem)
	shoulder(tool,rig.arms[side].upper.transform,hem)
	if not hem: cuff(tool,rig,side)
	tool.generate_normals()
	var arrays := tool.commit().surface_get_arrays(0)
	var result := ArrayMesh.new()
	if hem:
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	else:
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX].duplicate()
		shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL].duplicate()
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
