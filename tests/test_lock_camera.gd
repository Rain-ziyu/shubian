extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func error_to(p: CharacterBody3D, m: Node3D) -> float:
	var offset := m.global_position-p.global_position
	return absf(wrapf(p.yaw-atan2(-offset.x,-offset.z),-PI,PI))
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	world.hunter.set_process_input(false)
	world.hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var m = get_nodes_in_group("monsters")[0]
	m.global_position = p.global_position+Vector3(6,0,-6)
	p.lock_target = m
	p.yaw = 0
	p.camera_manual_time = 0
	p.update_lock_camera(1.0/60)
	check(p.yaw<0 and p.yaw> -PI/4,"lock begins a smooth turn rather than snapping")
	for frame in 120: p.update_lock_camera(1.0/60)
	check(error_to(p,m)<0.001,"camera converges on locked target")
	p.apply_look(Vector2(100,0))
	var manual: float = p.yaw
	p.update_lock_camera(0.25)
	check(is_equal_approx(p.yaw,manual),"horizontal mouse temporarily owns camera yaw")
	p.update_lock_camera(0.6)
	check(not is_equal_approx(p.yaw,manual) and error_to(p,m)<0.1,"automatic follow resumes after manual grace period")
	p.camera_manual_time = 0
	p.apply_look(Vector2(0,-10000))
	var pitch: float = p.pitch
	p.update_lock_camera(0.1)
	check(p.camera_manual_time==0 and p.pitch==pitch and is_equal_approx(pitch,0.65),"vertical weakpoint aiming remains independent of camera follow")
	p.yaw = 0
	for frame in 30: p.update_lock_camera(1.0/30)
	var slow: float = p.yaw
	p.yaw = 0
	for frame in 120: p.update_lock_camera(1.0/120)
	check(absf(wrapf(p.yaw-slow,-PI,PI))<0.0001,"follow smoothing is consistent across frame rates")
	p.lock_target = null
	var before: float = p.yaw
	p.update_lock_camera(1)
	check(is_equal_approx(p.yaw,before),"unlocked camera remains free")
	p.lock_target = m
	p.combat.health = 0
	p.update_lock_camera(1)
	check(is_equal_approx(p.yaw,before),"hunter defeat does not force camera rotation")
	p.combat.health = 240
	m.global_position = p.global_position+Vector3(40,0,0)
	p.update_lock_camera(1)
	check(is_equal_approx(p.yaw,before),"out-of-range target does not steer view")
	m.global_position = p.global_position
	p.update_lock_camera(1)
	check(is_equal_approx(p.yaw,before),"overlapping horizontal positions keep stable yaw")
	m.global_position = p.global_position+Vector3(0.2,0,6)
	p.yaw = PI-0.05
	before = p.yaw
	p.update_lock_camera(1.0/60)
	var step := wrapf(p.yaw-before,-PI,PI)
	check(step>0 and step<0.03,"camera crosses angle seam by shortest turn")
	p.yaw = 0
	p.camera_manual_time = 0
	var maximum := 0.0
	for frame in 180:
		var angle := float(frame)/60
		m.global_position = p.global_position+Vector3(sin(angle)*6,0,-cos(angle)*6)
		p.update_lock_camera(1.0/60)
		maximum = maxf(maximum,error_to(p,m))
	check(maximum<0.21,"normal lateral target travel stays near center of view")
	var hp: float = p.combat.health
	var stamina: float = p.combat.stamina
	var elapsed: float = p.combat.elapsed
	p.update_lock_camera(0.1)
	check(p.combat.health==hp and p.combat.stamina==stamina and p.combat.elapsed==elapsed,"camera tracking does not advance combat clocks or resources")
	p._physics_process(1.0/60)
	check(is_equal_approx(p.mount.rotation.y,p.yaw),"live camera mount uses updated follow yaw")
	print("LOCK_CAMERA_CHECKS: ",checks," FAILURES: ",failures," MOVING_ERROR=",maximum)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
