extends "res://tools/replay_animation_study.gd"
## Frozen targets, arena reset between examples, fixture flash window for the
## final example. Movement uses the real player physics, not pose teleporting.
const CASES := ["前向闪身","左向闪身","右向闪身","后向闪身","前向闪刺"]
const KEYS := ["move_forward","move_left","move_right","move_back",""]
var case_index := 0
var case_clock := 0.0
var launched := false
var observed := 0
var study_camera: Camera3D
func setup() -> void:
	await super.setup()
	study_camera = root.get_camera_3d()
	fighter.set_process_unhandled_input(false)
	reset_example()
func release_movement() -> void:
	for key in KEYS:
		if not key.is_empty(): Input.action_release(key)
func reset_example() -> void:
	release_movement()
	fighter.clear_body_turn()
	fighter.global_position = Vector3.ZERO
	fighter.velocity = Vector3.ZERO
	fighter.yaw = 0
	fighter.rig.root.rotation = Vector3.ZERO
	fighter.combat.set_action("idle")
	fighter.combat.drawn = true
	fighter.animate(0,0)
	launched = false
	case_clock = 0
func step() -> void:
	if finished: return
	case_clock += 1.0/60
	if case_clock>=0.3 and not launched:
		launched = true
		var move := "dodge"
		if case_index==4:
			move = "flash"
			fighter.combat.flash_window = 0.8
		else: Input.action_press(KEYS[case_index])
		if fighter.combat.request(move): observed += 1
	if case_clock>0.86: release_movement()
	fighter._physics_process(1.0/60)
	title.text = "戍边 / 位移动作研究（预设场景，非实战）\n"+CASES[case_index]+" / 蹬地 · 跨步 · 落脚"
	study_camera.position = fighter.global_position+Vector3(3,2,-4)
	study_camera.look_at(fighter.global_position+Vector3(0,0.95,0))
	if case_clock>=1.25:
		case_index += 1
		if case_index>=CASES.size():
			finished = true
			finish.call_deferred()
		else: reset_example()
func finish() -> void:
	release_movement()
	print("EVASION_STUDY: accepted=",observed," cases=",CASES.size()," health=",fighter.combat.health)
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if observed==CASES.size() else 1)
