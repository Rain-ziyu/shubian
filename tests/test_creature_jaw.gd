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
	var stage := Node3D.new()
	root.add_child(stage)
	var species: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json")).species
	for data in species:
		var mesh := Model.create(stage,data)
		var neck := mesh.get_node("Neck") as Node3D
		var jaw := neck.get_node("Jaw") as MeshInstance3D
		var hinge := Vector3(0,float(data.size)*0.01,-float(data.size)*0.12)
		var tip := Vector3(0,-float(data.size)*0.04,-float(data.size)*0.66)-hinge
		Model.animate(mesh,data,0,"idle",0,0)
		var closed := neck.to_local(jaw.to_global(tip))
		Model.animate(mesh,data,0,"active",0.15,0)
		var open := neck.to_local(jaw.to_global(tip))
		check(closed.y-open.y>float(data.size)*0.10,str(data.id)+" visibly lowers the mandible during its attack")
		check(jaw.global_position.distance_to(neck.to_global(hinge))<0.001,"editable jaw node rotates around its fixed rear hinge")
		check(jaw.has_node("MouthFloor"),"mouth interior stays attached to the mandible")
		var lining: MeshInstance3D = jaw.get_node("MouthFloor")
		var jaw_surface: TriangleMesh = jaw.mesh.generate_triangle_mesh()
		var attached := true
		var fully_projected := true
		var upward := true
		var lining_arrays: Array = lining.mesh.surface_get_arrays(0)
		var lining_points: PackedVector3Array = lining_arrays[Mesh.ARRAY_VERTEX]
		var lining_normals: PackedVector3Array = lining_arrays[Mesh.ARRAY_NORMAL]
		for vertex in lining_points.size():
			var point: Vector3 = lining.transform*lining_points[vertex]
			var contact := jaw_surface.intersect_segment(Vector3(point.x,float(data.size)*0.25,point.z),Vector3(point.x,-float(data.size)*0.25,point.z))
			fully_projected = fully_projected and not contact.is_empty()
			if not contact.is_empty():
				var clearance: float = point.y-contact.position.y
				attached = attached and clearance>=float(data.size)*0.0005 and clearance<=float(data.size)*0.007
			upward = upward and lining_normals[vertex].y>0.2
		check(fully_projected,"entire mouth lining lies over the actual jaw surface")
		check(attached,"mouth lining hugs the jaw instead of floating as a flat board")
		check(upward,"inner mouth surface normals face its opening")

		var saved = load("res://assets/models/"+str(data.id)+"-v1.tscn").instantiate()
		stage.add_child(saved)
		var saved_lining: MeshInstance3D = saved.get_node("Neck/Jaw/MouthFloor")
		check(saved_lining.transform.is_equal_approx(lining.transform) and saved_lining.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==lining_points,"saved mouth lining matches the fitted runtime mesh")
		saved.queue_free()
		var loaded := Model.jaw_pose(data,"windup",float(data.windup))
		check(loaded.is_equal_approx(Model.jaw_pose(data,"active",0)),"jaw joins anticipation to attack without a snap")
		check(Model.jaw_pose(data,"active",0.65).is_equal_approx(Model.jaw_pose(data,"recover",0)),"jaw joins attack to recovery without a snap")
		Model.animate(mesh,data,0,"recover",float(data.recovery),0)
		check(jaw.basis.is_equal_approx(Basis.IDENTITY) and jaw.position.distance_to(hinge)<0.001,"recovery returns the mouth to its authored rest shape")
		# A lower capsule probe distinguishes the articulated jaw from the old frame.
		Model.animate(mesh,data,0,"active",0.15,0)
		var rings := Contact.profile(jaw.mesh)
		var probe := Vector3(0,-float(data.size)*0.04,-float(data.size)*0.58)-hinge
		var point := jaw.to_global(probe)-Vector3.UP*1.65
		check(Contact.touches(rings,jaw.global_transform,jaw.global_transform,point),"fitted contact samples follow the visible jaw transform")
		mesh.queue_free()
	await process_frame
	print("CREATURE_JAW_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
