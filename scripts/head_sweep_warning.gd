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
		for rings in actor.head_rings:
			for ring in rings:
				var center: Vector3 = pose*Vector3(ring.w,ring.y,ring.x)
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
	for ring in 10:
		for i in boundary.size():
			var next := (i+1)%boundary.size()
			var a := center.lerp(boundary[i],float(ring)/10)
			var b := center.lerp(boundary[i],float(ring+1)/10)
			var c := center.lerp(boundary[next],float(ring)/10)
			var d := center.lerp(boundary[next],float(ring+1)/10)
			for point in ([a,b,d] if ring==0 else [a,b,c,b,d,c]):
				var world: Vector3 = actor.to_global(Vector3(point.x,0,point.y))
				world.y = Terrain.effect_height_at(world.x,world.z)+0.08
				st.add_vertex(world)
	st.generate_normals()
	return st.commit()
