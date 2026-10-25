extends SceneTree
## Scripted strike presentation study; not player input or combat difficulty proof.
var world: Node3D
var subjects: Array[Node] = []
var actor: CharacterBody3D
var camera: Camera3D
var title: Label
var index := 0
var time := 0.0
var struck := false
var finished := false
var captured := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.5).timeout
	world.hunter.set_physics_process(false)
	world.hunter.set_process_unhandled_input(false)
	world.hunter.hide()
	world.hunter.global_position = Vector3(30,0,0)
	subjects = get_nodes_in_group("monsters")
	for m in subjects:
		m.set_physics_process(false)
		m.hide()
		m.global_position = Vector3(80+subjects.find(m)*12,0,80)
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 36
	var layer := CanvasLayer.new()
	world.add_child(layer)
	title = Label.new()
	title.position = Vector2(24,24)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(title)
	select_subject()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	physics_frame.connect(step)
func select_subject() -> void:
	actor = subjects[index]
	actor.show()
	actor.global_position = Vector3(0,0.03,-16)
	actor.rotation = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor.phase = "windup"
	actor.clock = float(actor.data.windup)*0.8
	actor.CreatureModel.animate(actor.mesh,actor.data,0,"windup",actor.clock,0)
	actor.label.hide()
	for marker in actor.weak_markers: marker.hide()
	time = 0
	struck = false
func step() -> void:
	if finished: return
	time += 1.0/60
	if time>=0.5:
		if not struck:
			actor.receive_strike(1,actor.global_position+Vector3(0,0,-5),"spin","body")
			struck = true
		actor._physics_process(1.0/60)
	var size: float = actor.data.size
	camera.global_position = actor.global_position+Vector3(size*2.2,size*1.3,-size*3.0)
	camera.look_at(actor.global_position+Vector3(0,size*0.6,0))
	title.text = "戍边 / 怪物硬直姿态研究（脚本命中，非实战）\n"+str(actor.data.name)+"：蓄势被打断 → 击飞 → 低头支撑 → 恢复"
	if index==0 and time>=1.1 and not captured:
		captured = true
		capture.call_deferred()
	if time>=2.8:
		actor.hide()
		actor.global_position = Vector3(80+index*12,0,80)
		index += 1
		if index==subjects.size():
			finished = true
			finish.call_deferred()
		else: select_subject()
func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-stagger-brace.png"))
func finish() -> void:
	print("STAGGER_STUDY_FINISHED: five species; scripted receive_strike, real launch physics; not player difficulty acceptance")
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
