extends SceneTree
const Surface = preload("res://scripts/creature_surface.gd")
const Model = preload("res://scripts/creature_model.gd")
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
	var probe := Surface.surface(holder,"NormalProbe",[Vector4(0,0.1,0.1,0),Vector4(1,0.1,0.1,0)],Color.WHITE)
	var arrays: Array = probe.mesh.surface_get_arrays(0)
	var alignment := 0.0
	for index in 28*6:
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		alignment += Vector3(point.x,point.y,0).normalized().dot(normal)
	check(alignment/(28*6)>0.9,"creature surface normals point outward")
	var curved := Surface.profile(holder,"BodySurface",[Vector4(-1,0.1,0.2,0),Vector4(0,0.5,0.6,0.1),Vector4(1,0.2,0.3,0)],1,Color.WHITE)
	var curved_vertices: PackedVector3Array = curved.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounded := true
	var curved_section := false
	for vertex in curved_vertices:
		bounded = bounded and absf(vertex.x)<=0.5001 and vertex.y<=0.7001 and vertex.y>= -0.5001
		if is_equal_approx(vertex.z,-0.5) and vertex.x>0.3: curved_section = true
	check(bounded,"curved surface preserves authored maximum body volume")
	check(curved_section,"actual body mesh rounds longitudinal silhouette between authored sections")
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for data in database.species:
		var model := Model.create(holder,data)
		var saved = load("res://assets/models/"+str(data.id)+"-v1.tscn").instantiate()
		holder.add_child(saved)
		for instance in [model,saved]:
			check(instance.has_node("BodySurface") and instance.has_node("Neck/HeadSurface") and instance.has_node("Neck/Jaw"),"live and saved continuous body head jaw: "+str(data.id))
			check(instance.get_node("Tail/TailSurface").mesh is ArrayMesh,"live and saved continuous tail: "+str(data.id))
		var body: MeshInstance3D = model.get_node("BodySurface")
		var skin: Array = body.mesh.surface_get_arrays(0)
		check(skin[Mesh.ARRAY_COLOR].size()==skin[Mesh.ARRAY_VERTEX].size(),"surface coloration is saved per vertex")
		var leg := model.get_node("Hind1") as Node3D
		var foot := leg.get_node("Foot") as MeshInstance3D
		check(absf(leg.position.y+foot.position.y-foot.scale.y*0.5)<0.001,"standing foot sole matches actor floor")
		check(leg.has_node("LegSurface") and leg.has_node("Claw0"),"curved limbs and toe claws exist")
		if data.id=="mistfrill":
			Model.animate(model,data,0,"windup",data.windup,0)
			check(model.get_node("Neck/Frill").scale.x>1.1,"mist frill expands during warning")
			Model.animate(model,data,0,"idle",0,0)
			check(is_equal_approx(model.get_node("Neck/Frill").scale.x,1),"mist frill returns to resting size")
		if data.id=="mossback":
			var plate: MeshInstance3D = model.get_node("ArmorPlate2")
			var top := plate.position.y+plate.mesh.get_aabb().end.y
			var back := body.position.y+body.mesh.get_aabb().end.y
			check(absf(top-back)<0.05,"central armor shell fits back rather than hovering")
	print("CREATURE_SURFACE_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
