extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
const Skinning = preload("res://scripts/creature_tail_skin.gd")
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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in data.species:
		var live := Model.create(holder,species)
		var saved = load("res://assets/models/"+str(species.id)+"-v1.tscn").instantiate()
		holder.add_child(saved)
		for model in [live,saved]:
			var tail: Node3D = model.get_node("Tail")
			var skeleton := tail.get_node_or_null("TailSkeleton") as Skeleton3D
			check(skeleton!=null,"live and saved tail skeleton: "+str(species.id))
			if skeleton==null: continue
			var rendered: MeshInstance3D = skeleton.get_node("SkinnedTail")
			var source: MeshInstance3D = tail.get_node("TailSurface")
			check(skeleton.get_bone_count()==Contact.profile(source.mesh).size() and rendered.skin.get_bind_count()==skeleton.get_bone_count(),"tail bind chain covers every authored smoothed ring")
			check(not source.visible and rendered.visible and rendered.skeleton==NodePath(".."),"visible tail uses skeletal mesh")
			var arrays := rendered.mesh.surface_get_arrays(0)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normalized := weights.size()==vertices.size()*4
			for i in vertices.size(): normalized = normalized and absf(weights[i*4]+weights[i*4+1]-1)<0.0001
			check(normalized,"tail skin weights normalize")
			var rings := Contact.profile(source.mesh)
			if species.id=="mossback":
				var club_radius := 0.0
				for ring in rings:
					if ring.x>species.size*0.70: club_radius = maxf(club_radius,ring.z)
				check(club_radius>species.size*0.15,"mossback distal club has a distinct broad silhouette")
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var root_color := 0.0
				var club_color := 0.0
				var root_count := 0
				var club_count := 0
				for vertex in vertices.size():
					var value: float = (colors[vertex].r+colors[vertex].g+colors[vertex].b)/3
					if vertices[vertex].z<species.size*0.10:
						root_color += value
						root_count += 1
					if vertices[vertex].z>species.size*0.80:
						club_color += value
						club_count += 1
				check(club_count>0 and root_count>0 and club_color/club_count>root_color/root_count+0.06,"distal bone color distinguishes club from flexible root")
			var mid := Vector3(0,(rings[1].y+rings[2].y)*0.5,(rings[1].x+rings[2].x)*0.5)
			check(absf(Skinning.weights(mid.z,rings).z-0.5)<0.001,"intermediate vertices blend adjacent bones")
			for bone in skeleton.get_bone_count(): skeleton.set_bone_pose_rotation(bone,Quaternion.IDENTITY)
			skeleton.force_update_all_bone_transforms()
			check(Skinning.deform(skeleton,mid,rings).distance_to(mid)<0.001,"inverse binds preserve rest surface")
			var tip := Vector3(0,rings[-1].y,rings[-1].x)
			var initial := Skinning.deform(skeleton,tip,rings)
			Skinning.animate(tail,2.0,"active",0.325)
			var bent := Skinning.deform(skeleton,tip,rings)
			check(bent.distance_to(initial)>0.08,"bone animation bends actual tail tip")
			var contacts := Skinning.contact_profile(tail,rings)
			check(Vector3(contacts[-1].w,contacts[-1].y,contacts[-1].x).distance_to(bent)<0.001,"contact tip follows same skin transforms")
			var chain := true
			for bone in range(1,skeleton.get_bone_count()): chain = chain and skeleton.get_bone_parent(bone)==bone-1
			check(chain,"tail bones form parent chain")
	var old_rings: Array[Vector4] = [Vector4(0,1,0.1,-2),Vector4(2,1,0.1,-2)]
	var new_rings: Array[Vector4] = [Vector4(0,1,0.1,2),Vector4(2,1,0.1,2)]
	check(not Contact.contact(old_rings,Transform3D.IDENTITY,Transform3D.IDENTITY,Vector3(0,0,1)).size(),"old deformed tail starts clear")
	check(not Contact.contact(new_rings,Transform3D.IDENTITY,Transform3D.IDENTITY,Vector3(0,0,1)).size(),"new deformed tail ends clear")
	check(not Contact.contact(new_rings,Transform3D.IDENTITY,Transform3D.IDENTITY,Vector3(0,0,1),null,old_rings).is_empty(),"sweep includes deformation between frames")
	print("CREATURE_TAIL_SKIN_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
