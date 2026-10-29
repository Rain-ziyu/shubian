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
func closed(mesh: Mesh) -> bool:
	var points := mesh.get_faces()
	var edges := {}
	for triangle in range(0,points.size(),3):
		for edge in 3:
			var a := str(Vector3i((points[triangle+edge]*1000000).round()))
			var b := str(Vector3i((points[triangle+(edge+1)%3]*1000000).round()))
			var key := a+"|"+b if a<b else b+"|"+a
			edges[key] = int(edges.get(key,0))+1
	for count in edges.values():
		if count!=2: return false
	return true
func check_frame(mesh: Mesh, label: String) -> void:
	var shape := mesh.generate_triangle_mesh()
	for height in [-0.006,0.006]:
		check(shape.intersect_segment(Vector3(0,height,-0.03),Vector3(0,height,0.03)).is_empty(),"buckle center is a real opening: "+label)
	check(not shape.intersect_segment(Vector3(0,0.017,-0.03),Vector3(0,0.017,0.03)).is_empty(),"solid upper rail surrounds the opening: "+label)
	var inner := shape.intersect_segment(Vector3.ZERO,Vector3(0.05,0,0.015))
	check(not inner.is_empty() and absf(inner.position.x-0.023)<0.00001 and inner.normal.x< -0.8,"inner wall has actual depth and an inward-facing normal: "+label)
	check(closed(mesh),"beveled frame is one closed ring: "+label)
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := Model.create(holder)
	var saved: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	holder.add_child(saved)
	for model: Node3D in [rig.root,saved]:
		var found := 0
		for source in model.get_node("Pelvis").get_children():
			if not source is MeshInstance3D or not source.has_meta("belt_fitting"): continue
			found += 1
			var fitting: String = source.get_meta("belt_fitting")
			check(source.scale.is_equal_approx(Vector3.ONE),"fitting uses physical mesh dimensions: "+fitting)
			check(source.material_override is StandardMaterial3D and source.material_override.metallic>0.5 and source.material_override.albedo_texture!=null and source.material_override.roughness_texture!=null,"fitting carries the authored metal finish: "+fitting)
			check(closed(source.mesh),"fitting has no open edges: "+fitting)
			check(absf(source.position.x-0.055)<0.00001 and absf(source.position.y-0.107)<0.00001,"original belt attachment position is retained: "+fitting)
			if fitting=="frame":
				var belt: MeshInstance3D = model.get_node("Pelvis/Belt")
				var belt_surface := belt.mesh.generate_triangle_mesh()
				var hardware: TriangleMesh = source.mesh.generate_triangle_mesh()
				for x in [-0.03,0.03]:
					var back: Dictionary = hardware.intersect_segment(Vector3(x,0,0.04),Vector3(x,0,-0.04))
					var point := belt.to_local(source.to_global(back.position))
					var contact := belt_surface.intersect_segment(Vector3(point.x,point.y,-1),Vector3(point.x,point.y,1))
					var gap: float = contact.position.z-point.z
					print("BELT_SUPPORT_GAP: ",x," / ",gap)
					check(gap>0 and gap<0.005,"frame sides remain within 5mm of the actual leather belt")
				check_frame(source.mesh,"source")
				var box: AABB = source.mesh.get_aabb()
				check(Vector2(box.size.x,box.size.y).distance_to(Vector2(0.07,0.044))<0.000001,"curved frame retains its original outer width and height")
				for x in [-0.03,0.03]:
					var front := hardware.intersect_segment(Vector3(x,0,-0.04),Vector3(x,0,0.04))
					var back := hardware.intersect_segment(Vector3(x,0,0.04),Vector3(x,0,-0.04))
					check(not front.is_empty() and not back.is_empty() and absf(back.position.z-front.position.z-0.013)<0.00001,"curving the frame retains its 13mm material depth")
				for rendered in model.get_node("Skeleton3D").get_children():
					if not rendered is MeshInstance3D or rendered.get_meta("source_part","")!=str(source.name): continue
					var arrays: Array = rendered.mesh.surface_get_arrays(0)
					var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var local: Transform3D = source.global_transform.affine_inverse()*model.global_transform
					for index in points.size(): points[index] = local*points[index]
					arrays[Mesh.ARRAY_VERTEX] = points
					var mesh := ArrayMesh.new()
					mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
					check_frame(mesh,"rendered")
			else:
				check(source.mesh.get_aabb().size.y<0.005 and source.mesh.get_aabb().size.x>0.05,"tongue is a narrow closure bar rather than a filled plate")
		check(found==2,"runtime and saved belt retain exactly two existing fittings")
	print("BELT_FITTING_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
