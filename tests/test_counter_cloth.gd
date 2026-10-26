extends SceneTree
## Sample the actual skinned cloth, not the hidden rigid source mesh.
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func surface(part: MeshInstance3D, skeleton: Skeleton3D) -> TriangleMesh:
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var base_points := points.duplicate()
	for shape_index in part.get_blend_shape_count():
		var target: PackedVector3Array = part.mesh.surface_get_blend_shape_arrays(0)[shape_index][Mesh.ARRAY_VERTEX]
		for i in points.size(): points[i] += (target[i]-base_points[i])*part.get_blend_shape_value(shape_index)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var poses: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): poses.append(skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(bone))
	for i in points.size():
		var point := Vector3.ZERO
		for slot in 4: point += (poses[bones[i*4+slot]]*points[i])*weights[i*4+slot]
		points[i] = skeleton.to_global(point)
	var triangle_arrays := []
	triangle_arrays.resize(Mesh.ARRAY_MAX)
	triangle_arrays[Mesh.ARRAY_VERTEX] = points
	triangle_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle_arrays)
	return mesh.generate_triangle_mesh()
func shaft_hits(p: CharacterBody3D, include_head := false) -> Array[String]:
	return shaft_hits_for(p.rig.skinning.skeleton,p.rig.weapon,include_head)
