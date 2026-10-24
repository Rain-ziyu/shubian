extends "res://tests/replay_weapon_sequence.gd"
## Render the existing live combat controller; no pose or resource injection.
func setup() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Combat video requires native rendering")
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await super.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.camera_manual_time = 0
