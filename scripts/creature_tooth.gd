extends RefCounted
## Original curved dental surfaces, with circular roots seated on the real jaw.
const Triangles = preload("res://scripts/trident_mesh.gd")
static func create(parent: Node3D, root: Vector3, size: float, index: int, upper: bool, species: String) -> MeshInstance3D:
	var radius := size*(0.014 if upper else 0.010)
	var factor: float = {"mossback":0.70,"thornhorn":0.96,"mistfrill":0.90,"reedclaw":1.0,"stormcrest":0.90}[species]
	var height := size*(0.060 if upper else 0.035)*factor*(1.0-0.10*(index%3))
	var curve: float = {"mossback":0.003,"thornhorn":0.008,"mistfrill":0.012,"reedclaw":0.021,"stormcrest":0.009}[species]*size
	var direction := -1.0 if upper else 1.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	var rows: Array[PackedVector3Array] = []
	var centers := PackedVector3Array()
	for t: float in [0.0,0.10,0.25,0.45,0.65,0.82,0.94,1.0]:
		var center := Vector3(0,direction*height*t,curve*t*t)
		centers.append(center)
		var width := maxf(size*0.00035,radius*pow(1-t,0.8))
		var row := PackedVector3Array()
		for column in 17:
			var angle := TAU*float(column)/16
			row.append(center+Vector3(sin(angle)*width,0,cos(angle)*width*lerpf(1.0,0.65,t)))
		rows.append(row)
	for row in range(rows.size()-1):
		for column in 16:
			var tint := Color("a7a185").lerp(Color("dddcc2"),smoothstep(0,5,float(row)))
			tool.set_color(tint)
			var a := rows[row][column]
			var b := rows[row][column+1]
			var c := rows[row+1][column]
			var d := rows[row+1][column+1]
			var outward := Vector3(a.x,0,a.z-centers[row].z)
			Triangles.bevel_triangle(tool,a,b,c,outward)
			Triangles.bevel_triangle(tool,b,d,c,outward)
	tool.set_smooth_group(-1)
	for row in [0,rows.size()-1]:
		tool.set_color(Color("a7a185") if row==0 else Color("dddcc2"))
		var outward := Vector3(0,-direction if row==0 else direction,0)
		for column in 16: Triangles.bevel_triangle(tool,centers[row],rows[row][column],rows[row][column+1],outward)
	tool.generate_normals()
	var tooth := MeshInstance3D.new()
	tooth.mesh = tool.commit()
	tooth.position = root
	tooth.set_meta("dental_tooth",true)
	var enamel := StandardMaterial3D.new()
	enamel.vertex_color_use_as_albedo = true
	enamel.roughness = 0.40
	tooth.material_override = enamel
	parent.add_child(tooth)
	return tooth
