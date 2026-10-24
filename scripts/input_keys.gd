extends RefCounted
## Preserve physical bindings and accept logical-only or unmapped-special injected codes.
var pressed_actions := {}
const MOVEMENT := ["move_forward","move_back","move_left","move_right","sprint"]
const BOUND_KEYS := [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SHIFT,KEY_Q,KEY_E,KEY_R,KEY_TAB,KEY_SPACE,KEY_CTRL,KEY_F1,KEY_F5,KEY_ESCAPE]
static func logical_fallback(event: InputEventKey) -> bool:
	return event.physical_keycode==0 or (event.physical_keycode>=KEY_ESCAPE and event.physical_keycode not in BOUND_KEYS and event.keycode in BOUND_KEYS)
static func code(event: InputEventKey) -> Key:
	return event.keycode if logical_fallback(event) else event.physical_keycode
func movement(event: InputEventKey) -> void:
	if not logical_fallback(event): return
	for action in MOVEMENT:
		if not InputMap.has_action(action): continue
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey and binding.physical_keycode!=0 and binding.physical_keycode==event.keycode:
				if event.pressed:
					Input.action_press(action)
					pressed_actions[action] = true
				else:
					Input.action_release(action)
					pressed_actions.erase(action)
				break
func release() -> void:
	for action in pressed_actions: Input.action_release(action)
	pressed_actions.clear()
