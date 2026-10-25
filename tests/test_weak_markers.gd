extends SceneTree
const Parts = preload("res://scripts/monster_parts.gd")
var checks := 0
var failures := 0
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
	world.hunter.set_physics_process(false)
	for m in get_nodes_in_group("monsters"):
		m.set_physics_process(false)
		m.set_process(false)
		m.phase = "windup"
		m.exposed = 1
		m.mesh.get_node("Neck").rotation.y = 0.7
		m.mesh.get_node("Tail").rotation.y = -0.8
		m.update_weak_markers()
		var active := 0
		for volume in Parts.volumes(m):
			if not m.weak_part_active(volume.id): continue
			var marker: MeshInstance3D = m.weak_markers[active]
			check(marker.visible and marker.global_position.distance_to(volume.center)<=float(volume.radius),str(m.data.id)+" marker remains inside its actual moving weak volume")
			active += 1
		check(active==m.weak_markers.size(),str(m.data.id)+" all open weak parts marked, including both flanks")
		if m.data.id=="reedclaw":
			var body: MeshInstance3D = m.mesh.get_node("BodySurface")
			for marker in m.weak_markers:
				check(body.get_aabb().grow(0.06).has_point(body.to_local(marker.global_position)),"reedclaw marker stays close to visible body rather than floating beyond thigh")
			var before: float = m.weak_marker.global_position.y
			var body_before: float = body.global_position.y
			m.CreatureModel.animate(m.mesh,m.data,0,"recover",0.5,0)
			m.update_weak_markers()
			check(m.weak_marker.global_position.y<before-0.05 and absf((m.weak_marker.global_position.y-before)-(body.global_position.y-body_before))<0.002,"surface marker follows the lowered recovery body")
		if m.data.id=="mossback":
			var before: Vector3 = m.weak_marker.global_position
			m.mesh.get_node("Tail").rotation.y += 0.8
			m.update_weak_markers()
			check(m.weak_marker.global_position.distance_to(before)>0.2,"tail marker follows articulation")
		m.phase = "idle"
		m.exposed = 0
		m.stagger = 0
		m.update_weak_markers()
		for marker in m.weak_markers:
			check(marker.visible==(m.data.id=="mossback"),str(m.data.id)+" closed weak windows hide indicators")
		m.health = 0
		m.update_weak_markers()
		for marker in m.weak_markers: check(not marker.visible,"defeated monster has no active indicator")
	print("WEAK_MARKER_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
