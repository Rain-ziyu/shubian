extends RefCounted
## Closed curved keratin surfaces in the original cylindrical claw frame.
const Triangles = preload("res://scripts/trident_mesh.gd")

static func finish(claw: MeshInstance3D, size: float, leaper: bool) -> void:
	var length := size*(0.20 if leaper else 0.14)
	var bend := size*(0.055 if leaper else 0.050)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	var rows: Array[PackedVector3Array] = []
	var centers: Array[Vector3] = []
	for row in 13:
		var t := float(row)/12
		var center := Vector3(0,length*(t-0.5),-bend*t*t)
		var tangent := Vector3(0,length,-2*bend*t).normalized()
		var across := tangent.cross(Vector3.RIGHT).normalized()
		var radius := size*(0.017*pow(1-t,0.8)+0.001*t)
		var ring := PackedVector3Array()
		for segment in 24:
			var angle := TAU*float(segment)/24
			ring.append(center+(Vector3.RIGHT*cos(angle)+across*sin(angle))*radius)
		rows.append(ring)
		centers.append(center)
	for row in rows.size()-1:
		tool.set_color(Color.WHITE.darkened(0.20*(1-float(row)/12)))
		for segment in 24:
			var next := (segment+1)%24
			var outward := (rows[row][segment]-centers[row]).normalized()
			Triangles.bevel_triangle(tool,rows[row][segment],rows[row+1][segment],rows[row][next],outward)
			Triangles.bevel_triangle(tool,rows[row][next],rows[row+1][segment],rows[row+1][next],outward)
	tool.set_smooth_group(-1)
	for row in [0,rows.size()-1]:
		tool.set_color(Color.WHITE.darkened(0.20 if row==0 else 0))
		for segment in 24:
			Triangles.bevel_triangle(tool,centers[row],rows[row][segment],rows[row][(segment+1)%24],Vector3.DOWN if row==0 else Vector3(0,length,-2*bend).normalized())
	tool.generate_normals()
	claw.mesh = tool.commit()
	claw.material_override.vertex_color_use_as_albedo = true
	claw.material_override.roughness = 0.72
	claw.material_override.metallic_specular = 0.25
