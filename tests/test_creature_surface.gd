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
		if data.id=="reedclaw":
			for instance in [model,saved]:
				var points: PackedVector3Array = instance.get_node("BodySurface").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var chest_width := 0.0
				var waist_width := 0.0
				for point in points:
					if absf(point.z+float(data.size)*0.15)<0.001: chest_width = maxf(chest_width,absf(point.x))
					if absf(point.z-float(data.size)*0.20)<0.001: waist_width = maxf(waist_width,absf(point.x))
				check(chest_width>0.1 and waist_width/chest_width<0.8,"live and saved leaper has a tucked waist between chest and hips")
				for side in [-1,1]:
					var wrist: Node3D = instance.get_node("Forelimb"+str(side)+"/Wrist")
					check(wrist.get_child_count()==4,"reedclaw has palm and three separated fingers")
					var talon: MeshInstance3D = wrist.get_node("Digit0/Talon")
					check(talon.mesh.get_aabb().size.z>data.size*0.09,"hooked talon has readable length")
		if data.id=="mistfrill":
			for instance in [model,saved]:
				for side in [-1,1]:
					var sac: MeshInstance3D = instance.get_node("Neck/MistSac"+str(side))
					Model.animate(instance,data,0,"idle",0,0)
					var resting := sac.scale
					Model.animate(instance,data,0,"windup",data.windup,0)
					var inflated := sac.scale
					check(inflated.x>resting.x*1.3 and inflated.y>resting.y*1.2,"live and saved throat sac visibly inflates during mist warning")
					Model.animate(instance,data,0,"active",0,0)
					check(sac.scale.is_equal_approx(inflated),"mist release begins from the inflated sac without a pose jump")
					Model.animate(instance,data,0,"recover",0,0)
					check(sac.scale.is_equal_approx(resting),"mist recovery resets sac pressure instead of retaining attack swelling")
			Model.animate(model,data,0,"windup",data.windup,0)
			check(model.get_node("Neck/Frill").scale.x>1.1,"mist frill expands during warning")
			Model.animate(model,data,0,"idle",0,0)
			check(is_equal_approx(model.get_node("Neck/Frill").scale.x,1),"mist frill returns to resting size")
		if data.id=="mossback":
			var plate: MeshInstance3D = model.get_node("ArmorPlate2")
			var top := plate.position.y+plate.mesh.get_aabb().end.y
			var back := body.position.y+body.mesh.get_aabb().end.y
			check(absf(top-back)<0.05,"central armor shell fits back rather than hovering")
			for instance in [model,saved]:
				var trunk: MeshInstance3D = instance.get_node("BodySurface")
				var attachments := []
				for index in 5: attachments.append(trunk.global_transform.affine_inverse()*instance.get_node("ArmorPlate"+str(index)).global_transform)
				for phase in ["windup","active","recover"]:
					Model.animate(instance,data,0,phase,float(data.windup) if phase=="windup" else 0.0,0)
					for index in 5:
						var attached: Transform3D = trunk.global_transform.affine_inverse()*instance.get_node("ArmorPlate"+str(index)).global_transform
						check(attached.is_equal_approx(attachments[index]),"live and saved shell plates follow the rolling trunk: "+phase)
	print("CREATURE_SURFACE_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
