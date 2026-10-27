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
	for label in ["HeadSurface","Jaw","EyeRidge1"]:
		var rounded := Surface.profile(holder,label,[Vector4(-1,0.1,0.2,0),Vector4(0,0.5,0.6,0.1),Vector4(1,0.2,0.3,0)],1,Color.WHITE)
		var points: PackedVector3Array = rounded.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var rounded_section := false
		var within_envelope := true
		for point in points:
			within_envelope = within_envelope and absf(point.x)<=0.5001 and point.y<=0.7001 and point.y>= -0.5001
			if is_equal_approx(point.z,-0.5) and point.x>0.3: rounded_section = true
		check(rounded_section and within_envelope,"rounded head sections preserve authored envelope: "+label)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for data in database.species:
		var model := Model.create(holder,data)
		var saved = load("res://assets/models/"+str(data.id)+"-v1.tscn").instantiate()
		holder.add_child(saved)
		for label in ["BodySurface","Neck/HeadSurface","Neck/Nostril-1","Neck/Nostril1"]:
			var live_mesh: Mesh = model.get_node(label).mesh
			var saved_mesh: Mesh = saved.get_node(label).mesh
			check(live_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==saved_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"saved anatomical relief matches live skin vertices: "+str(data.id)+"/"+label)
			check(live_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]==saved_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL],"saved sculpted skin keeps reconstructed normals: "+str(data.id)+"/"+label)
		for instance in [model,saved]:
			check(instance.has_node("BodySurface") and instance.has_node("Neck/HeadSurface") and instance.has_node("Neck/Jaw"),"live and saved continuous body head jaw: "+str(data.id))
			check(instance.get_node("Tail/TailSurface").mesh is ArrayMesh,"live and saved continuous tail: "+str(data.id))
			check_nasal_relief(instance,float(data.size))
		var body: MeshInstance3D = model.get_node("BodySurface")
		var skin: Array = body.mesh.surface_get_arrays(0)
		check(skin[Mesh.ARRAY_COLOR].size()==skin[Mesh.ARRAY_VERTEX].size(),"surface coloration is saved per vertex")
		var leg := model.get_node("Hind1") as Node3D
		var foot := leg.get_node("Foot") as MeshInstance3D
		check(absf(leg.position.y+foot.position.y-foot.scale.y*0.5)<0.001,"standing foot sole matches actor floor")
		check(leg.has_node("LegSurface") and leg.has_node("Claw0"),"curved limbs and toe claws exist")
		if data.id=="thornhorn":
			for instance in [model,saved]:
				check_horn_roots(instance,float(data.size))
				var skull: MeshInstance3D = instance.get_node("Neck/HeadSurface")
				var surface: TriangleMesh = skull.mesh.generate_triangle_mesh()
				var muzzle_width := 0.0
				for point: Vector3 in skull.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					if absf(point.z+float(data.size)*0.69)<0.001: muzzle_width = maxf(muzzle_width,absf(point.x))
				check(muzzle_width>float(data.size)*0.10,"charging skull has a broad blunt muzzle in live and saved meshes")
				for side in [-1,1]:
					for label in ["Eye","Nostril"]:
						var feature: Node3D = instance.get_node("Neck/"+label+str(side))
						var point: Vector3 = feature.position
						var contact := surface.intersect_segment(Vector3(side*float(data.size)*2,point.y,point.z),Vector3(0,point.y,point.z))
						var clearance: float = absf(point.x)-absf(contact.get("position",Vector3.ZERO).x)
						check(not contact.is_empty() and clearance>0.003*float(data.size) and clearance<0.02*float(data.size),"facial feature sits at visible skull surface: "+label+str(side))
		for instance in [model,saved]:
			var skull: MeshInstance3D = instance.get_node("Neck/HeadSurface")
			var skull_triangles := skull.mesh.generate_triangle_mesh()
			for side in [-1,1]:
				var eye: MeshInstance3D = instance.get_node("Neck/Eye"+str(side))
				var pupil: MeshInstance3D = instance.get_node("Neck/Pupil"+str(side))
				var eye_point := eye.position
				var seat := skull_triangles.intersect_segment(Vector3(side*float(data.size)*2,eye_point.y,eye_point.z),Vector3(0,eye_point.y,eye_point.z))
				check(not seat.is_empty() and absf(eye_point.x)>absf(seat.get("position",Vector3.ZERO).x),"live and saved eye is not buried inside skull: "+str(data.id))
				var eye_triangles := eye.mesh.generate_triangle_mesh()
				var pupil_point := eye.to_local(pupil.global_position)
				var iris_seat := eye_triangles.intersect_segment(Vector3(side*float(data.size),pupil_point.y,pupil_point.z),Vector3(0,pupil_point.y,pupil_point.z))
				# Compare actual pupil vertices in eye-local space; world-size offsets
				# cannot be added to coordinates already divided by eyeball scale.
				var pupil_extent := 0.0
				for vertex: Vector3 in pupil.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					pupil_extent = maxf(pupil_extent,absf(eye.to_local(pupil.to_global(vertex)).x))
				check(not iris_seat.is_empty() and pupil_extent>absf(iris_seat.get("position",Vector3.ZERO).x),"live and saved pupil protrudes beyond eye surface: "+str(data.id))
				var ridge: MeshInstance3D = instance.get_node("Neck/EyeRidge"+str(side))
				var roots := {}
				var ray_cache := {}
				var supported := true
				for vertex: Vector3 in ridge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var point := ridge.transform*vertex
					var yz := Vector2(point.y,point.z)
					if not ray_cache.has(yz): ray_cache[yz] = skull_triangles.intersect_segment(Vector3(side*float(data.size)*2,point.y,point.z),Vector3(0,point.y,point.z))
					var contact: Dictionary = ray_cache[yz]
					if contact.is_empty():
						supported = false
						continue
					var row := roundi(point.z/float(data.size)*1000000)
					var gap: float = side*(point.x-contact.position.x)
					roots[row] = minf(float(roots.get(row,INF)),gap)
				for gap: float in roots.values(): supported = supported and gap<=0.001*float(data.size)
				check(supported and roots.size()>10,"live and saved orbital ridge embeds its root along the skull: "+str(data.id))
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
				var crown: MeshInstance3D = instance.get_node("Neck/HeadSurface")
				var exposed_mesh: Mesh = crown.get_meta("unarmored_mesh")
				check(crown.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]!=exposed_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] and crown.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==exposed_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"live and saved skull protection changes appearance without changing its contact surface")
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

