extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
var maximum_gap := 0.0
var maximum_stretch := 1.0
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
	var data: Dictionary
	for species in database.species:
		if species.id=="stormcrest": data = species
	var live := Model.create(holder,data)
	var saved: Node3D = load("res://assets/models/stormcrest-v1.tscn").instantiate()
	holder.add_child(saved)
	for model in [live,saved]:
		var body: MeshInstance3D = model.get_node("BodySurface")
		var head: MeshInstance3D = model.get_node("Neck/HeadSurface")
		var skeleton: Skeleton3D = body.get_node("NeckSkeleton")
		var torso: MeshInstance3D = skeleton.get_node("Skin_BodySurface")
		var skull: MeshInstance3D = head.get_node("Skin_HeadSurface")
		check(body.layers==0 and head.layers==0 and torso.layers==1 and skull.layers==1,"rendered skins replace source drawing without hiding mouth children")
		check(head.visible and head.get_node("MouthRoof").is_visible_in_tree(),"upper palate stays visible with the retained contact head")
		check(skeleton.get_bone_count()==2 and torso.skin.get_bind_count()==2 and torso.skeleton==NodePath(".."),"torso and neck use two explicit skin bindings")
		var arrays: Array = torso.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var valid := weights.size()==points.size()*4 and bones.size()==weights.size()
		for index in points.size():
			# Mesh storage quantizes skin weights to 16 bits per component.
			valid = valid and absf(weights[index*4]+weights[index*4+1]-1.0)<0.00004 and weights[index*4]>=0 and weights[index*4+1]>=0
		check(valid,"every visible torso vertex has normalized nonnegative skin weights")
		var end := -INF
		for point: Vector3 in skull.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: end = maxf(end,point.z)
		check(absf(end+float(data.size)*0.28)<0.00002,"visible skull ends at the shared neck ring")
		check(torso.get_instance_shader_parameter("neck_transition")==1.0 and arrays[Mesh.ARRAY_TEX_UV2].size()==points.size(),"material transition is saved on the actual rendered torso")
		var poses := [["idle",0.0,{}],["windup",0.1,{}],["windup",float(data.windup),{}],["active",0.15,{}],["recover",0.2,{}],["stagger",0.12,{"neck_rotation":Vector3(-0.22,0.45,0),"body_surface_rotation":Vector3(0,0,0.1)}]]
		for pose in poses:
			Model.animate(model,data,0,pose[0],pose[1],0,Callable(),Callable(),false,pose[2])
			var front := INF
			for point in points: front = minf(front,point.z)
			var unique := {}
			for point: Vector3 in head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if absf(point.z+float(data.size)*0.28)<0.00001: unique[point.snapped(Vector3.ONE*0.00001)] = point
			var ring: Array = unique.values()
			var center_y := float(data.size)*0.14
			ring.sort_custom(func(a: Vector3,b: Vector3) -> bool: return atan2(a.x,a.y-center_y)<atan2(b.x,b.y-center_y))
			var gap := 0.0
			var samples := 0
			var deformed := PackedVector3Array()
			for index in points.size():
				var vertex := Vector3.ZERO
				for slot in 4:
					var bone := bones[index*4+slot]
					vertex += (skeleton.get_bone_global_pose(bone)*torso.skin.get_bind_pose(bone)*points[index])*weights[index*4+slot]
				deformed.append(vertex)
				if absf(points[index].z-front)>0.00001: continue
				var local := head.to_local(body.to_global(vertex))
				var distance := INF
				for edge in ring.size(): distance = minf(distance,local.distance_to(Geometry3D.get_closest_point_to_segment(local,ring[edge],ring[(edge+1)%ring.size()])))
				gap = maxf(gap,distance)
				samples += 1
			maximum_gap = maxf(maximum_gap,gap)
			check(samples>100 and gap<0.0015,"posed torso/skull boundary remains within 1.5mm: "+pose[0])
			var stretch := 1.0
			var worst := {}
			for triangle in range(0,points.size(),3):
				for edge in 3:
					var a := triangle+edge
					var b := triangle+(edge+1)%3
					var rest := points[a].distance_to(points[b])
					if rest>0.005:
						var ratio := deformed[a].distance_to(deformed[b])/rest
						if ratio>stretch:
							stretch = ratio
							worst = {"a":points[a],"b":points[b],"weights_a":weights[a*4+1],"weights_b":weights[b*4+1]}
			if stretch>=1.4: print("NECK_STRETCH_DETAIL: ",worst)
			maximum_stretch = maxf(maximum_stretch,stretch)
			check(stretch<1.40,"posed transition does not stretch an edge over 40 percent: "+pose[0])
			check(skeleton.get_bone_global_pose(0).is_equal_approx(Transform3D.IDENTITY),"rear torso stays rigid in the body frame: "+pose[0])
			var posed_arrays := []
			posed_arrays.resize(Mesh.ARRAY_MAX)
			posed_arrays[Mesh.ARRAY_VERTEX] = deformed
			var posed_mesh := ArrayMesh.new()
			posed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,posed_arrays)
			var posed_surface := posed_mesh.generate_triangle_mesh()
			for index in 5:
				var crest: MeshInstance3D = model.get_node("Crest"+str(index))
				var box := crest.mesh.get_aabb()
				var supported := true
				for vertex: Vector3 in crest.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					if absf(vertex.z-box.position.z)>0.0001 and absf(vertex.z-box.end.z)>0.0001: continue
					var point := body.to_local(crest.to_global(vertex))
					var high := posed_surface.intersect_segment(Vector3(point.x,float(data.size)*2,point.z),Vector3(point.x,-float(data.size)*2,point.z))
					var low := posed_surface.intersect_segment(Vector3(point.x,-float(data.size)*2,point.z),Vector3(point.x,float(data.size)*2,point.z))
					supported = supported and not high.is_empty() and not low.is_empty()
					if not high.is_empty() and not low.is_empty(): supported = supported and point.y<high.position.y-float(data.size)*0.001 and point.y>low.position.y+float(data.size)*0.001
				check(supported,"crest root stays inside the rendered deformed body: "+str(index)+"/"+pose[0])
	print("CREATURE_NECK_METRICS: gap_m=",maximum_gap," max_edge_ratio=",maximum_stretch)
	print("CREATURE_NECK_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
