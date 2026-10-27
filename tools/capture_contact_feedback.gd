extends SceneTree
const Feedback = preload("res://scripts/hit_feedback.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1000,500)
	root.content_scale_size = root.size
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("253b40")
	stage.add_child(env)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(6,2,0)
	camera.look_at(Vector3(0,1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var title := Label.new()
	title.text = "SHUBIAN / CONTACT FEEDBACK / SIDE CAMERA / 0.06 s"
	title.position = Vector2(24,24)
	title.add_theme_font_size_override("font_size",22)
	layer.add_child(title)
	for i in 5:
		var effect := Feedback.new()
		effect.action = "heavy" if i in [1,4] else "light"
		effect.weak = i==2
		effect.armor_reduced = i in [3,4]
		effect.armor_just_broken = i==4
		effect.damage = [26,42,47,12,19][i]
		stage.add_child(effect)
		effect.position = Vector3(0,1,(i-2)*1.9)
		effect.set_process(false)
		effect.advance_visual(0.06)
		var label := Label3D.new()
		label.text = ["LIGHT","HEAVY","WEAK POINT","ARMORED","ARMOR BREAK"][i]
		label.font_size = 36
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stage.add_child(label)
		label.position = effect.position+Vector3(0,-0.65,0)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-contact-feedback.png"))
	print("CONTACT_FEEDBACK_CAPTURE: ",error," variants=5 / controlled presentation samples")
	# Allow the short native audio voices to finish before disposing the study.
	await create_timer(0.25).timeout
	stage.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
