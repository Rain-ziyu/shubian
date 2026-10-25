extends SceneTree
const Warning = preload("res://scripts/head_sweep_warning.gd")
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
	world.hunter.set_physics_process(false)
	world.hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for foe in get_nodes_in_group("monsters"): foe.set_physics_process(false)
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	var actor = get_nodes_in_group("monsters")[0]
	var hull: PackedVector2Array = actor.head_warning_hull
	for pose in [Vector3(0,0,0),Vector3(-18,0,0.7),Vector3(41,0,-0.6)]:
		actor.position = Vector3(pose.x,0.05,pose.y)
		actor.rotation.y = pose.z
		var baseline: Array = reference_build(actor,hull).surface_get_arrays(0)
		var current: Array = Warning.build(actor,hull).surface_get_arrays(0)
		var vertices: PackedVector3Array = current[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = current[Mesh.ARRAY_INDEX]
		var expected: PackedVector3Array = baseline[Mesh.ARRAY_VERTEX]
		var equal := indices.size()==expected.size()
		for index in mini(indices.size(),expected.size()):
			equal = equal and vertices[indices[index]].distance_to(expected[index])<0.00001
		check(equal,"indexed warning preserves every projected triangle on flat slope and water")
		check(vertices.size()<expected.size()/4,"shared warning vertices reduce repeated terrain samples")
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	for sample in 9:
		var start := Time.get_ticks_usec()
		var baseline := reference_build(actor,hull)
		old_times.append(Time.get_ticks_usec()-start)
		start = Time.get_ticks_usec()
		var current := Warning.build(actor,hull)
		new_times.append(Time.get_ticks_usec()-start)
		check(baseline!=null and current!=null,"both comparison meshes are valid")
	old_times.sort()
	new_times.sort()
	print("WARNING_BUILD_CPU_US: reference_median=",old_times[4]," indexed_median=",new_times[4],"; function timings, not frame rate")
	print("HEAD_WARNING_GEOMETRY_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)

static func reference_build(actor: Node3D, hull: PackedVector2Array) -> ArrayMesh:
	var boundary := PackedVector2Array()
	for i in range(hull.size()-1):
		var steps := maxi(1,ceili(hull[i].distance_to(hull[i+1])/0.35))
		for step in steps: boundary.append(hull[i].lerp(hull[i+1],float(step)/steps))
	var center := Vector2.ZERO
	for point in boundary: center += point
	center /= boundary.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 10:
		for i in boundary.size():
			var next := (i+1)%boundary.size()
			var a := center.lerp(boundary[i],float(ring)/10)
			var b := center.lerp(boundary[i],float(ring+1)/10)
			var c := center.lerp(boundary[next],float(ring)/10)
			var d := center.lerp(boundary[next],float(ring+1)/10)
			for point in ([a,b,d] if ring==0 else [a,b,c,b,d,c]):
				var world: Vector3 = actor.to_global(Vector3(point.x,0,point.y))
				world.y = Terrain.effect_height_at(world.x,world.z)+0.08
				st.add_vertex(world)
	st.generate_normals()
	return st.commit()
