extends Node
## Draw real Compatibility materials while actors are paused, before control.
var world: Node3D
var complete := false
var preparation_ms := 0.0
var overlay: CanvasLayer

func _ready() -> void:
	var started := Time.get_ticks_usec()
	if DisplayServer.get_name()=="headless":
		world = load("res://scenes/main/main.tscn").instantiate()
		add_child(world)
		complete = true
		return
	overlay = CanvasLayer.new()
	overlay.layer = 200
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color("17251f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var title := Label.new()
	title.text = "戍边\n准备湿林与装备……"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size",30)
	background.add_child(title)
	await RenderingServer.frame_post_draw
	world = load("res://scenes/main/main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.combat_hud.update_state(world.hunter,0)
	var player_camera: Camera3D = world.hunter.camera
	world.hunter.mount.position = world.hunter.global_position+Vector3(0,1.5,0)
	world.hunter.mount.rotation = Vector3(world.hunter.pitch,world.hunter.yaw,0)
	player_camera.position.z = 5.0
	var survey := Camera3D.new()
	world.add_child(survey)
	survey.projection = Camera3D.PROJECTION_ORTHOGONAL
	survey.size = 150
	survey.position = Vector3(0,100,0.1)
	survey.look_at(Vector3.ZERO)
	survey.current = true
	# Render the actual actors/environment, rather than only loading resources.
	await RenderingServer.frame_post_draw
	title.text = "戍边\n准备雾效与枪影……"
	player_camera.current = true
	var effects := Node3D.new()
	world.add_child(effects)
	var location: Vector3 = world.hunter.global_position+Vector3.FORWARD*2
	for kind in ["mist","pulse"]:
		var hazard = load("res://scripts/hazard.gd").new()
		hazard.kind = kind
		hazard.damage = 0
		hazard.target = world.hunter
		effects.add_child(hazard)
		hazard.global_position = location
	var ghost: Node3D = load("res://scripts/visuals.gd").trident(effects,true)
	ghost.global_position = location+Vector3(0,1,0)
	# Warm the actual first-hit material and both damage-font sizes while paused.
	# Include every digit and each outcome prefix without playing impact audio.
	for variant in 4:
		var contact = load("res://scripts/hit_feedback.gd").new()
		contact.audio_enabled = false
		contact.damage = 1234567890
		contact.weak = variant==1
		contact.armor_reduced = variant==2
		contact.armor_just_broken = variant==3
		effects.add_child(contact)
		contact.global_position = location+Vector3((variant-1.5)*0.3,1,0)
		contact.set_process(false)
		contact.advance_visual(0.06)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	effects.queue_free()
	survey.queue_free()
	await get_tree().process_frame
	# Let deferred mesh/node deletion finish behind the preparation screen.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	preparation_ms = (Time.get_ticks_usec()-started)/1000.0
	world.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	overlay.queue_free()
	complete = true
	print("SHUBIAN_PREPARATION: milliseconds=",preparation_ms," actors_paused_until_complete=true")
