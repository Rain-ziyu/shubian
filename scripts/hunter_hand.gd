extends RefCounted
## Single skinned hand piece: palm, four curled digits and opposing thumb.
static func geometry(side: int, opened: bool) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var palm := SphereMesh.new()
	palm.radial_segments = 16
	palm.rings = 8
	palm.radius = 0.5
	palm.height = 1
	var arrays := palm.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		st.set_color(Color("353e35").lerp(Color("485247"),smoothstep(-0.1,0.4,points[index].x)))
		st.add_vertex(points[index]*Vector3(0.045,0.10,0.065)+Vector3(0.057,0,0))
	wrist(st)
	for digit in 4:
		var path: Array[Vector3] = []
		for step in 13:
			var end_angle: float = [2.25,2.35,2.20,1.95][digit]
			var angle := lerpf(-0.55,end_angle,float(step)/12)
			var closed := Vector3(cos(angle)*0.043,(digit-1.5)*0.023,sin(angle)*0.043)
			var length: float = [0.105,0.115,0.108,0.085][digit]
			var straight := Vector3(lerpf(0.04,0.04-length,float(step)/12),(digit-1.5)*0.025,0.012*sin(PI*step/12.0))
			path.append(straight if opened else closed)
		tube(st,path,0.010,Color("4b5548"))
	var thumb: Array[Vector3] = [Vector3(0.057,-0.047,0.018),Vector3(0.035,-0.058,0.040),Vector3(0,-0.055,0.047),Vector3(-0.034,-0.043,0.030)]
	if opened: thumb = [Vector3(0.057,-0.047,0.018),Vector3(0.035,-0.065,0.030),Vector3(0.01,-0.08,0.027),Vector3(-0.014,-0.088,0.02)]
	if side==1:
		for i in thumb.size(): thumb[i].y = -thumb[i].y
	tube(st,smooth_path(thumb),0.012,Color("48513f"))
	st.generate_normals()
	return st.commit_to_arrays()
static func wrist(tool: SurfaceTool) -> void:
	var rings := [Vector3(0.062,0.037,0.023),Vector3(0.075,0.037,0.027),Vector3(0.090,0.034,0.028),Vector3(0.110,0.030,0.027),Vector3(0.125,0.026,0.025)]
	tool.set_color(Color("353e35"))
	for row in rings.size()-1:
		for segment in 20:
			for item in [Vector2i(row,segment),Vector2i(row+1,segment),Vector2i(row,segment+1),Vector2i(row,segment+1),Vector2i(row+1,segment),Vector2i(row+1,segment+1)]:
				var ring: Vector3 = rings[item.x]
				var angle := TAU*float(item.y)/20
				tool.add_vertex(Vector3(ring.x,sin(angle)*ring.y,cos(angle)*ring.z))

static func create(parent: Node3D, side: int) -> MeshInstance3D:
	var closed := geometry(side,false)
	var opened := geometry(side,true)
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = opened[Mesh.ARRAY_VERTEX]
	shape[Mesh.ARRAY_NORMAL] = opened[Mesh.ARRAY_NORMAL]
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	mesh.add_blend_shape("OpenHand")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,closed,[shape])
	var hand := MeshInstance3D.new()
	hand.name = "GripHandLeft" if side==-1 else "GripHandRight"
	hand.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	hand.material_override = material
	parent.add_child(hand)
	return hand
static func tube(st: SurfaceTool, path: Array[Vector3], radius: float, color: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in path.size():
		var tangent := (path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
		var u := tangent.cross(Vector3.UP).normalized()
		var v := tangent.cross(u).normalized()
		var ring := PackedVector3Array()
		var t := float(i)/maxi(1,path.size()-1)
		var taper := 1-0.65*smoothstep(0.80,1.0,t)
		for j in 10: ring.append(path[i]+radius*taper*(u*cos(TAU*j/10)+v*sin(TAU*j/10)))
		rings.append(ring)
	for i in path.size()-1:
		for j in 10:
			var k := (j+1)%10
			for item in [[rings[i][j],i],[rings[i][k],i],[rings[i+1][j],i+1],[rings[i][k],i],[rings[i+1][k],i+1],[rings[i+1][j],i+1]]:
				var t: float = float(item[1])/maxi(1,path.size()-1)
				st.set_color(digit_color(color,t))
				st.add_vertex(item[0])
	for row in [0,path.size()-1]:
		for j in 10:
			var k := (j+1)%10
			for point in ([path[row],rings[row][k],rings[row][j]] if row==0 else [path[row],rings[row][j],rings[row][k]]):
				st.set_color(digit_color(color,float(row)/maxi(1,path.size()-1)))
				st.add_vertex(point)
static func smooth_path(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index in points.size()-1:
		for step in 4:
			result.append(points[index].cubic_interpolate(points[index+1],points[maxi(0,index-1)],points[mini(points.size()-1,index+2)],float(step)/4))
	result.append(points[-1])
	return result

static func digit_color(glove: Color, t: float) -> Color:
	var skin := preload("res://scripts/hunter_outfit.gd").SKIN_TONE
	if t>0.55: return skin
	if t>0.47: return glove.darkened(0.30)
	return glove

static func orient(hand: MeshInstance3D, elbow: Vector3, grip_axis: Vector3, grip := 1.0, finger_release := 0.0) -> void:
	hand.basis = basis_for(hand.position,elbow,Vector3.RIGHT).slerp(basis_for(hand.position,elbow,grip_axis),grip)
	hand.set_blend_shape_value(0,1-grip*(1-finger_release))
static func basis_for(point: Vector3, elbow: Vector3, grip_axis: Vector3) -> Basis:
	var y := grip_axis.normalized()
	var x := elbow-point
	x = (x-y*x.dot(y)).normalized()
	if x.length_squared()<0.01: x = y.cross(Vector3.FORWARD).normalized()
	if x.length_squared()<0.01: x = y.cross(Vector3.RIGHT).normalized()
	return Basis(x,y,x.cross(y)).orthonormalized()
