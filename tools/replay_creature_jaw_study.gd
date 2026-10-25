extends SceneTree
## Direct animation study, not a live fight or difficulty proof.
var world: Node3D
var creatures: Array = []
var camera: Camera3D
var title: Label
var index := 0
var elapsed := 0.0
var captures := {}
var finished := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.hunter.set_physics_process(false)
	world.hunter.hide()
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	for creature in get_nodes_in_group("monsters"):
		creature.set_physics_process(false)
		creature.set_process(false)
		creature.hide()
		creature.label.hide()
		for marker in creature.weak_markers: marker.hide()
		creature.position = Vector3(0,0.05,-10)
		creature.rotation = Vector3.ZERO
		creatures.append(creature)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.fov = 35
	camera.make_current()
	var layer := CanvasLayer.new()
	world.add_child(layer)
	title = Label.new()
	title.position = Vector2(24,24)
	title.add_theme_font_size_override("font_size",23)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(title)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	physics_frame.connect(step)
func step() -> void:
	if finished: return
	var creature: CharacterBody3D = creatures[index]
	for candidate in creatures: candidate.visible = candidate==creature
	var windup: float = creature.data.windup
	var recovery: float = creature.data.recovery
	var phase := "windup"
	var clock := elapsed
	if elapsed>=windup+0.65:
		phase = "recover"
		clock -= windup+0.65
	elif elapsed>=windup:
		phase = "active"
		clock -= windup
	creature.CreatureModel.animate(creature.mesh,creature.data,0,phase,clock,0)
	var s: float = creature.data.size
	var focus: Vector3 = creature.mesh.global_position
	camera.position = focus+Vector3(s*1.25,s*0.9,-s*1.6)
	camera.look_at(focus+Vector3(0,s*(0.58 if "quadruped" in creature.data.body else 0.67),-s*0.57))
	title.text = "戍边 / 头口动作研究（非实战）\n"+str(creature.data.name)+" · "+str({"windup":"蓄势","active":"出手","recover":"收势"}[phase])
	var moment := "ready" if elapsed<0.02 else ("open" if phase=="active" and clock>=0.15 else "")
	var key := str(index)+moment
	if moment!="" and not captures.has(key):
		captures[key] = true
		capture.call_deferred(str(creature.data.id),moment)
	elapsed += 1.0/60
	if elapsed>=windup+0.65+recovery:
		index += 1
		elapsed = 0
		if index==creatures.size():
			finished = true
			finish.call_deferred()
func capture(species: String, moment: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-jaw-"+species+"-"+moment+".png"))
func finish() -> void:
	print("CREATURE_JAW_STUDY: five species; presentation sampling only")
	world.queue_free()
	await process_frame
	quit()
