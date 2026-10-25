extends "res://tests/replay_interruptions.gd"
## Capture actual live damage: fourfold is interrupted, armored spin continues.
var captured := {}
func setup() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Interruption video requires native rendering")
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await super.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.yaw = 0
	fighter.pitch = -0.25
	fighter.camera_manual_time = 0
	process_frame.connect(sample_feedback)
func sample_feedback() -> void:
	var moment := ""
	if "被打断" in fighter.feedback.text: moment = "interrupted"
	elif "动作继续" in fighter.feedback.text: moment = "armored"
	elif fighter.combat.action=="fourfold" and fighter.combat.elapsed>0.18: moment = "active"
	if moment!="" and not captured.has(moment):
		captured[moment] = true
		capture.call_deferred(moment)
func capture(moment: String) -> void:
	# Allow the visibility pass to consume damage that occurred later in the tick.
	if moment=="interrupted":
		for frame in 6: await physics_frame
	else:
		await process_frame
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../Shubian-action-feedback-"+moment+".png")
	var error := root.get_texture().get_image().save_png(path)
	print("ACTION_FEEDBACK_CAPTURE: ",moment," result=",error)
