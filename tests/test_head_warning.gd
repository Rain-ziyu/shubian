extends SceneTree
const Terrain = preload("res://scripts/forest_terrain.gd")
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
	for foe in get_nodes_in_group("monsters"): foe.set_physics_process(false)
	var m = get_nodes_in_group("monsters")[0]
	m.global_position = Vector3(0,0.01,-16)
	m.rotation.y = 0.7
	world.hunter.global_position = m.to_global(Vector3(0,0,-3.2))
	m.phase = "windup"
	m.clock = m.data.windup*0.8
	m.rear_attack = false
	m._physics_process(0)
	var hull: PackedVector2Array = m.head_warning_hull
	check(hull.size()>4 and Geometry2D.is_point_in_polygon(Vector2(0,-3.2),hull),"front contact region lies in directional warning")
	check(not Geometry2D.is_point_in_polygon(Vector2(0,3),hull),"rear ground is not included in a front head sweep")
	check(m.tell.mesh is ArrayMesh and m.tell.global_basis.is_equal_approx(Basis.IDENTITY),"real windup creates a world-aligned fitted warning")
	var error := 0.0
	for vertex in m.tell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point: Vector3 = m.tell.to_global(vertex)
		error = maxf(error,absf(point.y-Terrain.effect_height_at(point.x,point.z)-0.08))
	check(error<0.001,"warning interior follows terrain rather than a flat sphere")
	print("HEAD_WARNING_HEIGHT_DELTA: ",error)
	var covered := true
	for sample in 81:
		var time := lerpf(0.08,0.45,float(sample)/80)
		m.CreatureModel.animate(m.mesh,m.data,0,"active",time,0)
		for rings in m.head_rings:
			for ring in rings:
				var center: Vector3 = m.to_local(m.mesh.get_node("Neck").to_global(Vector3(ring.w,ring.y,ring.x)))
				for edge in 12:
					var angle := TAU*edge/12
					var point: Vector2 = Vector2(center.x,center.z)+Vector2(cos(angle),sin(angle))*(ring.z+0.36)
					covered = covered and Geometry2D.is_point_in_polygon(point,hull)
	check(covered,"denser actual animated head and jaw samples remain within conservative warning")
	if DisplayServer.get_name()!="headless":
		world.hunter.hide()
		world.hud.get_parent().hide()
		m.CreatureModel.animate(m.mesh,m.data,0,"windup",m.data.windup*0.8,0)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(-9,8,-26)
		camera.look_at(m.global_position+Vector3(0,0.4,-1.8))
		camera.current = true
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-head-warning.png"))
	print("HEAD_WARNING_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
