extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
const Contact = preload("res://scripts/tail_contact.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	var data: Dictionary = database.species[3]
	var live := Model.create(holder,data)
	var saved = load("res://assets/models/reedclaw-v1.tscn").instantiate()
	holder.add_child(saved)
	for model in [live,saved]:
		var body: MeshInstance3D = model.get_node("BodySurface")
		var surface := body.mesh.generate_triangle_mesh()
		for side in [-1,1]:
			var arm: MeshInstance3D = model.get_node("Forelimb"+str(side))
			var points: PackedVector3Array = arm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var roots: Array[Vector3] = []
			for point in points:
				if point.z>float(data.size)*0.0199: roots.append(point)
			check(roots.size()>28,"test inspects the full shoulder end ring and closing cap")
			for sample in [["idle",0.0],["windup",0.75],["active",0.0],["active",0.20],["active",0.40],["active",0.65],["recover",0.15],["recover",0.50]]:
				Model.animate(model,data,0,sample[0],sample[1],0)
				var buried := true
				for point in roots:
					var local := body.to_local(arm.to_global(point))
					var hit := surface.intersect_segment(Vector3(side*float(data.size)*2,local.y,local.z),Vector3(0,local.y,local.z))
					buried = buried and not hit.is_empty() and side*local.x<side*hit.get("position",Vector3.ZERO).x-float(data.size)*0.001
				check(buried,"shoulder cap stays inside actual chest surface: "+str(sample))
			check(arm.get_node("Wrist").position.is_equal_approx(Vector3(0,-float(data.size)*0.13,-float(data.size)*0.22)),"wrist anchor remains at the authored attack position")
			var rings := Contact.profile(arm.mesh)
			check(absf(rings[-1].w+side*float(data.size)*0.18)<0.0001,"fitted contact rings preserve the shifted shoulder center")
	var probe := Model.Surface.surface(holder,"OffsetProbe",[Vector4(0,0.05,0.05,0),Vector4(1,0.05,0.05,0)],Color.WHITE)
	var arrays: Array = probe.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size(): vertices[index].x += 1.0
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var offset_mesh := ArrayMesh.new()
	offset_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var rings := Contact.profile(offset_mesh)
	var transform := Transform3D(Basis.IDENTITY,Vector3.UP*0.8)
	check(Contact.touches(rings,transform,transform,Vector3(1,0,0.5)),"offset surface contact hits its actual lateral center")
	check(not Contact.touches(rings,transform,transform,Vector3(0,0,0.5)),"offset surface does not retain a phantom center hit")
	print("REEDCLAW_SHOULDER_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
