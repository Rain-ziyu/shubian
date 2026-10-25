extends "res://tools/replay_animation_study.gd"
## Hidden, non-colliding enemies; real held-button handling, projectile and arrival checks.
var study_clock := 0.0
var pressed := false
var released := false
var throw_seen := false
var landing_seen := false
var origin := Vector3.ZERO
var study_camera: Camera3D
func setup() -> void:
	await super.setup()
	for creature in get_nodes_in_group("monsters"): creature.collision_layer = 0
	fighter.set_process_unhandled_input(false)
	fighter.global_position = Vector3(0,0.05,-10)
	fighter.velocity = Vector3.ZERO
	fighter.yaw = 0
	fighter.rig.root.rotation = Vector3.ZERO
	fighter.combat.set_action("idle")
	fighter.combat.drawn = true
	fighter.animate(0,0)
	origin = fighter.global_position
	study_camera = root.get_camera_3d()
func button(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	fighter._unhandled_input(event)
func step() -> void:
	if finished: return
	study_clock += 1.0/60
	if study_clock>=0.30 and not pressed:
		pressed = true
		button(true)
	if study_clock>=0.88 and not released:
		released = true
		button(false)
	fighter._physics_process(1.0/60)
	throw_seen = throw_seen or fighter.combat.action=="throw"
	if fighter.arrival_pose_weight()>0.8 and not landing_seen:
		landing_seen = true
		capture_arrival.call_deferred()
	study_camera.position = fighter.global_position+Vector3(3.8,2.1,-3)
	study_camera.look_at(fighter.global_position+Vector3(0,0.95,0))
	title.text = "戍边 / 投枪与落点姿态研究（预设空场，非实战）\n右键长按 · 投出 · 瞬移 · 屈膝稳住 / 位移 %.1f m" % fighter.global_position.distance_to(origin)
	if study_clock>=2.9:
		finished = true
		finish.call_deferred()
func capture_arrival() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-throw-arrival-pose.png"))
func finish() -> void:
	var moved: float = fighter.global_position.distance_to(origin)
	# The real forest may stop the projectile before maximum range. Require a
	# genuine arrival (the gameplay threshold), not an unobstructed flight lane.
	var passed: bool = throw_seen and landing_seen and moved>0.5 and fighter.projectile==null
	print("THROW_STUDY: throw=",throw_seen," landing=",landing_seen," moved=",moved," passed=",passed)
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if passed else 1)
