extends SceneTree
## Animation inspection only. Poses are sampled directly; this is not a gameplay proof.
var world: Node3D
var fighter: CharacterBody3D
var title: Label
var index := 0
var elapsed := 0.0
var finished := false
var captured := false
const MOVES := ["light","heavy","pull","guard","reply","finisher"]
const NAMES := ["斜刺：预摆与前送","横扫：转腰与跟随","回拉：后坐收杆","格挡：架杆蓄势","反击：枪尾前送","终结：支撑移步与踢击"]
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	world.hunter.set_process_unhandled_input(false)
	await create_timer(0.5).timeout
	fighter = world.hunter
	fighter.set_physics_process(false)
	fighter.set_process_unhandled_input(false)
	for monster in get_nodes_in_group("monsters"):
		monster.set_physics_process(false)
		monster.hide()
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	fighter.pitch = -0.25
	fighter.yaw = 0
	fighter.rig.root.rotation.y = 0
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = fighter.global_position+Vector3(4,2.1,-4)
	camera.look_at(fighter.global_position+Vector3(0,0.95,0))
	camera.fov = 32
	camera.current = true
	var layer := CanvasLayer.new()
	world.add_child(layer)
	title = Label.new()
	title.position = Vector2(24,24)
	title.add_theme_font_size_override("font_size",25)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(title)
	fighter.combat.set_action(MOVES[0])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	physics_frame.connect(step)
func step() -> void:
	if finished: return
	elapsed += 1.0/60.0
	var move: String = MOVES[index]
	var duration: float = fighter.Combat.MOVES[move].duration
	title.text = "戍边 / 动作姿态检查（非实战回放）\n"+NAMES[index]
	if elapsed<=duration:
		fighter.combat.elapsed = elapsed
	else:
		if fighter.combat.action!="idle": fighter.combat.set_action("idle")
	fighter.animate(1.0/60,0)
	if move=="heavy" and elapsed>=0.44 and not captured:
		captured = true
		capture.call_deferred()
	if elapsed>=duration+0.28:
		index += 1
		elapsed = 0
		if index>=MOVES.size():
			finished = true
			finish.call_deferred()
		else: fighter.combat.set_action(MOVES[index])
func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-torso-heavy.png"))
func finish() -> void:
	print("ANIMATION_STUDY_FINISHED: six actions; presentation-only sampling")
	await create_timer(0.25).timeout
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
