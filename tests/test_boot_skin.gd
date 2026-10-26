extends SceneTree
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func verify(source: MeshInstance3D, rendered: MeshInstance3D, skeleton: Skeleton3D, foot: int, shin: int, label: String) -> void:
	var arrays: Array = rendered.mesh.surface_get_arrays(0)
	var originals: PackedVector3Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var cuff_drift := 0.0
	var sole_drift := 0.0
	for index in points.size():
		if originals[index].y<1.2 and not is_equal_approx(originals[index].y,-0.5): continue
		var actual := Vector3.ZERO
		for slot in 4:
			var bone: int = bones[index*4+slot]
			actual += (skeleton.get_bone_global_pose(bone)*rendered.skin.get_bind_pose(bone)*points[index])*weights[index*4+slot]
		if originals[index].y>=1.2:
			var expected := skeleton.get_bone_global_pose(shin)*rendered.skin.get_bind_pose(shin)*points[index]
			cuff_drift = maxf(cuff_drift,actual.distance_to(expected))
		else:
			var expected := skeleton.get_bone_global_pose(foot)*rendered.skin.get_bind_pose(foot)*points[index]
			sole_drift = maxf(sole_drift,actual.distance_to(expected))
	print("BOOT_ATTACHMENT_DEVIATION: ",label," cuff=",cuff_drift," sole=",sole_drift)
	check(cuff_drift<0.002,"upper boot follows the shin through ankle flexion: "+label)
	check(sole_drift<0.0001,"sole retains the exact rigid foot transform: "+label)
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.combat.drawn = true
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	stage.add_child(saved)
	var preview: AnimationPlayer = saved.get_node("AnimationPreview")
	var saved_skeleton: Skeleton3D = saved.get_node("Skeleton3D")
	for sample in [["heavy",0.18],["guard",0.18],["plant",0.48],["finisher",0.95]]:
		p.combat.set_action(sample[0])
		p.combat.elapsed = sample[1]
		p.animate(0,0)
		preview.play(sample[0])
		preview.seek(sample[1],true)
		for side in [-1,1]:
			var prefix := "Left" if side==-1 else "Right"
			for binding in p.rig.skinning.bindings:
				if binding.source==p.rig.legs[side].boot:
					verify(binding.source,binding.rendered,p.rig.skinning.skeleton,p.rig.skinning.skeleton.find_bone(prefix+"Foot"),p.rig.skinning.skeleton.find_bone(prefix+"Shin"),"runtime/"+sample[0]+"/"+prefix)
			for rendered in saved_skeleton.get_children():
				if not rendered is MeshInstance3D or rendered.get_meta("source_part","")!="ForestBoot": continue
				var foot: int = saved_skeleton.find_bone(prefix+"Foot")
				if int(rendered.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES][0])!=foot: continue
				var source: MeshInstance3D = saved.get_node("Leg"+str(side)+"/Knee/Ankle/ForestBoot")
				verify(source,rendered,saved_skeleton,foot,saved_skeleton.find_bone(prefix+"Shin"),"saved/"+sample[0]+"/"+prefix)
	check(checks==32,"all runtime and saved boot samples were found and checked")
	print("BOOT_SKIN_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
