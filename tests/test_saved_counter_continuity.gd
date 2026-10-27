extends "res://tests/test_counter_cloth.gd"
func run() -> void:
	var model: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	root.add_child(model)
	var skeleton: Skeleton3D = model.get_node("Skeleton3D")
	var animation: AnimationPlayer = model.get_node("AnimationPreview")
	var weapon: Node3D = model.get_node("Trident")
	var live := preload("res://scripts/player.gd").new()
	root.add_child(live)
	live.set_physics_process(false)
	live.set_process_input(false)
	live.combat.drawn = true
	live.pitch = -0.25
	live.combat.set_action("guard")
	live.combat.elapsed = 1.4
	live.animate(0,0)
	live.combat.set_action("reply")
	animation.play("reply")
	animation.seek(0,true)
	var previous := {}
	for side in ["Left","Right"]:
		previous[side] = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(side+"UpperArm"))*Vector3(0,0.195,0))
	var peak := 0.0
	var grip_error := 0.0
	var crossings := {}
	for frame in 100:
		var time := minf(0.82,frame/120.0)
		live.combat.elapsed = time
		live.animate(0 if frame==0 else minf(1.0/120,0.82-(frame-1)/120.0),0)
		animation.seek(time,true)
		for side in ["Left","Right"]:
			var elbow: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(side+"UpperArm"))*Vector3(0,0.195,0))
			peak = maxf(peak,elbow.distance_to(previous[side]))
			previous[side] = elbow
		var hand: Vector3 = weapon.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("RightHand")).origin))
		grip_error = maxf(grip_error,hand.distance_to(Vector3(0,live.right_hand_grip,0)))
		for label in shaft_hits_for(skeleton,weapon,true):
			if not crossings.has(label): crossings[label] = time
	print("SAVED_COUNTER_CONTINUITY: max_elbow_step=",peak," max_grip_error=",grip_error," crossings=",crossings)
	check(peak<0.10,"Saved counter has no elbow displacement above 10 cm per 120Hz sample")
	check(grip_error<0.015,"Saved counter retains its physical right-hand grip between baked keys")
	check(crossings.is_empty(),"Saved counter shaft clears actual clothing and head throughout the clip")
	print("SAVED_COUNTER_CONTINUITY_CHECKS: ",checks," FAILURES: ",failures)
	model.queue_free()
	live.queue_free()
	await process_frame
	quit(1 if failures else 0)
