extends SceneTree
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
	var rig := Model.create(holder)
	rig.blink_clock = 3.2
	for frame in 4:
		Model.pose_torso(rig,"idle",0,0,0,1.0/60)
		Model.pose_arms(rig,false,0)
	var channels := 0
	for binding in rig.skinning.bindings:
		var index: int = binding.source.find_blend_shape_by_name("Blink")
		if index<0: continue
		channels += 1
		check(binding.source.get_blend_shape_value(index)>0.99,"normal frame clock closes the eye feature")
		check(binding.rendered.get_blend_shape_value(index)>0.99,"visible skin follows source eyelid shape")
	check(channels==10,"both eyes include white iris glint and two lids")
	for frame in 14:
		Model.pose_torso(rig,"idle",0,0,0,1.0/60)
		Model.pose_arms(rig,false,0)
	check(rig.torso.get_node("EyeWhite1").get_blend_shape_value(0)==0,"normal blink releases rather than leaving eyes shut")
	var clock: float = rig.blink_clock
	Model.pose_torso(rig,"idle",0,0,0,0)
	check(rig.blink_clock==clock,"static sampling does not advance the autonomous blink clock")
	Model.pose_torso(rig,"hurt",0.08,0,0,0)
	Model.pose_arms(rig,true,0)
	check(rig.torso.get_node("EyeWhite1").get_blend_shape_value(0)>0.99,"authored impact briefly closes the eyes")
	Model.pose_torso(rig,"hurt",0.30,0,0,0)
	check(rig.torso.get_node("EyeWhite1").get_blend_shape_value(0)==0,"impact reaction reopens before recovery ends")
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	holder.add_child(saved)
	var saved_channels := 0
	for mesh in saved.get_node("Skeleton3D").get_children():
		if not mesh is MeshInstance3D or mesh.find_blend_shape_by_name("Blink")<0: continue
		saved_channels += 1
		check(mesh.skin!=null and mesh.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED,"exported facial shape remains on visible skinned mesh")
		if str(mesh.get_meta("source_part","")).begins_with("EyeWhite"):
			var open: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var closed: PackedVector3Array = mesh.mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
			check(vertical_span(closed)<vertical_span(open)*0.4,"closed shape physically narrows the white opening")
	check(saved_channels==10,"export preserves every eyelid channel")
	var preview: AnimationPlayer = saved.get_node("AnimationPreview")
	preview.play("hurt")
	preview.advance(0.08)
	var saved_white: MeshInstance3D
	for mesh in saved.get_node("Skeleton3D").get_children():
		if mesh is MeshInstance3D and mesh.get_meta("source_part","")=="EyeWhite1": saved_white = mesh
	check(saved_white!=null and saved_white.get_blend_shape_value(0)>0.9,"saved hurt clip plays the visible eye closure")
	preview.advance(0.30)
	check(saved_white!=null and saved_white.get_blend_shape_value(0)<0.01,"saved hurt clip reopens the eyes")
	print("HUNTER_BLINK_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
func vertical_span(points: PackedVector3Array) -> float:
	var low := INF
	var high := -INF
	for point in points:
		low = minf(low,point.y)
		high = maxf(high,point.y)
	return high-low
