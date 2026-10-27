extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var stage: Node3D
var models: Array[Node3D] = []
var species_data: Array[Dictionary] = []
var frame := 0
var running := false
var slope_mode := false
var travel_mode := false
var turn_mode := false
var study_camera: Camera3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	slope_mode = "--slope" in OS.get_cmdline_user_args()
	travel_mode = "--travel" in OS.get_cmdline_user_args()
	turn_mode = "--turn" in OS.get_cmdline_user_args()
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("96aaa4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := Model.V.piece(stage,Vector3(0,-0.15,1),Vector3(22,0.3,18),Color("596d64"))
	if slope_mode:
		floor_mesh.rotation.z = atan(0.2)
		floor_mesh.position.y = -0.15/cos(atan(0.2))
	if travel_mode or turn_mode:
		for z in range(-8,10): Model.V.piece(stage,Vector3(0,0.01,z),Vector3(22,0.01,0.08),Color("75857b"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for side in [-1,1]:
		var holder := Node3D.new()
		stage.add_child(holder)
		holder.position.x = side*3.2
		if slope_mode: holder.position.y = holder.position.x*0.2
		var species: Dictionary = data.species[0 if side==-1 else 3]
		var model := Model.create(holder,species)
		models.append(model)
		species_data.append(species)
		var label := Label3D.new()
		label.text = "苔甲 · 四足" if side==-1 else "苇影 · 双足"
		label.position = Vector3(0,4,0)
		label.font_size = 38
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(label)
	var camera := Camera3D.new()
	study_camera = camera
	stage.add_child(camera)
	camera.position = Vector3(8,6,-15)
	camera.look_at(Vector3(0,1.2,0))
	camera.fov = 47
	camera.current = true
	var title := Label.new()
	title.text = "戍边 · 腿部骨骼步态研究（原地循环，非实战）"
	if slope_mode: title.text = "戍边 · 支撑脚坡面示意（静态，非实战）"
	if travel_mode: title.text = "戍边 · 行进支撑脚研究（非实战回放）"
	if turn_mode: title.text = "戍边 · 蓄势转向换步（动作研究，非实战）"
	title.position = Vector2(20,18)
	title.add_theme_font_size_override("font_size",26)
	root.add_child(title)
	for warmup in 30: await process_frame
	running = true
func _process(_delta: float) -> bool:
	if not running: return false
	var time := float(frame)/60
	for i in 2:
		if turn_mode:
			models[i].get_parent().rotation.y = 0.65*minf(time/0.3,1)
			var ground := func(_point: Vector3) -> float: return 0.0
			var normal := func(_point: Vector3) -> Vector3: return Vector3.UP
			var clock := minf(float(species_data[i].windup),0.2+time)
			Model.animate(models[i],species_data[i],0,"windup",clock,0,ground,normal,false,{},1.0/60)
		elif travel_mode:
			models[i].get_parent().position.z = 4-time*2.4
			var ground := func(_point: Vector3) -> float: return 0.0
			var normal := func(_point: Vector3) -> Vector3: return Vector3.UP
			Model.animate(models[i],species_data[i],time*2.4*Model.GAIT_PER_METER,"idle",0,2.4,ground,normal)
		elif slope_mode:
			var baseline: float = models[i].get_parent().position.y
			var ground := func(point: Vector3) -> float: return point.x*0.2-baseline
			var normal := func(_point: Vector3) -> Vector3: return Vector3(-0.2,1,0).normalized()
			Model.animate(models[i],species_data[i],0,"idle",0,0,ground,normal)
		else: Model.animate(models[i],species_data[i],time*5,"idle",0,4)
	if travel_mode:
		study_camera.position = Vector3(8,6,-15)+Vector3(0,0,4-time*2.4)
		study_camera.look_at(Vector3(0,1.2,4-time*2.4))
	frame += 1
	if turn_mode and frame in [6,12,18]: call_deferred("capture_turn",frame)
	if slope_mode and frame==120: call_deferred("capture_slope")
	if frame>=240:
		running = false
		call_deferred("finish")
	return false
func capture_slope() -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-creature-slope.png"))
	print("CREATURE_SLOPE_CAPTURE: ",result)
func capture_turn(sample: int) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-creature-turn-%02d.png" % sample))
	print("CREATURE_TURN_CAPTURE: sample=",sample," result=",result," / controlled windup fixture")
func finish() -> void:
	print("CREATURE_LEG_STUDY: 240 frames; ","turn" if turn_mode else "travel" if travel_mode else ("slope" if slope_mode else "in-place"),"; visual study only")
	stage.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
