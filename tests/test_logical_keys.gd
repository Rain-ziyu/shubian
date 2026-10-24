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
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.pressed = true
	p._unhandled_input(event)
	check(p.combat.action=="guard","logical-only Q starts guard")
	event.keycode = KEY_F1
	world.combat_hud._unhandled_key_input(event)
	check(world.combat_hud.help.visible,"logical-only F1 opens help")
	p.combat.set_action("idle")
	event.keycode = KEY_R
	event.physical_keycode = KEY_Q
	p._unhandled_input(event)
	check(p.combat.action=="guard","physical key takes priority when codes differ")
	event.physical_keycode = 0
	for code in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SHIFT]:
		event.keycode = code
		event.pressed = true
		p._input(event)
		check(p.virtual_keys.pressed_actions.size()==1,"logical movement activates mapped action")
		event.pressed = false
		p._input(event)
		check(p.virtual_keys.pressed_actions.is_empty(),"logical key release clears mapped action")
	event.keycode = KEY_W
	event.pressed = true
	p._input(event)
	p._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not Input.is_action_pressed("move_forward") and p.virtual_keys.pressed_actions.is_empty(),"focus loss releases logical movement")
	event.physical_keycode = KEY_W
	p._input(event)
	check(p.virtual_keys.pressed_actions.is_empty(),"physical movement remains handled by original InputMap")
	event.physical_keycode = 0
	event.keycode = KEY_CTRL
	p.combat.set_action("wait")
	p._unhandled_input(event)
	check(p.combat.action=="counter_window","logical Ctrl opens planted counter window")
	event.keycode = KEY_W
	p._input(event)
	p._exit_tree()
	check(not Input.is_action_pressed("move_forward"),"scene teardown releases virtual movement")
	event.physical_keycode = KEY_PAUSE
	event.keycode = KEY_Q
	event.pressed = true
	p.combat.set_action("idle")
	p._unhandled_input(event)
	check(p.combat.action=="guard","observed injected Q with unmapped Pause physical code starts guard")
	world.combat_hud.help.hide()
	event.keycode = KEY_F1
	world.combat_hud._unhandled_key_input(event)
	check(world.combat_hud.help.visible,"observed injected F1 with Pause physical code opens help")
	event.keycode = KEY_W
	p._input(event)
	check(Input.is_action_pressed("move_forward"),"unmapped special physical code falls back to mapped logical movement")
	event.pressed = false
	p._input(event)
	check(not Input.is_action_pressed("move_forward"),"fallback release clears mapped movement")
	event.physical_keycode = KEY_Z
	event.keycode = KEY_W
	p._input(event)
	check(not Input.is_action_pressed("move_forward") and p.InputKeys.code(event)==KEY_Z,"printable physical layout differences retain their original meaning")
	print("LOGICAL_KEY_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
