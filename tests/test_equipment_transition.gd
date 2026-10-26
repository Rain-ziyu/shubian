extends SceneTree
var checks := 0
var failures := 0
var hits := 0
var hit_time := 0.0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.combat.set_action("idle")
	p.combat.drawn = true
	p.animate(0,0)
	# Inspect the actual clip mesh against the shaft axis through moving carry poses.
	p.combat.drawn = false
	for phase in [0.0,0.8,1.6,2.4]:
		p.walk_clock = phase
		p.animate(0,4.5)
		var clips: MeshInstance3D = p.rig.torso.get_node("BackMountClips")
		var aligned := true
		for vertex: Vector3 in clips.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var local: Vector3 = p.rig.weapon.to_local(clips.to_global(vertex))
			var radius := Vector2(local.x,local.z).length()
			aligned = aligned and radius>=0.0329 and radius<=0.0451
		check(aligned,"actual carry clips retain shaft clearance during gait "+str(phase))
	var clips: MeshInstance3D = p.rig.torso.get_node("BackMountClips")
	var clip_points: PackedVector3Array = clips.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges := {}
	for triangle in range(0,clip_points.size(),3):
		for edge in 3:
			var a := str(Vector3i((clip_points[triangle+edge]*1000000).round()))
			var b := str(Vector3i((clip_points[triangle+(edge+1)%3]*1000000).round()))
			var key := a+"|"+b if a<b else b+"|"+a
			edges[key] = int(edges.get(key,0))+1
	var closed := true
	for count in edges.values(): closed = closed and count==2
	check(closed,"both side-open clips have closed metal thickness, including cut ends")
	var opening_clear := true
	for vertex in clip_points:
		var local: Vector3 = p.rig.weapon.to_local(clips.to_global(vertex))
		opening_clear = opening_clear and local.x<0.016
	check(opening_clear,"clip mouths remain open toward the positive-X equipment route")
	p.walk_clock = 0
	p.combat.drawn = true
	p.animate(0,0)
	var armed: Vector3 = p.rig.weapon.position
	check(p.combat.request("sheathe"),"idle accepts sheath request")
	p.animate(1.0/60,0)
	check(p.rig.weapon.position.distance_to(armed)<0.05 and p.pose_blend<1,"sheath begins smoothly despite unchanged idle action")
	var lengths := true
	var side_route := false
	var main_holds := false
	for frame in 30:
		p.animate(1.0/60,0)
		if p.rig.weapon.position.x>0.25 and p.rig.weapon.position.y>1.4: side_route = true
		if frame==8: main_holds = p.rig.arms[1].hand.position.distance_to(p.rig.weapon.transform*Vector3(0,-0.28,0))<0.002
		for side in [-1,1]:
			var arm: Dictionary = p.rig.arms[side]
			lengths = lengths and absf(arm.upper.scale.y-0.39)<0.002 and absf(arm.lower.scale.y-0.39)<0.002
	check(lengths,"release transition retains both arm segment lengths")
	check(side_route,"equipment path lifts beside torso instead of only straight interpolation")
	check(main_holds,"main hand holds shaft through middle of sheath transfer")
	check(p.rig.weapon.position.distance_to(Vector3(0,1.05,0.26))<0.001 and is_zero_approx(p.equipment_grip),"sheath settles at back mount and releases hands")
	var before: Vector3 = p.rig.weapon.position
	var hand: Vector3 = p.rig.arms[-1].hand.position
	check(p.combat.request("light") and p.combat.drawn,"attack draws immediately without adding a gameplay wait")
	p.animate(1.0/60,0)
	check(p.rig.weapon.position.distance_to(before)<0.2,"draw starts from back mount continuously")
	check(p.rig.arms[-1].hand.position.distance_to(hand)<0.15,"drawing hand begins continuous reach")
	p.combat.strike.connect(func(_beat: int):
		hits += 1
		hit_time = p.combat.elapsed
	)
	for frame in 16:
		p.combat.advance(1.0/60)
		p.animate(1.0/60,0)
		for side in [-1,1]:
			var arm: Dictionary = p.rig.arms[side]
			lengths = lengths and absf(arm.upper.scale.y-0.39)<0.002 and absf(arm.lower.scale.y-0.39)<0.002
	check(lengths,"draw arc also retains fixed arm lengths")
	check(hits==1 and hit_time>=0.25 and hit_time<=0.25+1.0/60+0.001,"visual draw preserves first strike threshold within one physics tick")
	check(is_equal_approx(p.equipment_grip,1),"hands settle on grips before first strike")
	p.combat.set_action("idle")
	p.combat.drawn = true
	p.animate(0,0)
	p.combat.request("sheathe")
	for frame in 4: p.animate(1.0/60,0)
	before = p.rig.weapon.position
	check(p.combat.request("heavy"),"fresh attack can interrupt visual sheath")
	p.animate(1.0/60,0)
	check(p.rig.weapon.position.distance_to(before)<0.2,"redraw resumes from current weapon pose")
	check(p.combat.health==240 and p.combat.shadow_lifetimes.is_empty(),"visual equipment transition does not change health or shadows")
	p.combat.set_action("throw")
	for sample in [[0.28,0.0],[0.33,0.5],[0.38,1.0]]:
		p.combat.elapsed = sample[0]
		p.animate(0,0)
		check(absf(p.rig.arms[-1].hand.get_blend_shape_value(0)-sample[1])<0.001,"throw progressively opens fingers before projectile release")
	print("EQUIPMENT_TRANSITION_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
