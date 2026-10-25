extends "res://tests/replay_encounter.gd"
## One normal light attack against live mossback AI; controlled rear placement, no resource injection.
var pressed := false
var root_hits := 0
var root_damage := 0.0
func _init() -> void: controller_name = "moss_root_contact"
func setup() -> void:
	await super.setup()
	fighter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.global_position = monster.global_position+Vector3(0,0,3.5)
	fighter.velocity = Vector3.ZERO
	fighter.hit_confirmed.connect(func(_action: String, _beat: int, target: Node3D, result: Dictionary):
		if target==monster and result.part=="tail" and result.weak:
			root_hits += 1
			root_damage += float(result.damage)
	)
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var title := Label.new()
	title.position = Vector2(24,245)
	title.text = "戍边 / 尾根接触定位\n正常 AI · 单次斜刺 · 非通关演示"
	title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(title)
func control() -> void:
	if result_saved: return
	elapsed += 1.0/60
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	if elapsed>=0.20 and not pressed:
		pressed = true
		fighter.request_action("light")
	if elapsed>=1.8 or fighter.combat.health<=0:
		result_saved = true
		finish_contact.call_deferred()
func finish_contact() -> void:
	var passed: bool = root_hits>0 and fighter.combat.health>0
	print("MOSS_ROOT_CONTACT: ",JSON.stringify({"passed":passed,"root_hits":root_hits,"root_damage":root_damage,"health":fighter.combat.health,"scope":"normal AI and action request at controlled rear starting position; no injected damage or resources; one contact, not victory or human difficulty acceptance"}))
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if passed else 1)
