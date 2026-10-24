extends RefCounted
const V = preload("res://scripts/visuals.gd")
static func create(root: Node3D, label: String, upper: Vector3, hinge: Vector3, lower: Vector3, radius: float) -> MeshInstance3D:
	var start := hinge+(upper-hinge).normalized()*0.11
	var end := hinge+(lower-hinge).normalized()*0.11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[PackedVector3Array] = []
	for ring in 7:
		var t := float(ring)/6
		var center := start*(1-t)*(1-t)+hinge*2*t*(1-t)+end*t*t
		var tangent := ((hinge-start)*(1-t)+(end-hinge)*t).normalized()
		var across := tangent.cross(Vector3.FORWARD).normalized()
		if across.length_squared()<0.1: across = tangent.cross(Vector3.RIGHT).normalized()
		var around := tangent.cross(across).normalized()
		var row := PackedVector3Array()
		for index in 13:
			var angle := TAU*index/12
			row.append(center+(across*cos(angle)+around*sin(angle))*radius*(1+0.1*sin(t*PI)))
		rows.append(row)
	for ring in 6:
		for index in 12:
			for cell in [Vector2i(ring,index),Vector2i(ring,index+1),Vector2i(ring+1,index),Vector2i(ring+1,index),Vector2i(ring,index+1),Vector2i(ring+1,index+1)]:
				surface.set_uv(Vector2(float(cell.y)/12,float(cell.x)/6))
				surface.add_vertex(rows[cell.x][cell.y])
	surface.generate_normals()
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = surface.commit()
	result.material_override = V.mat(Color("303834"))
	result.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(result)
	return result
