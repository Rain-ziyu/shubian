extends SceneTree
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
	var p = world.hunter
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	for monster in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	p.global_position = Vector3(0,0.05,8)
	p.mount.global_position = p.global_position+Vector3.UP*1.5
	p.mount.rotation = Vector3(-0.25,0,0)
	var arm: SpringArm3D = p.camera.get_parent()
	for frame in 8: await physics_frame
	check(p.camera.global_basis.is_equal_approx(p.mount.global_basis),"shoulder view retains the original look heading and pitch")
	check(p.mount.to_local(p.camera.global_position).x>0.8,"camera separates the weapon from a directly centered rear silhouette")
	check(arm.get_hit_length()>p.CAMERA_DISTANCE-0.1,"open camera retains its intended follow distance")
	var wall = world.obstacle(Vector3(0,2.5,10.4),Vector3(6,5,0.3),Color.GRAY)
	for frame in 8: await physics_frame
	check(arm.get_hit_length()<2.5 and p.camera.global_position.z<10.25,"rear wall retracts the shoulder camera before the visible wall")
	wall.queue_free()
	for frame in 8: await physics_frame
	check(arm.get_hit_length()>p.CAMERA_DISTANCE-0.1,"camera extends again when the rear obstruction is removed")
	wall = world.obstacle(Vector3(0.55,2.5,10),Vector3(0.25,5,7),Color.GRAY)
	for frame in 8: await physics_frame
	check(arm.get_hit_length()<4.0 and p.camera.global_position.x<0.425,"side wall also retracts the offset camera from the central cast origin")
	check(p.camera.global_basis.is_equal_approx(p.mount.global_basis),"wall retraction preserves view orientation")
	print("SHOULDER_CAMERA_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