func check_horn_roots(model: Node3D, size: float) -> void:
	var skull: MeshInstance3D = model.get_node("Neck/HeadSurface")
	var triangles := skull.mesh.generate_triangle_mesh()
	for side in [-1,1]:
		var horn: MeshInstance3D = model.get_node("Neck/BrowHorn"+str(side))
		var base_z := horn.mesh.get_aabb().end.z
		var embedded := true
		var sampled := 0
		for vertex: Vector3 in horn.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.z-base_z)>0.0001: continue
			var point := skull.to_local(horn.to_global(vertex))
			var top := triangles.intersect_segment(Vector3(point.x,size*3,point.z),Vector3(point.x,-size*3,point.z))
			var bottom := triangles.intersect_segment(Vector3(point.x,-size*3,point.z),Vector3(point.x,size*3,point.z))
			embedded = embedded and not top.is_empty() and not bottom.is_empty()
			if not top.is_empty() and not bottom.is_empty(): embedded = embedded and point.y<float(top.position.y)-size*0.001 and point.y>float(bottom.position.y)+size*0.001
			sampled += 1
		print("HORN_ROOT_EMBEDDED: side=",side," points=",sampled," inside=",embedded)
		check(sampled>28 and embedded,"whole horn root cap is seated inside the actual skull")

func check_nasal_relief(model: Node3D, size: float) -> void:
	var skull: MeshInstance3D = model.get_node("Neck/HeadSurface")
	var triangles := skull.mesh.generate_triangle_mesh()
	for side in [-1,1]:
		var nose: MeshInstance3D = model.get_node("Neck/Nostril"+str(side))
		var anchor := nose.position
		var seed := triangles.intersect_segment(Vector3(side*size*2,anchor.y,anchor.z),Vector3(0,anchor.y,anchor.z))
		check(not seed.is_empty() and nose.mesh is ArrayMesh,"nasal relief has a real skull attachment")
		if seed.is_empty(): continue
		var normal: Vector3 = seed.normal
		if normal.x*side<0: normal = -normal
		var fitted := true
		var minimum := INF
		var maximum := -INF
		for vertex: Vector3 in nose.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point := nose.transform*vertex
			var hit := triangles.intersect_segment(point+normal*size*0.02,point-normal*size*0.02)
			fitted = fitted and not hit.is_empty()
			if hit.is_empty(): continue
			var distance: float = (point-hit.position).dot(normal)
			minimum = minf(minimum,distance)
			maximum = maxf(maximum,distance)
			fitted = fitted and distance>size*0.0001 and distance<size*0.007
		check(fitted and maximum-minimum>size*0.003,"raised nasal rim and recessed floor follow the actual curved skull")
		check(nose.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and nose.material_override.vertex_color_use_as_albedo and nose.material_override.metallic_specular<0.2,"nasal relief receives matte scene lighting instead of an unshaded black sticker")
