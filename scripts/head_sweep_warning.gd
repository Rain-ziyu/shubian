extends RefCounted
const Model = preload("res://scripts/creature_model.gd")
const Terrain = preload("res://scripts/forest_terrain.gd")
static func profile(actor: Node3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var neck: Node3D = actor.mesh.get_node("Neck")
	for sample in 20:
		var time := lerpf(0.08,0.45,float(sample)/19)
		var angles := Model.sweep_angles("active",time,actor.data.windup,actor.data.recovery)
		var pose := Transform3D(Basis.from_euler(Vector3(angles.x,angles.y,0)),neck.position)
		for part in actor.head_rings.size():
			var part_pose := Transform3D.IDENTITY if part==0 else Model.jaw_pose(actor.data,"active",time)
			for ring in actor.head_rings[part]:
				var center: Vector3 = pose*part_pose*Vector3(ring.w,ring.y,ring.x)
				# Include the hunter capsule, sphere-sample padding and a conservative pose margin.
				var radius: float = (ring.z+0.32+0.04+0.20)/cos(PI/12)
				for i in 12:
					var angle := TAU*i/12
					points.append(Vector2(center.x,center.z)+Vector2(cos(angle),sin(angle))*radius)
	return Geometry2D.convex_hull(points)
static func build(actor: Node3D, hull: PackedVector2Array) -> ArrayMesh:
	var boundary := PackedVector2Array()
	for i in range(hull.size()-1):
		var steps := maxi(1,ceili(hull[i].distance_to(hull[i+1])/0.35))
		for step in steps: boundary.append(hull[i].lerp(hull[i+1],float(step)/steps))
	var center := Vector2.ZERO
	for point in boundary: center += point
	center /= boundary.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sample each shared radial vertex once. The prior triangle soup repeated
	# terrain height queries up to six times for the same world-space position.
	for ring in 11:
		for point in boundary:
			var sample := center.lerp(point,float(ring)/10)
			var world: Vector3 = actor.to_global(Vector3(sample.x,0,sample.y))
			world.y = Terrain.effect_height_at(world.x,world.z)+0.08
			st.add_vertex(world)
	var count := boundary.size()
	for ring in 10:
		for i in count:
			var next := (i+1)%count
			var a := ring*count+i
			var b := (ring+1)*count+i
			var c := ring*count+next
			var d := (ring+1)*count+next
			for index in ([a,b,d] if ring==0 else [a,b,c,b,d,c]): st.add_index(index)
	st.generate_normals()
	return st.commit()
