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
		var old: float = m.health
		m.phase = "windup"
		m.exposed = 2
		var expected := "tail" if m.data.weak_side=="rear" else ("flank" if m.data.weak_side=="flank" else "head")
		if m.data.id=="stormcrest": expected = "spine"
		var origin: Vector3 = m.global_position-m.global_basis.z*4
		var normal: Dictionary = m.receive_strike(10,origin,"light","body")
		var weak: Dictionary = m.receive_strike(10,origin,"light",expected)
		check(not normal.weak and weak.weak and weak.damage>normal.damage,"actual part overrides attacker direction: "+str(m.data.id))
		var volumes := Parts.volumes(m)
		var point: Vector3 = volumes[0].center
		check(Parts.at_point(m,point)==volumes[0].id,"point contact identifies model part")
		var before: Vector3 = volumes[0].center
		m.mesh.position.x += 1.5
		check(is_equal_approx(Parts.volumes(m)[0].center.x-before.x,1.5),"hit volume follows model transform")
		m.mesh.position.x -= 1.5
		var miss: Dictionary = Parts.cast(m,m.global_position+Vector3(50,20,50),Vector3.UP,3)
		check(miss.is_empty(),"cast cannot hit distant creature")
		m.health = old
		if m.data.id=="mossback":
			var crown: MeshInstance3D = m.mesh.get_node("Neck/HeadSurface")
			var exposed_mesh: Mesh = crown.get_meta("unarmored_mesh")
			check(crown.mesh!=exposed_mesh and crown.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==exposed_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"crown protection has distinct appearance without adding hit volume")
			m.receive_strike(250,origin,"heavy","body")
			check(m.armor_integrity==0 and not m.mesh.get_node("ArmorPlate0").visible,"armor break removes plate visuals")
			check(crown.mesh==exposed_mesh,"actual armor break exposes the skull surface")
			var after: Dictionary = m.receive_strike(10,origin,"light","body")
			check(after.damage>normal.damage,"broken armor loses frontal reduction")
		if m.data.id=="stormcrest":
			m.phase = "windup"
			m.disrupted = 0
			m.receive_strike(100,origin,"light","tail")
			check(m.disrupted==0,"tail is not charged spine")
			m.receive_strike(100,origin,"light","spine")
			check(m.stagger>0,"charged spine hit interrupts")
			m.phase = "recover"
			check(m.receive_strike(10,origin,"light","spine").weak,"staggered spine keeps promised weakness bonus")
			m.stagger = 0
			check(not m.receive_strike(10,origin,"light","spine").weak,"ordinary recovery does not automatically expose spine")
	print("PART_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
