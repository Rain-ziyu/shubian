extends "res://tools/replay_physical_leap.gd"
## Fixed initial placement and stationary hunter; normal AI and real damage, no health injection.
var hit_captured := false
var health_before := 240.0
func setup() -> void:
	await super.setup()
	hunter.global_position = creature.global_position+Vector3(0,0,-3.7)
	health_before = hunter.combat.health
	title.text = "戍边 / 扑跃实际接触检查\n正常 AI · 角色固定站位 · 非真人难度验证"
func control() -> void:
	frames += 1
	peak = maxf(peak,creature.global_position.y)
	launched = launched or creature.airborne_leap
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	camera.position = Vector3(creature.global_position.x+7,4.5,creature.global_position.z-7)
	camera.look_at(Vector3(creature.global_position.x,1.3,creature.global_position.z-0.5))
	if hunter.combat.health<health_before and not hit_captured:
		hit_captured = true
		print("LUNGE_VISIBLE_CONTACT: clock=",creature.clock," part=",creature.lunge_contact.last_part," health=",hunter.combat.health)
		capture_hit.call_deferred()
	if (launched and creature.is_on_floor() and creature.phase=="recover" and creature.clock>0.7) or frames>=240:
		physics_frame.disconnect(control)
		finish.call_deferred()
func capture_hit() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-lunge-visible-contact.png"))
func finish() -> void:
	var passed: bool = launched and creature.is_on_floor() and hit_captured and is_equal_approx(hunter.combat.health,health_before-float(creature.data.damage))
	print("LUNGE_CONTACT_STUDY: ",JSON.stringify({"passed":passed,"peak":peak,"health":hunter.combat.health,"part":creature.lunge_contact.last_part,"scope":"normal AI against stationary hunter at controlled start; no damage or health injection; not difficulty acceptance"}))
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if passed else 1)