func shaft_hits_for(skeleton: Skeleton3D, weapon: Node3D, include_head := false) -> Array[String]:
	var hits: Array[String] = []
	for part in skeleton.get_children():
		if not part is MeshInstance3D: continue
		var label: String = part.get_meta("source_part","")
		if label!="Undercoat" and not label.begins_with("RainCape") and not (include_head and label=="Head"): continue
		var triangles := surface(part,skeleton)
		for ray in 9:
			var offset := Vector3.ZERO if ray==0 else Vector3(cos((ray-1)*TAU/8)*0.024,0,sin((ray-1)*TAU/8)*0.024)
			if not triangles.intersect_segment(weapon.to_global(Vector3(0,-0.90,0)+offset),weapon.to_global(Vector3(0,0.82,0)+offset)).is_empty():
				hits.append(label)
				break
	return hits
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := preload("res://scripts/player.gd").new()
	p.set_physics_process(false)
	stage.add_child(p)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	p.yaw = 0
	p.pitch = -0.25
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.combat.drawn = true
	p.combat.set_action("reply")
	var crossings := {}
	var lengths_valid := true
	var longest := 0.0
	var longest_time := 0.0
	for frame in 100:
		p.combat.elapsed = 0.82*frame/99
		p.animate(0,0)
		for side in [-1,1]:
			lengths_valid = lengths_valid and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
			if p.rig.arms[side].upper.scale.y>longest:
				longest = p.rig.arms[side].upper.scale.y
				longest_time = p.combat.elapsed
		for label in shaft_hits(p):
			if not crossings.has(label): crossings[label] = []
			crossings[label].append(snappedf(p.combat.elapsed,0.001))
	print("COUNTER_CLOTH_CROSSINGS: ",JSON.stringify(crossings))
	print("COUNTER_CLOTH_ARM: longest=",longest," time=",longest_time)
	check(crossings.is_empty(),"100 neutral-aim counter poses clear actual skinned cape and undercoat along nine shaft rays")
	check(lengths_valid,"counter route keeps both anatomical arm lengths")
	p.combat.set_action("idle")
	p.animate(0,0)
	check(shaft_hits(p).is_empty(),"armed idle carries the shaft outside the actual cape and undercoat")
	var returned_clear := true
	var returned_lengths := true
	var returned_samples := 0
	for aim in [-0.4,0.0,0.4,0.85]:
		p.pitch = aim-0.25
		for frame in 61:
			var time := 0.38+0.42*frame/60
			p.combat.set_action("throw")
			p.throw_recalled = true
			p.combat.elapsed = time
			p.animate(0,0)
			var hits := shaft_hits(p)
			if not hits.is_empty(): print("RETURNED_SHAFT_CROSSINGS: aim=",aim," time=",time," parts=",hits)
			returned_clear = returned_clear and hits.is_empty()
			for side in [-1,1]: returned_lengths = returned_lengths and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
			returned_samples += 1
	print("RETURNED_SHAFT_SAMPLES: ",returned_samples)
	check(returned_clear,"early returned throw carries its shaft outside actual clothing")
	check(returned_lengths,"early return keeps both anatomical arm lengths")
	p.pitch = -0.25
	for action in ["light","pull"]:
		var clear := true
		var arm_lengths := true
		for frame in 61:
			p.combat.set_action(action)
			p.combat.elapsed = float(p.Combat.MOVES[action].duration)*frame/60
			p.animate(0,0)
			clear = clear and shaft_hits(p).is_empty()
			for side in [-1,1]: arm_lengths = arm_lengths and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
		check(clear,"neutral "+action+" keeps rear shaft outside actual upper clothing across 61 poses")
		check(arm_lengths,"neutral "+action+" keeps both anatomical arm lengths")
	var sweep_clear := true
	var sweep_arms := true
	for frame in 181:
		p.combat.set_action("heavy")
		p.combat.elapsed = 0.92*frame/180.0
		p.animate(0,0)
		var sweep_hits := shaft_hits(p)
		if not sweep_hits.is_empty(): print("HEAVY_CLOTH_CROSSING: ",p.combat.elapsed," ",sweep_hits)
		sweep_clear = sweep_clear and sweep_hits.is_empty()
		for side in [-1,1]: sweep_arms = sweep_arms and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
	check(sweep_clear,"181 full-duration neutral heavy poses keep shaft outside actual upper clothing")
	check(sweep_arms,"full-duration neutral heavy keeps anatomical arm lengths")
	p.combat.set_action("idle")
	p.animate(0,0)
	p.combat.set_action("heavy")
	var runtime_clear := true
	var runtime_arms := true
	for frame in 112:
		p.combat.elapsed = minf(0.92,frame/120.0)
		p.animate(1.0/120,0)
		var hits := shaft_hits(p)
		if not hits.is_empty(): print("HEAVY_RUNTIME_CLOTH: ",p.combat.elapsed," ",hits)
		runtime_clear = runtime_clear and hits.is_empty()
		for side in [-1,1]: runtime_arms = runtime_arms and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
	check(runtime_clear,"120Hz idle-to-heavy presentation keeps shaft outside actual upper clothing")
	check(runtime_arms,"120Hz idle-to-heavy presentation keeps anatomical arm lengths")
	for aim in [-0.90,-0.25,0.65]:
		p.pitch = aim
		for continuous in [false,true]:
			p.combat.set_action("idle")
			p.animate(0,0)
			p.combat.set_action("turn")
			var turn_crossings := {}
			var turn_deviation := 0.0
			for frame in 115:
				p.combat.elapsed = minf(0.95,frame/120.0)
				p.animate(1.0/120 if continuous else 0.0,0)
				for label in shaft_hits(p,true):
					if not turn_crossings.has(label):turn_crossings[label]=p.combat.elapsed
				for side in [-1,1]:
					var arm: Dictionary = p.rig.arms[side]
					turn_deviation = maxf(turn_deviation,maxf(absf(arm.upper.scale.y-0.39),absf(arm.lower.scale.y-0.39)))
			check(turn_crossings.is_empty(),"turn shaft clears clothes and head at aim="+str(aim)+" continuous="+str(continuous))
			check(turn_deviation<0.002,"turn preserves anatomical arm lengths at aim="+str(aim)+" continuous="+str(continuous))
	p.pitch = -0.25
	for continuous in [false,true]:
		p.combat.set_action("idle")
		p.animate(0,0)
		p.combat.set_action("spin")
		var spin_clear := true
		var spin_arms := true
		for frame in 163:
			p.combat.elapsed = frame/120.0
			p.animate(1.0/120 if continuous else 0.0,0)
			spin_clear = spin_clear and shaft_hits(p,true).is_empty()
			for side in [-1,1]: spin_arms = spin_arms and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
		check(spin_clear,"full spin shaft clears actual upper clothes and head; continuous="+str(continuous))
		check(spin_arms,"full spin preserves arm lengths; continuous="+str(continuous))
	for chain in [["spin",1.08,"light"],["spin",1.08,"heavy"],["turn",0.60,"light"],["turn",0.60,"heavy"],["turn",0.60,"pull"]]:
		var next: String = chain[2]
		p.combat.set_action(chain[0])
		p.combat.elapsed = chain[1]
		p.animate(0,0)
		p.combat.set_action(next)
		var chain_clear := true
		var chain_arms := true
		for frame in 31:
			p.combat.elapsed = frame/120.0
			p.animate(1.0/120,0)
			chain_clear = chain_clear and shaft_hits(p,true).is_empty()
			for side in [-1,1]: chain_arms = chain_arms and absf(p.rig.arms[side].upper.scale.y-0.39)<0.002 and absf(p.rig.arms[side].lower.scale.y-0.39)<0.002
		check(chain_clear,str(chain[0])+"-to-"+next+" clears actual clothes and head throughout handoff")
		check(chain_arms,str(chain[0])+"-to-"+next+" handoff preserves anatomical arm lengths")
	var saved: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	stage.add_child(saved)
	var preview: AnimationPlayer = saved.get_node("AnimationPreview")
	preview.play("spin")
	var saved_clear := true
	var saved_crossings := {}
	for frame in 163:
		preview.seek(frame/120.0,true)
		for label in shaft_hits_for(saved.get_node("Skeleton3D"),saved.get_node("Trident"),true):
			saved_clear = false
			if not saved_crossings.has(label): saved_crossings[label]=frame/120.0
	check(saved_clear,"saved spin animation also clears clothes and head between its baked keys")
	print("SAVED_SPIN_CROSSINGS: ",saved_crossings)
	preview.play("turn")
	var saved_turn_clear := true
	for frame in 115:
		preview.seek(minf(0.95,frame/120.0),true)
		saved_turn_clear = saved_turn_clear and shaft_hits_for(saved.get_node("Skeleton3D"),saved.get_node("Trident"),true).is_empty()
	check(saved_turn_clear,"saved turn animation clears actual clothes and head between baked keys")
	saved.queue_free()
	print("COUNTER_CLOTH_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
