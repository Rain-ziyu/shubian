extends SceneTree
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func step(p: CharacterBody3D, frames: int) -> void:
	for frame in frames:
		p._physics_process(1.0/60)
		await physics_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_mesh := Player.Visuals.piece(stage,Vector3(0,-0.2,0),Vector3(30,0.4,30),Color.GRAY)
	floor_mesh.create_trimesh_collision()
	var wall := Player.Visuals.piece(stage,Vector3(0,1,-2),Vector3(20,2,0.2),Color.GRAY)
	wall.create_trimesh_collision()
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	# This is a controlled fixture, not a window-input test.
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.yaw = 0
	p.pitch = -0.25
	p.rig.root.rotation.y = 0
	p.position = Vector3(0,0.02,0)
	p.yaw = 0
	await physics_frame
	await physics_frame
	Input.action_press("move_forward")
	var start: Vector3 = p.position
	var phase: float = p.walk_clock
	await step(p,12)
	var free_distance := Vector2(p.position.x-start.x,p.position.z-start.z).length()
	var free_phase: float = p.walk_clock-phase
	check(free_distance>0.8,"forward input produces normal unobstructed travel")
	check(free_phase>0,"travel advances the walking cycle")
	await step(p,30)
	start = p.position
	phase = p.walk_clock
	await step(p,30)
	check(p.position.distance_to(start)<0.01,"real wall stops the capsule")
	check(absf(p.walk_clock-phase)<0.01,"fully blocked movement does not continue the walking cycle")
	check(p.position.z> -1.6,"capsule remains on the near side of the wall")
	Input.action_press("move_right")
	start = p.position
	phase = p.walk_clock
	await step(p,12)
	var slide_distance := Vector2(p.position.x-start.x,p.position.z-start.z).length()
	check(p.position.x-start.x>0.5 and absf(p.position.z-start.z)<0.01,"diagonal input slides along the real wall")
	check(absf((p.walk_clock-phase)/slide_distance-free_phase/free_distance)<0.03,"wall sliding keeps the same gait per actual meter as free movement")
	var feet_before_release := {}
	for side in [-1,1]: feet_before_release[side] = p.rig.legs[side].ankle.global_position
	Input.action_release("move_forward")
	Input.action_release("move_right")
	start = p.position
	phase = p.walk_clock
	await step(p,1)
	for side in [-1,1]: check(feet_before_release[side].distance_to(p.rig.legs[side].ankle.global_position)<0.04,"real movement release carries rendered ankle continuously")
	await step(p,11)
	check(p.position.distance_to(start)<0.01 and is_equal_approx(p.walk_clock,phase),"release stops movement and cycle advancement")
	check(p.combat.health==240 and p.combat.stamina==100,"locomotion measurements do not consume combat resources")
	print("LOCOMOTION_PHYSICS_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
