extends SceneTree
const Outfit = preload("res://scripts/hunter_outfit.gd")
const Model = preload("res://scripts/hunter_model.gd")
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
	var profile := Outfit.loft(holder,"NormalProbe",[Vector4(0,0.1,0.1,0),Vector4(1,0.1,0.1,0)],Color.WHITE)
	var arrays: Array = profile.mesh.surface_get_arrays(0)
	var alignment := 0.0
	for index in 28*6:
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		alignment += Vector3(point.x,0,point.z).normalized().dot(normal)
	check(alignment/(28*6)>0.9,"profile mesh normals face outward")
	var rig := Model.create(holder)
	check(rig.root.has_node("Torso/Head") and rig.root.has_node("Torso/HairCap"),"head and hair are separate editable meshes")
	check(rig.root.has_node("Torso/RainCape1") and rig.root.has_node("Torso/RainCape-1"),"split cape panels exist")
	check(rig.weapon.has_node("CenterBlade") and rig.weapon.has_node("Hook1") and rig.weapon.has_node("Hook-1"),"three blade silhouettes exist")
	check(rig.weapon.has_node("Grip") and rig.weapon.has_node("Butt") and rig.weapon.has_node("JadeCell"),"grip butt and jade insert remain separate")
	for label in ["CenterBlade","Hook-1","Hook1"]:
		var blade_arrays: Array = rig.weapon.get_node(label).mesh.surface_get_arrays(0)
		var points: PackedVector3Array = blade_arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = blade_arrays[Mesh.ARRAY_NORMAL]
		var edges := {}
		var outward := true
		var bevel := false
		for index in points.size():
			if absf(points[index].z)>0.0119:
				outward = outward and points[index].z*normals[index].z>0
			bevel = bevel or (absf(normals[index].z)>0.05 and absf(normals[index].z)<0.95)
		for triangle in range(0,points.size(),3):
			for edge in 3:
				var a := str(Vector3i((points[triangle+edge]*1000000).round()))
				var b := str(Vector3i((points[triangle+(edge+1)%3]*1000000).round()))
				var key := a+"|"+b if a<b else b+"|"+a
				edges[key] = int(edges.get(key,0))+1
		var closed := true
		for count in edges.values(): closed = closed and count==2
		check(closed,"blade bevel remains a closed surface: "+label)
		check(outward and bevel,"blade has outward broad faces and distinct angled bevel normals: "+label)
	var grip: MeshInstance3D = rig.weapon.get_node("Grip")
	check(grip.position.y-grip.mesh.height/2<=-0.28 and grip.position.y+grip.mesh.height/2>=0.18,"existing hand grip points fit new wrapped handle")
	check(is_equal_approx(rig.weapon.get_node("TipContact").position.y,1.2) and is_equal_approx(rig.weapon.get_node("ButtContact").position.y,-0.98),"combat endpoints preserved in model markers")
	Model.pose_legs(rig,"finisher",0.95,true,0,0,0)
	check(rig.skirts[1].rotation.x>0.4,"coat panel opens with kicking thigh")
	Model.pose_arms(rig,false,0)
	for side in [-1,1]:
		check(rig.arms[side].elbow.position.distance_to(rig.arms[side].hand.position)>0.38,"relaxed arm remains full length")
	print("COSTUME_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
