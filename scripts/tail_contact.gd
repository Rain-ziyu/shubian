extends RefCounted
## Swept spherical samples fitted to the authored tail rings; still a volume approximation.
static func profile(mesh: Mesh) -> Array[Vector4]:
	var rings := {}
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in vertices:
		var key := snappedf(point.z,0.00001)
		if not rings.has(key): rings[key] = Vector4(point.x,point.x,point.y,point.y)
		var bounds: Vector4 = rings[key]
		rings[key] = Vector4(minf(bounds.x,point.x),maxf(bounds.y,point.x),minf(bounds.z,point.y),maxf(bounds.w,point.y))
	var depths := rings.keys()
	depths.sort()
	var result: Array[Vector4] = []
	for depth in depths:
		var bounds: Vector4 = rings[depth]
		result.append(Vector4(depth,(bounds.z+bounds.w)*0.5,maxf(bounds.y-bounds.x,bounds.w-bounds.z)*0.5,(bounds.x+bounds.y)*0.5))
	return result

static func touches(rings: Array[Vector4], before: Transform3D, after: Transform3D, feet: Vector3, previous_feet: Variant = null) -> bool:
	return not contact(rings,before,after,feet,previous_feet).is_empty()

static func contact(rings: Array[Vector4], before: Transform3D, after: Transform3D, feet: Vector3, previous_feet: Variant = null, previous_rings: Array[Vector4] = []) -> Dictionary:
	var start: Vector3 = feet if previous_feet==null else previous_feet
	var low := Vector3.UP*0.32
	var high := Vector3.UP*1.48
	for index in range(rings.size()-1):
		var first := rings[index]
		var last := rings[index+1]
		var steps := maxi(1,ceili(Vector3(last.w-first.w,last.y-first.y,last.x-first.x).length()/0.08))
		for step in range(steps+1):
			var ring := first.lerp(last,float(step)/steps)
			var center := Vector3(ring.w,ring.y,ring.x)
			var old_ring := previous_rings[index].lerp(previous_rings[index+1],float(step)/steps) if previous_rings.size()==rings.size() else ring
			var old_center := Vector3(old_ring.w,old_ring.y,old_ring.x)
			# Relative motion keeps tail and hunter samples at the same time fraction.
			var first_point := before*old_center-start
			var last_point := after*center-feet
			var closest := Geometry3D.get_closest_points_between_segments(first_point,last_point,low,high)
			# Half sample spacing closes gaps between adjacent spheres.
			if closest[0].distance_to(closest[1])<=0.32+ring.z+0.04:
				var travel := last_point-first_point
				var fraction := clampf((closest[0]-first_point).dot(travel)/travel.length_squared(),0,1) if travel.length_squared()>0.000001 else 1.0
				return {"feet":start.lerp(feet,fraction),"fraction":fraction}
	return {}
