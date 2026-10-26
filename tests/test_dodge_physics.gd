extends SceneTree
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func release_movement() -> void:
	for action in ["move_forward","move_back","move_left","move_right"]: Input.action_release(action)
func start_dodge(p: CharacterBody3D) -> void:
	p.combat.set_action("idle")
	p.combat.stamina = 100
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(0,0.02,0)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	p._unhandled_input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_mesh := Player.Visuals.piece(stage,Vector3(0,-0.2,0),Vector3(40,0.4,40),Color.GRAY)
	floor_mesh.create_trimesh_collision()
	var p := Player.new()
	stage.add_child(p)
	# Only explicit logical events below drive this deterministic fixture.
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.set_physics_process(false)
	await physics_frame
	await physics_frame
	var trials := [
		{"keys":["move_forward"],"yaw":0.0,"expected":Vector3.FORWARD},
		{"keys":["move_back"],"yaw":0.0,"expected":Vector3.BACK},
		{"keys":["move_left"],"yaw":0.0,"expected":Vector3.LEFT},
		{"keys":["move_right"],"yaw":0.0,"expected":Vector3.RIGHT},
		{"keys":["move_forward","move_right"],"yaw":0.0,"expected":Vector3(1,0,-1).normalized()},
		{"keys":["move_forward"],"yaw":PI/2,"expected":Vector3.LEFT},
		{"keys":[],"yaw":0.0,"expected":Vector3.BACK}
	]
	for trial in trials:
		release_movement()
		for action in trial.keys: Input.action_press(action)
		p.yaw = trial.yaw
		p.rig.root.rotation.y = PI if trial.keys.is_empty() else 0.0
		start_dodge(p)
		check(p.combat.action=="dodge" and is_equal_approx(p.combat.stamina,72),"Space starts dodge and spends normal stamina")
		for tick in 20:
			p._physics_process(1.0/60)
			await physics_frame
		var travel := Vector3(p.position.x,0,p.position.z)
		check(travel.normalized().dot(trial.expected)>0.999,"physical dodge follows camera-relative input or facing fallback")
		check(absf(travel.length()-3.0)<0.03,"cardinal and diagonal dodges have equal displacement")
	release_movement()
	var wall := Player.Visuals.piece(stage,Vector3(1.2,1,0),Vector3(0.2,2,12),Color.GRAY)
	wall.create_trimesh_collision()
	await physics_frame
	await physics_frame
	Input.action_press("move_right")
	p.yaw = 0
	start_dodge(p)
	for tick in 20:
		p._physics_process(1.0/60)
		await physics_frame
	check(p.position.x<0.80 and p.position.x>0.5,"actual dodge capsule stops before wall without crossing it")
	release_movement()
	for sample in [[0.05,false],[0.06,true],[0.32,true],[0.33,false]]:
		p.combat.health = 240
		p.combat.set_action("dodge")
		p.combat.elapsed = sample[0]
		p.take_damage(10,p.global_position+Vector3.FORWARD,false)
		check((p.combat.health==240)==sample[1],"real damage entry respects dodge immunity boundary at "+str(sample[0]))
	p.combat.set_action("dodge")
	p.combat.elapsed = 0.54
	p._physics_process(0.02)
	check(p.combat.action=="idle","dodge ends at its authored duration")
	print("DODGE_PHYSICS_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
