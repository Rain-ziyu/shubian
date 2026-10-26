extends SceneTree
const Player = preload("res://scripts/player.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(800,600)
	root.content_scale_size = Vector2i(800,600)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("58655c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,-0.4,0)
	stage.add_child(light)
	var floor_mesh := Player.Visuals.piece(stage,Vector3(0,-0.12,0),Vector3(10,0.2,10),Color("7b887b"))
	floor_mesh.create_trimesh_collision()
	var p := Player.new()
	p.set_physics_process(false)
	stage.add_child(p)
	p.set_physics_process(false)
	var segmented := "--segmented-mantle" in OS.get_cmdline_user_args()
	if segmented: preload("res://tools/prepare_segmented_mantle.gd").apply(p)
	if "--shoulder-parts" in OS.get_cmdline_user_args():
		var component_colors := {"UpperArmSurface":"ff3333","JointClothShoulder":"3388ff","Elbow":"ff33ff","JointClothElbow":"ffff33"}
		for binding in p.rig.skinning.bindings:
			var name: String = str(binding.source.name)
			for prefix in component_colors:
				if name.begins_with(prefix): binding.rendered.material_override = Player.Visuals.mat(Color(component_colors[prefix]))
	await process_frame
	await process_frame
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(3.8,2,0.6)
	camera.look_at(Vector3(0,1,-0.6))
	camera.fov = 35
	camera.current = true
	var shoulder_detail := "--shoulder" in OS.get_cmdline_user_args()
	var game_view := "--game-view" in OS.get_cmdline_user_args()
	var feet_detail := "--feet" in OS.get_cmdline_user_args()
	if game_view:
		camera.position = Vector3(0.98,2.75,4.55)
		camera.look_at(Vector3(0,1.1,-0.35))
		camera.fov = 68
	if feet_detail:
		camera.position = Vector3(1.1,0.85,1.6)
		camera.look_at(Vector3(0,0.32,0))
		camera.fov = 35
	if shoulder_detail:
		camera.position = Vector3(1.45,1.65,-1.35)
		camera.look_at(Vector3(0,1.38,-0.05))
		camera.fov = 30
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var label := Label.new()
	label.position = Vector2(20,20)
	label.add_theme_font_size_override("font_size",24)
	layer.add_child(label)
	var sheet := Image.create(2400,600,false,Image.FORMAT_RGB8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.yaw = 0
	var aimed := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--aim="):
			p.pitch = float(argument.trim_prefix("--aim="))
			aimed = true
	var action := "light"
	for candidate in ["heavy","pull","throw","plant","guard","reply","finisher","flash","fourfold","spin","turn"]:
		if "--"+candidate in OS.get_cmdline_user_args(): action = candidate
	p.combat.set_action(action)
	if action=="plant":
		camera.fov = 42
		camera.look_at(Vector3(0,1.25,-0.35))
	p.rig.root.rotation.y = 0
	for i in 3:
		var times := {"light":[0.11,0.25,0.34],"heavy":[0.18,0.43,0.60],"pull":[0.22,0.40,0.58],"throw":[0.0,0.20,0.37],"plant":[0.18,0.34,0.60]}
		times["reply"] = [0.10,0.36,0.52]
		times["guard"] = [0.0,0.09,0.18]
		times["finisher"] = [0.80,0.95,1.14]
		times["flash"] = [0.08,0.23,0.39]
		times["fourfold"] = [0.18,0.33,0.43]
		times["turn"] = [0.18,0.40,0.44]
		times["spin"] = [0.18,0.38,0.85]
		var t: float = times[action][i]
		p.combat.elapsed = t
		p.animate(0,0)
		var labels: Array = {"throw":["01 / READY","02 / WINDUP","03 / RELEASE PREPARATION"],"plant":["01 / RAISE","02 / DRIVE","03 / SETTLE"]}.get(action,["01 / PREPARE","02 / CONTACT","03 / FOLLOW THROUGH"])
		if action=="fourfold": labels = ["01 / FIRST THRUST","02 / RETRACT","03 / SECOND THRUST"]
		if action=="turn": labels = ["01 / WINDUP","02 / UPRIGHT HANDOFF","03 / CONTACT"]
		if action=="spin": labels = ["01 / WINDUP","02 / FIRST CONTACT","03 / SECOND CONTACT"]
		label.text = labels[i]+" / %.2f s" % t
		if aimed: label.text += " / AIM %.2f" % p.pitch
		await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.resize(800,600)
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,Rect2i(0,0,800,600),Vector2i(i*800,0))
	var paths := {"light":"Shubian-light-thrust","heavy":"Shubian-heavy-sweep","pull":"Shubian-pull-motion","throw":"Shubian-throw-motion","plant":"Shubian-plant-motion"}
	paths["reply"] = "Shubian-reply-motion"
	paths["guard"] = "Shubian-guard-motion"
	paths["finisher"] = "Shubian-kick-motion"
	paths["flash"] = "Shubian-flash-motion"
	paths["fourfold"] = "Shubian-fourfold-keyframes"
	paths["turn"] = "Shubian-turn-keyframes"
	paths["spin"] = "Shubian-spin-keyframes"
	var suffix := "-parts" if "--shoulder-parts" in OS.get_cmdline_user_args() else "-feet" if feet_detail else ("-shoulder" if shoulder_detail else ("-game-view" if game_view else ""))
	if aimed: suffix += "-aim"
	sheet.save_png(ProjectSettings.globalize_path("res://../"+("segmented-" if segmented else "")+str(paths[action])+suffix+".png"))
	stage.queue_free()
	await process_frame
	quit()
