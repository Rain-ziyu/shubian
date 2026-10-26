extends SceneTree
## Isolated trace serialization/input routing fixture; not physical Windows input.
const Diagnostics = preload("res://scripts/input_diagnostics.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func click_ctrl() -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.ctrl_pressed = true
		Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap_ctrl() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_CTRL
	key.physical_keycode = KEY_CTRL
	key.pressed = true
	key.ctrl_pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	key.ctrl_pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	check(world.get_node_or_null("InputDiagnostics")==null,"normal startup does not create an input recorder")
	var p = world.hunter
	p.set_physics_process(false)
	for monster in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	var trace = Diagnostics.attach(world,p,"res://../verification/input-diagnostic-fixtures")
	var path: String = trace.log_path
	check(not path.is_empty() and FileAccess.file_exists(path),"opt-in trace creates a unique local file")
	p.feedback.show_event("受击提示",Color.WHITE,5,3)
	click_ctrl()
	check(p.combat.action=="idle" and p.combat.shadow_lifetimes.is_empty(),"observing a rejected input does not grant a move or shadow")
	p.combat.set_action("light")
	p.combat.advance(0.20)
	click_ctrl()
	p.combat.advance(0.18)
	p.combat.set_action("guard")
	p.combat.advance(0.15)
	tap_ctrl()
	check(p.combat.action=="guard" and p.combat.shadow_lifetimes.is_empty(),"Ctrl before a successful block cannot start or reward a sweep")
	p.combat.receive_damage(10)
	tap_ctrl()
	check(p.combat.action=="reply" and p.combat.shadow_lifetimes.is_empty(),"Ctrl starts an earned counter without granting intent before contact")
	var distant := 0
	for monster in get_nodes_in_group("monsters"):
		monster.global_position = Vector3(80+distant*12,0,80)
		distant += 1
	for frame in 55:
		p.combat.advance(1.0/60)
		p.animate(1.0/60,0)
		p.update_weapon_contacts()
	check(p.combat.action=="idle" and p.combat.shadow_lifetimes.is_empty(),"a complete physical counter sweep miss grants no intent")
	trace._process(0)
	trace.queue_free()
	await process_frame
	var rows := []
	for line in FileAccess.get_file_as_string(path).split("\n",false): rows.append(JSON.parse_string(line))
	check(rows.size()>8 and rows[0].event=="session_start" and rows[-1].event=="session_end","trace session is delimited and flushed on close")
	var modifier_mouse := false
	var modifier_key := false
	var rejection := false
	var queued := false
	var hidden_reason := false
	var ordered := true
	var queued_combo := false
	var delayed_rejection := false
	for index in rows.size():
		var row: Dictionary = rows[index]
		ordered = ordered and row.sequence==index+1 and row.has("milliseconds") and row.has("state")
		if row.event=="mouse": modifier_mouse = modifier_mouse or (row.ctrl and row.pressed and row.button==MOUSE_BUTTON_LEFT)
		if row.event=="key": modifier_key = modifier_key or (row.ctrl and row.pressed and row.physical==KEY_CTRL)
		if row.event=="action_request":
			if row.requested=="fourfold":
				rejection = rejection or (row.outcome=="rejected" and "枪意不足" in row.reason)
				hidden_reason = hidden_reason or (row.state.feedback=="受击提示" and "枪意不足" in row.reason)
				if row.outcome=="queued":
					queued_combo = true
					queued = true
				if queued_combo and row.outcome=="rejected" and row.state.elapsed>=0.37: delayed_rejection = true
	check(modifier_mouse and modifier_key,"raw key and mouse events retain their actual modifier flags")
	check(rejection,"trace records the exact resource rejection")
	check(queued,"queued followup is distinguished from immediate execution")
	check(delayed_rejection,"queued resource failure also records its terminal rejection")
	check(hidden_reason,"priority HUD notice cannot hide the recorded rejection reason")
	check(ordered,"trace records carry ordered sequence, time and combat snapshots")
	p.combat.set_action("idle")
	check(p.request_action("light"),"freeing the recorder leaves ordinary requests usable")
	world.queue_free()
	await process_frame
	print("INPUT_DIAGNOSTIC_CHECKS: ",checks," FAILURES: ",failures)
	quit(1 if failures else 0)
