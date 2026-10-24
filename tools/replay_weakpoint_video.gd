extends "res://tests/replay_weakpoints.gd"
## Native capture of the live tactics replay, without injected poses or resources.
var captured := {}
func setup() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Weakpoint video requires native rendering")
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await super.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.camera_manual_time = 0
	process_frame.connect(sample_warning)
func sample_warning() -> void:
	if result_saved or not is_instance_valid(monster): return
	if monster.phase=="windup" and not captured.has("windup"):
		captured["windup"] = true
		capture.call_deferred("windup")
func on_contact(action: String, beat: int, target: Node3D, result: Dictionary) -> void:
	super.on_contact(action,beat,target,result)
	if result.weak and not captured.has("weak-hit"):
		captured["weak-hit"] = true
		capture.call_deferred("weak-hit")
func capture(moment: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../Shubian-live-"+str(monster.data.id)+"-"+moment+".png")
	var error := root.get_texture().get_image().save_png(path)
	print("LIVE_WEAKPOINT_CAPTURE: ",moment," result=",error," path=",path)
