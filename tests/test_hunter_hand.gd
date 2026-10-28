extends SceneTree
const H = preload("res://scripts/hunter_model.gd")
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
	var rig := H.create(holder)
	for side in [-1,1]:
		var hand: MeshInstance3D = rig.arms[side].hand
		var arrays := hand.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var min_radius := INF
		for p in points: min_radius = minf(min_radius,Vector2(p.x,p.z).length())
		check(min_radius>0.0305,"glove mesh clears wrapped shaft: "+str(side))
		check(hand.mesh is ArrayMesh and points.size()>2000,"hand contains original palm and digit geometry")
		check(arrays[Mesh.ARRAY_COLOR].size()==points.size(),"glove panels retain vertex colors")
	for rotation in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(0,0,PI/2),Vector3(0.4,0.7,-1.1)]:
		rig.weapon.position = Vector3(0,1.15,-0.35)
		rig.weapon.rotation = rotation
		H.pose_arms(rig,true,0)
		rig.skinning.skeleton.force_update_all_bone_transforms()
		for side in [-1,1]:
			var hand: MeshInstance3D = rig.arms[side].hand
			check(hand.basis.y.dot(rig.weapon.basis.y)>0.999,"fingers align with shaft through rotation")
			var forearm: MeshInstance3D = rig.arms[side].lower
			var cuff_y := forearm.mesh.get_aabb().end.y
			var axis: Vector3 = (rig.arms[side].elbow.position-hand.position).normalized()
			var palm_clearance := INF
			for point: Vector3 in forearm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if absf(point.y-cuff_y)>0.00001: continue
				palm_clearance = minf(palm_clearance,(forearm.to_global(point)-hand.global_position).dot(axis))
			var local_axis := hand.global_basis.inverse()*axis
			# Exact support of the palm ellipsoid in the forearm direction.
			# The grip frame intentionally bends the wrist relative to this axis.
			var palm_extent := Vector3(0.057,0,0).dot(local_axis)+Vector3(local_axis.x*0.0225,local_axis.y*0.05,local_axis.z*0.0325).length()
			print("WRIST_CLEARANCE: ",side," cuff=",palm_clearance," palm=",palm_extent)
			check(palm_clearance-palm_extent>0.005 and palm_clearance<0.12,"forearm cuff clears the palm through weapon rotation")
			check(hand.basis.is_finite() and absf(hand.basis.determinant()-1)<0.001,"grip frame remains finite and right handed")
			var label := "LeftHand" if side==-1 else "RightHand"
			var bone: int = rig.skinning.skeleton.find_bone(label)
			check(bone>=0 and rig.skinning.skeleton.get_bone_global_pose(bone).origin.distance_to(hand.position)<0.001,"rendered hand bone follows grip")
	for grip in [0.0,0.5,1.0]:
		H.pose_arms(rig,true,0,grip)
		for side in [-1,1]:
			var source: MeshInstance3D = rig.arms[side].hand
			check(is_equal_approx(source.get_blend_shape_value(0),1-grip),"finger shape follows equipment grip")
			for binding in rig.skinning.bindings:
				if binding.source!=source: continue
				check(binding.rendered.get_blend_shape_count()==1,"rendered skin retains open-hand shape")
				check(is_equal_approx(binding.rendered.get_blend_shape_value(0),1-grip),"rendered fingers follow actual grip weight")
				var closed: PackedVector3Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var opened: PackedVector3Array = source.mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
				var max_motion := 0.0
				for i in closed.size(): max_motion = maxf(max_motion,closed[i].distance_to(opened[i]))
				check(closed.size()==opened.size() and max_motion>0.001,"open fingers deform while preserving vertex correspondence")
	H.pose_arms(rig,false,0)
	check(rig.arms[-1].hand.get_blend_shape_value(0)==1,"unarmed hands relax open")
	print("HUNTER_HAND_CHECKS: ",checks," FAILURES: ",failures)
	holder.free()
	quit(1 if failures else 0)
