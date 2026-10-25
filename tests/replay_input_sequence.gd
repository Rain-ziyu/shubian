extends "res://tests/replay_weapon_sequence.gd"
## State-aware fight through the engine input pipeline, not OS or human input.
var held_movement := {}
var input_commands := {}
var key_events := 0
var mouse_events := 0
var reply_feedback_seen := false
var flash_feedback_seen := false
func setup() -> void:
	await super.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.camera_manual_time = 0
	fighter.hit_confirmed.connect(func(action: String, _beat: int, _monster: Node, _result: Dictionary):
		if action=="reply": reply_feedback_seen = reply_feedback_seen or "反击命中" in fighter.feedback.text
		if action=="flash": flash_feedback_seen = flash_feedback_seen or ("闪刺命中" in fighter.feedback.text and ("%d/5" % fighter.combat.shadow_lifetimes.size()) in fighter.feedback.text)
	)
func key(code: Key, pressed: bool, combo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = combo
	Input.parse_input_event(event)
	key_events += 1
func request_action(action: String) -> void:
	input_commands[action] = int(input_commands.get(action,0))+1
	if action in ["guard","plant","counter_window"]:
		var code: Key = KEY_Q if action=="guard" else (KEY_SPACE if action=="plant" else KEY_CTRL)
		key(code,true,action!="guard")
		key(code,false)
	else:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT if action=="spin" else MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.ctrl_pressed = action in ["flash","fourfold","spin"]
			Input.parse_input_event(event)
			mouse_events += 1
	Input.flush_buffered_events()
func set_movement(local: Vector3) -> void:
	var wanted := {KEY_A:local.x< -0.1,KEY_D:local.x>0.1,KEY_S:local.z>0.1,KEY_W:local.z< -0.1}
	for code in wanted:
		if bool(wanted[code])==bool(held_movement.get(code,false)): continue
		key(code,wanted[code])
		held_movement[code] = wanted[code]
	Input.flush_buffered_events()
func finish_sequence() -> void:
	var covered := key_events>0 and mouse_events>0
	for action in ["guard","reply","flash","fourfold","spin","plant","counter_window"]: covered = covered and input_commands.has(action)
	var checks := sequence_checks()
	checks["input_coverage"] = covered
	checks["confirmed_followup_feedback"] = reply_feedback_seen and flash_feedback_seen
	var passed := true
	for value in checks.values(): passed = passed and value
	var report := {"passed":passed,"checks":checks,"key_events":key_events,"mouse_events":mouse_events,"commands":input_commands,"contacts":hit_counts,"scope":"live single monster with state-aware controller; movement and attacks through Input.parse_input_event; no injected health shadows or confirmations; not OS or human difficulty acceptance"}
	var file := FileAccess.open("res://../Shubian-input-sequence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("INPUT_SEQUENCE: ",JSON.stringify(report))
	if not passed:
		quit(1)
		return
	super.finish_sequence()
