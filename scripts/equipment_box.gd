extends RefCounted
## Closed chamfered fittings, in physical mesh dimensions rather than node scale.
const Triangles = preload("res://scripts/trident_mesh.gd")
static func create(size: Vector3, bevel: float) -> ArrayMesh:
	var half := size*0.5
	var inner := half-Vector3.ONE*minf(bevel,minf(half.x,minf(half.y,half.z))*0.8)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for axis in 3:
		var a := (axis+1)%3
		var b := (axis+2)%3
		for side in [-1,1]:
			var corners: Array[Vector3] = []
			for cell: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = side*half[axis]
				point[a] = cell.x*inner[a]
				point[b] = cell.y*inner[b]
				corners.append(point)
			var normal := Vector3.ZERO
			normal[axis] = side
			quad(tool,corners,normal)
		for sa in [-1,1]:
			for sb in [-1,1]:
				var corners: Array[Vector3] = []
				for cell: Vector2 in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var point := Vector3.ZERO
					point[axis] = cell.x*inner[axis]
					point[a] = sa*(half[a] if cell.y==0 else inner[a])
					point[b] = sb*(inner[b] if cell.y==0 else half[b])
					corners.append(point)
				var normal := Vector3.ZERO
				normal[a] = sa
				normal[b] = sb
				quad(tool,corners,normal.normalized())
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var sign := Vector3(x,y,z)
				var corners: Array[Vector3] = []
				for axis in 3:
					var point := sign*inner
					point[axis] = sign[axis]*half[axis]
					corners.append(point)
				Triangles.bevel_triangle(tool,corners[0],corners[1],corners[2],sign.normalized())
	tool.generate_normals()
	return tool.commit()

static func quad(tool: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	Triangles.bevel_triangle(tool,points[0],points[1],points[2],normal)
	Triangles.bevel_triangle(tool,points[0],points[2],points[3],normal)

static func frame(size: Vector3, opening: Vector2, bevel: float) -> ArrayMesh:
	assert(opening.x<size.x-4*bevel and opening.y<size.y-4*bevel,"Buckle opening requires solid beveled walls")
	var outer := Vector2(size.x,size.y)*0.5
	var inner := opening*0.5
	var depth := size.z*0.5
	# Eight cross-section loops form one closed ring, including its open center.
	var profiles := [Vector3(outer.x-bevel,outer.y-bevel,-depth),Vector3(outer.x,outer.y,-depth+bevel),Vector3(outer.x,outer.y,depth-bevel),Vector3(outer.x-bevel,outer.y-bevel,depth),Vector3(inner.x+bevel,inner.y+bevel,depth),Vector3(inner.x,inner.y,depth-bevel),Vector3(inner.x,inner.y,-depth+bevel),Vector3(inner.x+bevel,inner.y+bevel,-depth)]
	var loops: Array[PackedVector3Array] = []
	for profile: Vector3 in profiles:
		var radius := 0.002 if profile.x>inner.x+bevel else 0.001
		var ring := PackedVector3Array()
		for point: Vector2 in [Vector2(-profile.x+radius,-profile.y),Vector2(profile.x-radius,-profile.y),Vector2(profile.x,-profile.y+radius),Vector2(profile.x,profile.y-radius),Vector2(profile.x-radius,profile.y),Vector2(-profile.x+radius,profile.y),Vector2(-profile.x,profile.y-radius),Vector2(-profile.x,-profile.y+radius)]: ring.append(Vector3(point.x,point.y,profile.z))
		loops.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for row in loops.size():
		var next := (row+1)%loops.size()
		for column in 8:
			var after := (column+1)%8
			var points: Array[Vector3] = [loops[row][column],loops[row][after],loops[next][after],loops[next][column]]
			var normal := (points[1]-points[0]).cross(points[3]-points[0]).normalized()
			quad(tool,points,normal)
	tool.generate_normals()
	return tool.commit()
