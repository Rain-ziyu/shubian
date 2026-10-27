extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json")).species[0]
	var live := Model.create(stage,data)
	var saved: Node3D = load("res://assets/models/mossback-v1.tscn").instantiate()
	stage.add_child(saved)
	for model in [live,saved]:
		var body: MeshInstance3D = model.get_node("BodySurface")
		var surface := body.mesh.generate_triangle_mesh()
		for index in 5:
			var plate: MeshInstance3D = model.get_node("ArmorPlate"+str(index))
			var points: PackedVector3Array = plate.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var samples := points.duplicate()
			for triangle in range(0,points.size(),3):
				samples.append((points[triangle]+points[triangle+1]+points[triangle+2])/3)
				for edge in 3: samples.append((points[triangle+edge]+points[triangle+(edge+1)%3])*0.5)
			var supported := true
			var minimum := INF
			var maximum := -INF
			for vertex in samples:
				var point := body.to_local(plate.to_global(vertex))
				var hit := surface.intersect_segment(Vector3(point.x,10,point.z),Vector3(point.x,-10,point.z))
				if hit.is_empty(): supported=false; continue
				var gap: float = point.y-hit.position.y
				minimum = minf(minimum,gap)
				maximum = maxf(maximum,gap)
			checks += 1
			print("ARMOR_FIT: saved=",model==saved," plate=",index," supported=",supported," min=",minimum," max=",maximum)
			if not supported or minimum<0.002 or maximum>0.05:
				failures += 1
				printerr("FAIL: Shell vertices, edge midpoints and triangle centers must remain outside and within 5 cm of the actual back")
	print("MOSSBACK_ARMOR_FIT_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
