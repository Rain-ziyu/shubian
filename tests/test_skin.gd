extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	root.add_child(model)
	await process_frame
	var skeleton := model.get_node("Skeleton3D") as Skeleton3D
	check(skeleton.get_bone_count()>20,"model has saved skeletal structure")
	var bound := 0
	var descendants := 0
	var blended_waist := false
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone)>0: descendants += 1
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			check(child.skin!=null and child.skin.get_bind_count()==skeleton.get_bone_count(),"skin binds available")
			var arrays: Array = child.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_BONES].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"vertex bone indices stored")
			var valid_weights := true
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for vertex in arrays[Mesh.ARRAY_VERTEX].size():
				var total := 0.0
				for slot in 4: total += weights[vertex*4+slot]
				# Two-bone blends can lose one 16-bit step when ArrayMesh packs weights.
				valid_weights = valid_weights and absf(total-1)<=1.1/65535
			if child.get_meta("source_part","")=="Undercoat":
				for weight in arrays[Mesh.ARRAY_WEIGHTS]:
					if weight>0.01 and weight<0.99: blended_waist = true
			check(valid_weights,"every vertex weight sum is normalized within packed precision")
			bound += 1
	check(bound>20 and descendants>=8,"arm hand and leg foot hierarchy with bound meshes")
	check(skeleton.find_bone("Spine")>=0,"saved spine bone exists")
	check(blended_waist,"saved waist contains blended rather than rigid-only weights")
	for side in ["Left","Right"]:
		var thigh := skeleton.find_bone(side+"Thigh")
		var shin := skeleton.find_bone(side+"Shin")
		var foot := skeleton.find_bone(side+"Foot")
		check(thigh>=0 and shin>=0 and foot>=0,"saved anatomical leg bone names")
		if thigh>=0 and shin>=0 and foot>=0:
			check(skeleton.get_bone_parent(shin)==thigh and skeleton.get_bone_parent(foot)==shin,"saved thigh shin foot hierarchy")
	var player := model.get_node("AnimationPreview") as AnimationPlayer
	check(player.get_animation_list().size()==17,"all seventeen preview clips saved")
	check(is_equal_approx(player.get_animation("reply").length,0.82),"saved counter sweep has its updated duration")
	player.play("reply")
	player.seek(0.40,true)
	var counter_weapon: Node3D = model.get_node("Trident")
	var main_hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
	var free_hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand"))
	check(main_hand.origin.distance_to(counter_weapon.transform*Vector3(0,preload("res://scripts/hunter_model.gd").counter_grip(0.36),0))<0.002,"saved counter sweep keeps the right hand on the shaft")
	check(free_hand.origin.distance_to(counter_weapon.transform*Vector3(0,0.18,0))>0.10,"saved counter sweep releases the left hand")
	player.play("heavy")
	player.advance(0)
	var before: Quaternion = model.get_node("Trident").quaternion
	var spine_before := skeleton.get_bone_global_pose(skeleton.find_bone("Spine")).basis.get_rotation_quaternion()
	player.advance(0.18)
	var after: Quaternion = model.get_node("Trident").quaternion
	check(before.angle_to(after)>0.1,"saved clip actually animates the weapon")
	check(spine_before.angle_to(skeleton.get_bone_global_pose(skeleton.find_bone("Spine")).basis.get_rotation_quaternion())>0.05,"saved clip actually animates spine")
	player.play("finisher")
	player.advance(0.95)
	var foot_bone := skeleton.find_bone("RightFoot")
	if foot_bone>=0:
		var foot_pose := skeleton.get_bone_global_pose(foot_bone)
		check(foot_pose.origin.z< -0.6 and foot_pose.origin.y>0.6,"saved finisher actually raises and extends kicking foot")
		check(foot_pose.basis.y.normalized().z>0.69,"saved finisher retains the forward-facing sole tilt")
	player.play("throw")
	player.advance(0)
	player.advance(0.33)
	var finger_parts := 0
	for part in skeleton.get_children():
		if not part is MeshInstance3D or part.get_blend_shape_count()==0: continue
		if part.mesh.get_blend_shape_name(0)!="OpenHand": continue
		finger_parts += 1
		check(absf(part.get_blend_shape_value(0)-0.5)<0.06,"saved throw clip progressively opens rendered fingers")
	check(finger_parts==2,"saved model retains both hand blend shapes")
	for action in ["plant","wait"]:
		player.play(action)
		player.advance(0)
		player.advance(0.60)
		var tip: Marker3D = model.get_node("Trident/TipContact")
		check(absf(tip.global_position.y+0.025)<0.015,"saved planted animation retains canonical floor contact: "+action)
	player.play("turn")
	player.advance(0)
	player.advance(0.30)
	check(absf(wrapf(model.rotation.y,-PI,PI))>1,"saved turn clip rotates full character")
	var phase := smoothstep(0.10,0.58,0.30)
	var weapon_position := Vector3(0,1.20,-0.32).rotated(Vector3.UP,TAU*phase)+Vector3(0,0,0.07*sin(phase*PI))
	var expected_basis := Basis.from_euler(Vector3(-PI/2,-1.5+0.30/0.95*TAU,-0.15))
	var expected_tip: Vector3 = model.position+weapon_position+expected_basis*Vector3(0,1.2,0)
	check(model.get_node("Trident/TipContact").global_position.distance_to(expected_tip)<0.003,"saved root rotation preserves compensated weapon trajectory")
	check(model.get_node("Trident").position.z< -0.20,"saved ordinary turn carries its grip ahead of the rotating chest")
	player.seek(0.20,true)
	var right_foot: int = skeleton.find_bone("RightFoot")
	var support_pose: Transform3D = skeleton.get_bone_global_pose(right_foot)
	var support_ankle: Vector3 = skeleton.global_transform*(support_pose.origin-support_pose.basis*Vector3(0,-0.025,-0.06))
	player.seek(7.0/30.0,true)
	support_pose = skeleton.get_bone_global_pose(right_foot)
	var support_after: Vector3 = skeleton.global_transform*(support_pose.origin-support_pose.basis*Vector3(0,-0.025,-0.06))
	check(support_after.distance_to(support_ankle)<0.003,"saved turn retains stance ankle position across sampled keys")
	print("SKIN_CHECKS: ",checks," FAILURES: ",failures)
	model.queue_free()
	await process_frame
	quit(1 if failures else 0)
