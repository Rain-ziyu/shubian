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
		if m.data.weak_side=="flank":
			var flank_body: MeshInstance3D = m.mesh.get_node("BodySurface")
			var flank_detector = preload("res://scripts/monster_projectile_contact.gd").new()
			for time in [0.0,0.25,0.5]:
				m.CreatureModel.animate(m.mesh,m.data,0,"recover",time,0)
				m.update_weak_markers()
				for marker in m.weak_markers:
					check(flank_body.get_aabb().grow(0.06).has_point(flank_body.to_local(marker.global_position)),"both flank species mark the visible body instead of empty space")
					var direction: Vector3 = ((marker.global_position-flank_body.global_position)*Vector3(1,0,1)).normalized()
					var hit: Dictionary = flank_detector.cast(m,marker.global_position+direction*0.4,marker.global_position-direction*0.5)
					check(not hit.is_empty() and hit.part=="flank" and hit.point.distance_to(marker.global_position)<0.07,"flank marker sits within seven centimeters of an actual weak surface")
		if m.data.id=="reedclaw":
			m.CreatureModel.animate(m.mesh,m.data,0,"idle",0,0)
			m.update_weak_markers()
			var body: MeshInstance3D = m.mesh.get_node("BodySurface")
			for marker in m.weak_markers:
				check(body.get_aabb().grow(0.06).has_point(body.to_local(marker.global_position)),"reedclaw marker stays close to visible body rather than floating beyond thigh")
			var before: float = m.weak_marker.global_position.y
			var body_before: float = body.global_position.y
			m.CreatureModel.animate(m.mesh,m.data,0,"recover",0.5,0)
			m.update_weak_markers()
			check(m.weak_marker.global_position.y<before-0.05 and absf((m.weak_marker.global_position.y-before)-(body.global_position.y-body_before))<0.002,"surface marker follows the lowered recovery body")
			var detector = preload("res://scripts/monster_projectile_contact.gd").new()
			for marker in m.weak_markers:
				var outward: Vector3 = (marker.global_position-body.global_position)*Vector3(1,0,1)
				outward = outward.normalized()
				var hit: Dictionary = detector.cast(m,marker.global_position+outward*0.4,marker.global_position-outward*0.5)
				check(not hit.is_empty() and hit.part=="flank" and m.weak_part_active(hit.part),"visible recovery flank marker leads to a real open weak surface contact")
		if m.data.id=="mossback":
			var before: Vector3 = m.weak_marker.global_position
			m.mesh.get_node("Tail").rotation.y += 0.8
			m.update_weak_markers()
			check(m.weak_marker.global_position.distance_to(before)>0.2,"tail marker follows articulation")
			var before_bend: Vector3 = m.weak_marker.global_position
			var bones: Skeleton3D = m.mesh.get_node("Tail/TailSkeleton")
			bones.set_bone_pose_rotation(0,Quaternion(Vector3.UP,0.6))
			bones.force_update_all_bone_transforms()
			m.update_weak_markers()
			check(m.weak_marker.global_position.distance_to(before_bend)>0.1,"tail-root indicator follows the skin bones as well as the outer pivot")
			var rendered: MeshInstance3D = bones.get_node("SkinnedTail")
			var arrays: Array = rendered.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vertex := vertices.find(m.tail_marker_anchor)
			check(vertex>=0,"weakpoint anchor is a real rendered rest vertex")
			if vertex>=0:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var actual := Vector3.ZERO
				for slot in 4:
					var bone: int = indices[vertex*4+slot]
					actual += (bones.get_bone_global_pose(bone)*rendered.skin.get_bind_pose(bone)*vertices[vertex])*weights[vertex*4+slot]
				var tail: Node3D = bones.get_parent()
				var expected := tail.to_global(actual)+tail.global_basis.y.normalized()*0.04
				check(m.weak_marker.global_position.distance_to(expected)<0.002,"marker follows actual rendered skin weights with a four-centimeter surface offset")
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
