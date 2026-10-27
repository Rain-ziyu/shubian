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
func check_teeth(parent: Node3D, surface_node: MeshInstance3D, scale: float, upper: bool, species: String) -> void:
	var surface_mesh := surface_node.mesh.generate_triangle_mesh()
	var count := 0
	var projected := true
	var seated := true
	var worst := 0.0
	var closed := true
	var enamel := true
	var shortest := INF
	var longest := 0.0
	var curved := true
	var caps_present := true
	for child in parent.get_children():
		if not child is MeshInstance3D or not child.get_meta("dental_tooth",false): continue
		count += 1
		var bounds: AABB = child.mesh.get_aabb()
		shortest = minf(shortest,bounds.size.y)
		longest = maxf(longest,bounds.size.y)
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tip_y := bounds.position.y if upper else bounds.end.y
		var tip_z := 0.0
		var tip_samples := 0
		for point in vertices:
			if absf(point.y-tip_y)>scale*0.00001: continue
			tip_z += point.z
			tip_samples += 1
		if tip_samples==0: curved = false
		elif species=="reedclaw": curved = curved and tip_z/tip_samples>scale*0.019
		elif species=="mossback": curved = curved and tip_z/tip_samples>0 and tip_z/tip_samples<scale*0.005

		var edges := {}
		for triangle in range(0,vertices.size(),3):
			for edge in 3:
				var a := str(Vector3i((vertices[triangle+edge]*1000000).round()))
				var b := str(Vector3i((vertices[triangle+(edge+1)%3]*1000000).round()))
				var key := a+"|"+b if a<b else b+"|"+a
				edges[key] = int(edges.get(key,0))+1
		for adjacent: int in edges.values(): closed = closed and adjacent==2
		var shades := {}
		for color: Color in arrays[Mesh.ARRAY_COLOR]: shades[color] = true
		enamel = enamel and shades.size()>2 and child.material_override.vertex_color_use_as_albedo

		var root_samples := 0
		for index in vertices.size():
			if normals[index].y*(1 if upper else -1)<0.99: continue
			root_samples += 1
			var point: Vector3 = child.transform*vertices[index]
			if surface_node!=parent: point = surface_node.transform.affine_inverse()*point
			var start := Vector3(point.x,-scale*0.25 if upper else scale*0.25,point.z)
			var end := Vector3(point.x,scale*0.40 if upper else -scale*0.25,point.z)
			var hit := surface_mesh.intersect_segment(start,end)
			projected = projected and not hit.is_empty()
			if hit.is_empty(): continue
			var embed: float = (point.y-hit.position.y)*(1 if upper else -1)
			worst = maxf(worst,absf(embed))
			seated = seated and embed>=scale*0.0005 and embed<=scale*0.025
		caps_present = caps_present and root_samples>=16
	check(count==10 and caps_present and projected,"all ten tooth roots have real jaw attachment surfaces")
	check(seated,"entire tooth root caps are seated without floating or excessive burial")
	check(count==10 and closed,"all curved teeth are closed meshes with two faces per edge")
	check(count==10 and enamel,"enamel color variation is stored and enabled in the tooth materials")
	check(longest/shortest>1.20,"dental row has visibly varied crown heights")
	check(curved,"tooth tip curvature follows the species dental silhouette")
	print("TOOTH_ROOT_DEVIATION: upper=",upper," max_embed=",worst)
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
		var resting_basis := jaw.basis
		var uncanted_tip := hinge+tip
		check(closed.y-uncanted_tip.y>float(data.size)*0.02,"resting mandible closes the former idle mouth gap")
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
		var head: MeshInstance3D = neck.get_node("HeadSurface")
		check(head.has_node("MouthRoof"),"upper palate stays attached to the cranium")
		var roof: MeshInstance3D = head.get_node("MouthRoof")
		var roof_arrays: Array = roof.mesh.surface_get_arrays(0)
		var roof_points: PackedVector3Array = roof_arrays[Mesh.ARRAY_VERTEX]
		var roof_normals: PackedVector3Array = roof_arrays[Mesh.ARRAY_NORMAL]
		var skull := head.mesh.generate_triangle_mesh()
		var roof_fitted := true
		var roof_downward := true
		for index in roof_points.size():
			var point: Vector3 = roof.transform*roof_points[index]
			var contact := skull.intersect_segment(Vector3(point.x,-float(data.size)*0.25,point.z),Vector3(point.x,float(data.size)*0.40,point.z))
			roof_fitted = roof_fitted and not contact.is_empty()
			if not contact.is_empty():
				var clearance: float = contact.position.y-point.y
				roof_fitted = roof_fitted and clearance>float(data.size)*0.0005 and clearance<float(data.size)*0.003
			roof_downward = roof_downward and roof_normals[index].y< -0.2
		check(roof_fitted,"upper palate follows the actual skull underside with bounded clearance")
		check(roof_downward,"upper palate normals face the mouth opening")
		check(saved.get_node("Neck/HeadSurface/MouthRoof").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==roof_points,"saved upper palate matches runtime geometry")
		var saved_neck: Node3D = saved.get_node("Neck")
		var saved_jaw: MeshInstance3D = saved.get_node("Neck/Jaw")
		check_teeth(saved_neck,saved_neck.get_node("HeadSurface"),float(data.size),true,str(data.id))
		check_teeth(saved_jaw,saved_jaw,float(data.size),false,str(data.id))
		saved.queue_free()
		check_teeth(neck,neck.get_node("HeadSurface"),float(data.size),true,str(data.id))
		check_teeth(jaw,jaw,float(data.size),false,str(data.id))
		var loaded := Model.jaw_pose(data,"windup",float(data.windup))
		check(loaded.is_equal_approx(Model.jaw_pose(data,"active",0)),"jaw joins anticipation to attack without a snap")
		check(Model.jaw_pose(data,"active",0.65).is_equal_approx(Model.jaw_pose(data,"recover",0)),"jaw joins attack to recovery without a snap")
		Model.animate(mesh,data,0,"recover",float(data.recovery),0)
		check(jaw.basis.is_equal_approx(resting_basis) and jaw.position.distance_to(hinge)<0.001,"recovery returns the mouth to its authored rest shape")
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
