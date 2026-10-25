extends SceneTree
var world: Node3D
var hunter: CharacterBody3D
var creature: CharacterBody3D
var camera: Camera3D
var frames := 0
var peak := 0.0
var launched := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	hunter = world.hunter
	hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.hud.get_parent().hide()
	for foe in get_nodes_in_group("monsters"):
		foe.set_physics_process(false)
		foe.global_position = Vector3(80+get_nodes_in_group("monsters").find(foe)*12,0,80)
		foe.hide()
		if foe.data.id=="reedclaw": creature = foe
	creature.show()
	creature.label.hide()
	creature.global_position = Vector3(0,0.01,-16)
	creature.rotation = Vector3.ZERO
	creature.phase = "idle"
	creature.clock = 0
	creature.velocity = Vector3.ZERO
	hunter.global_position = Vector3(0,0.01,-18.8)
	hunter.lock_target = creature
	camera = Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	camera.position = Vector3(7,4.5,-23)
	camera.look_at(Vector3(0,1.3,-17))
	camera.make_current()
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var title := Label.new()
	title.text = "戍边 / 苇爪兽扑跃恢复\n正常 AI · 自动横向走位 · 非真人操作"
	title.position = Vector2(24,24)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(title)
	await physics_frame
	await physics_frame
	creature.set_physics_process(true)
	physics_frame.connect(control)
func control() -> void:
	frames += 1
	peak = maxf(peak,creature.global_position.y)
	for action in ["move_right","sprint"]: Input.action_release(action)
	if (creature.phase=="windup" and creature.clock>0.54) or creature.phase=="active":
		Input.action_press("move_right")
		Input.action_press("sprint")
	launched = launched or creature.airborne_leap
	camera.position = Vector3(creature.global_position.x+7,4.5,creature.global_position.z-7)
	camera.look_at(Vector3(creature.global_position.x,1.3,creature.global_position.z-0.5))
	if (launched and creature.is_on_floor() and creature.phase=="recover" and creature.clock>0.9) or frames>=240:
		physics_frame.disconnect(control)
		call_deferred("finish")
func finish() -> void:
	for action in ["move_right","sprint"]: Input.action_release(action)
	print("PHYSICAL_LEAP_REPLAY: live AI, normal lateral movement inputs; peak=",peak," landed=",creature.is_on_floor()," hunter_health=",hunter.combat.health,"; state-aware controller, no injected damage or health")
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
