extends SceneTree
var world: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	# Bake against canonical flat ground, not the initial airborne spawn.
	p.global_position = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.lock_target = null
	p.yaw = 0
	p.rig.root.rotation.y = 0
	p.velocity = Vector3.DOWN
	p.move_and_slide()
	p.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	var library := AnimationLibrary.new()
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): requested = argument.trim_prefix("--only=")
	if not requested.is_empty():
		library = load("res://resources/animations/trident_library.tres").duplicate(true)
		if not library.has_animation(requested):
			printerr("Unknown existing animation: ",requested)
			quit(2)
			return
	var skeleton: Skeleton3D = p.rig.skinning.skeleton
	for action in ["idle","light","heavy","pull","turn","guard","reply","flash","throw","fourfold","spin","plant","wait","counter_window","finisher","dodge","hurt"]:
		if not requested.is_empty() and action!=requested: continue
		if requested=="reply":
			# A counter starts from the successful guard, not a previous clip.
			p.combat.drawn = true
			p.combat.set_action("guard")
			p.combat.elapsed = 1.4
			p.animate(0,0)
		var clip := Animation.new()
		clip.length = float(p.Combat.MOVES.get(action,{"duration":1}).duration)
		if action=="wait": clip.length = 1.0
		if action in ["idle","wait"]: clip.loop_mode = Animation.LOOP_LINEAR
		for bone in range(1,skeleton.get_bone_count()):
			for kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
				var track := clip.add_track(kind)
				clip.track_set_path(track,NodePath("Skeleton3D:"+skeleton.get_bone_name(bone)))
		var pos_track := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(pos_track,NodePath("Trident"))
		var rot_track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(rot_track,NodePath("Trident"))
		var body_track := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(body_track,NodePath("."))
		var body_rotation_track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(body_rotation_track,NodePath("."))
		var finger_tracks := []
		for binding in p.rig.skinning.bindings:
			if binding.rendered.get_blend_shape_count()>0:
				var track := clip.add_track(Animation.TYPE_BLEND_SHAPE)
				clip.track_set_path(track,NodePath("Skeleton3D/"+str(binding.rendered.name)+":"+str(binding.rendered.mesh.get_blend_shape_name(0))))
				finger_tracks.append({"track":track,"rendered":binding.rendered})
		p.combat.set_action(action)
		p.combat.drawn = true
		var sample_rate := 60.0 if action=="reply" else 30.0
		var frames := ceili(clip.length*sample_rate)
		var sampled_time := 0.0
		for frame in range(frames+1):
			var t := minf(clip.length,frame/sample_rate)
			if action=="reply" and frame>0:
				# The counter uses the preceding elbow pose. Preserve its actual
				# 120Hz transport; 60Hz keys also keep its hand on the fast shaft.
				while sampled_time<t:
					var next_time := minf(t,sampled_time+1.0/120)
					p.combat.elapsed = next_time
					p.animate(next_time-sampled_time,0)
					sampled_time = next_time
			else:
				p.combat.elapsed = t
				p.animate(0,0)
				sampled_time = t
			for bone in range(1,skeleton.get_bone_count()):
				clip.position_track_insert_key((bone-1)*2,t,skeleton.get_bone_pose_position(bone))
				clip.rotation_track_insert_key((bone-1)*2+1,t,skeleton.get_bone_pose_rotation(bone))
			for finger in finger_tracks: clip.blend_shape_track_insert_key(finger.track,t,finger.rendered.get_blend_shape_value(0))
			clip.position_track_insert_key(pos_track,t,p.rig.weapon.position)
			clip.rotation_track_insert_key(rot_track,t,p.rig.weapon.quaternion)
			clip.position_track_insert_key(body_track,t,p.rig.root.position)
			clip.rotation_track_insert_key(body_rotation_track,t,p.rig.root.quaternion)
		if library.has_animation(action): library.remove_animation(action)
		library.add_animation(action,clip)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/animations"))
	var error := ResourceSaver.save(library,"res://resources/animations/trident_library.tres")
	print("BAKED_ANIMATIONS: ",library.get_animation_list().size()," RESULT: ",error)
	world.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
