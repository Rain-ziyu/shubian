extends SceneTree
const Model = preload("res://scripts/hunter_model.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func positions(mesh: ArrayMesh, blend: float) -> PackedVector3Array:
	var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var target: PackedVector3Array = mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
	var result := PackedVector3Array()
	for index in base.size(): result.append(base[index].lerp(target[index],blend))
	return result
func check_mesh(mesh: ArrayMesh, label: String) -> void:
	check(mesh.get_blend_shape_count()==1 and mesh.get_blend_shape_name(0)=="HemFlex","cloth keeps the existing animation channel: "+label)
	for blend in [0.0,0.5,1.0]:
		var points := positions(mesh,blend)
		var edges := {}
		var valid := true
		for triangle in range(0,points.size(),3):
			for edge in 3:
				var a := points[triangle+edge]
				var b := points[triangle+(edge+1)%3]
				valid = valid and a.is_finite()
				var first := str(Vector3i((a*1000000).round()))
				var last := str(Vector3i((b*1000000).round()))
				var key := first+"|"+last if first<last else last+"|"+first
				edges[key] = int(edges.get(key,0))+1
		for count in edges.values(): valid = valid and count==2
		check(valid,"cloth front/back/rim remain closed through flex: "+label+"/"+str(blend))
func check_trim(panel: ArrayMesh, trim: ArrayMesh, label: String) -> void:
	for blend in [0.0,0.5,1.0]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions(panel,blend)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var surface := mesh.generate_triangle_mesh()
		var points := positions(trim,blend)
		var normals: PackedVector3Array = trim.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var supported := true
		var samples := 0
		var minimum := INF
		var maximum := 0.0
		for index in points.size():
			if normals[index].z> -0.6: continue
			var point := points[index]
			var hit := surface.intersect_segment(point-Vector3(0,0,0.1),point+Vector3(0,0,0.1))
			supported = supported and not hit.is_empty()
			if not hit.is_empty():
				var gap: float = hit.position.z-point.z
				minimum = minf(minimum,gap)
				maximum = maxf(maximum,gap)
				supported = supported and gap>0.0003 and gap<0.012
			samples += 1
		if not supported: print("PANEL_TRIM_GAP: ",label,"/",blend," min=",minimum," max=",maximum)
		check(supported and samples>100,"red trim stays above and within the actual panel: "+label+"/"+str(blend))
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := Model.create(holder)
	var saved: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	holder.add_child(saved)
	for model: Node3D in [rig.root,saved]:
		for side in [-1,1]:
			var panel: MeshInstance3D = model.get_node("Pelvis/Skirt"+str(side)+"/CoatPanel")
			var trim: MeshInstance3D = model.get_node("Pelvis/Skirt"+str(side)+"/PanelTrim")
			check_mesh(panel.mesh,"panel/"+str(side))
			check_mesh(trim.mesh,"trim/"+str(side))
			check_trim(panel.mesh,trim.mesh,str(side))
		for part in model.get_node("Skeleton3D").get_children():
			if part is MeshInstance3D and part.get_meta("source_part","") in ["CoatPanel","PanelTrim"]: check_mesh(part.mesh,"rendered/"+str(part.name))
	print("CLOTH_PANEL_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
