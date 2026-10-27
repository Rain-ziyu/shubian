extends SceneTree
const Model = preload("res://scripts/hunter_model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("d5d9d1")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce1df")
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7,-2.6,0)
	key.light_energy = 0.7
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3,0.5,0)
	fill.light_energy = 0.2
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(12,6)
	floor.material_override = Model.V.mat(Color("bfc6bb"))
	world.add_child(floor)
	var holders: Array[Node3D] = []
	var rigs: Array[Dictionary] = []
	for index in 3:
		var holder := Node3D.new()
		holders.append(holder)
		world.add_child(holder)
		holder.position.x = (1-index)*1.35
		var rig := Model.create(holder)
		rigs.append(rig)
		rig.root.rotation.y = [0.0,PI/2,PI][index]
		rig.weapon.position = Vector3(0,1.05,0.26)
		rig.weapon.rotation.z = 0.35
		Model.pose_legs(rig,"idle",0,false,0,0,0)
		Model.pose_arms(rig,false,0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.02,-6.2)
	camera.look_at(Vector3(0,1.02,0))
	camera.fov = 26
	camera.current = true
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var title := Label.new()
	title.position = Vector2(30,24)
	title.text = "SHUBIAN / FOREST RANGER / MESH STUDY"
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("28352e"))
	layer.add_child(title)
	for index in 3:
		var label := Label.new()
		label.text = ["FRONT","SIDE","BACK"][index]
		label.position = Vector2(200+index*340,80)
		label.size.x = 200
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",22)
		label.add_theme_color_override("font_color",Color("28352e"))
		layer.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-character-turnaround.png"))
	print("CHARACTER_TURNAROUND: ",error)
	if "--equipment" in OS.get_cmdline_user_args():
		var armed := "--armed" in OS.get_cmdline_user_args()
		if armed:
			rigs[0].weapon.position = Vector3(0.32,1.20,-0.32)
			rigs[0].weapon.rotation = Vector3(-PI/2,0.40,-0.15)
			Model.pose_arms(rigs[0],true,0)
		layer.hide()
		for index in [1,2]: holders[index].hide()
		root.size = Vector2i(1024,1024)
		root.content_scale_size = Vector2i(1024,1024)
		camera.position = Vector3(2.05,1.05,-1.15)
		camera.look_at(Vector3(1.35,1.03,0))
		camera.fov = 29
		if armed:
			var elbow: Vector3 = rigs[0].arms[1].elbow.global_position
			camera.position = elbow+Vector3(0.65,0.12,-0.85)
			camera.look_at(elbow)
			camera.fov = 32
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-equipment-armed-detail.png" if armed else "res://../Shubian-equipment-detail.png"))
		camera.position = Vector3(2.10,1.10,1.25)
		camera.look_at(Vector3(1.35,0.98,0))
		camera.fov = 34
		if armed:
			var elbow: Vector3 = rigs[0].arms[1].elbow.global_position
			camera.position = elbow+Vector3(0.65,0.12,0.85)
			camera.look_at(elbow)
			camera.fov = 32
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-equipment-armed-rear-detail.png" if armed else "res://../Shubian-equipment-rear-detail.png"))
	if "--boots" in OS.get_cmdline_user_args():
		layer.hide()
		for index in [1,2]: holders[index].hide()
		root.size = Vector2i(1024,1024)
		root.content_scale_size = Vector2i(1024,1024)
		camera.position = Vector3(1.75,0.35,-0.85)
		camera.look_at(Vector3(1.35,0.18,-0.04))
		camera.fov = 28
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-boots-detail.png"))
		print("CHARACTER_BOOTS_CAPTURE: ",error)
	if "--fabric" in OS.get_cmdline_user_args():
		layer.hide()
		for index in [1,2]: holders[index].hide()
		root.size = Vector2i(1024,1024)
		root.content_scale_size = Vector2i(1024,1024)
		camera.position = Vector3(1.35,1.38,-1.0)
		camera.look_at(Vector3(1.35,1.38,0))
		camera.fov = 30
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-fabric-detail.png"))
		print("CHARACTER_FABRIC_CAPTURE: ",error)
	if "--head" in OS.get_cmdline_user_args() or "--blink" in OS.get_cmdline_user_args():
		var blink_study := "--blink" in OS.get_cmdline_user_args()
		layer.hide()
		for index in [1,2]: holders[index].hide()
		holders[0].get_node("HunterRig/Trident").hide()
		root.size = Vector2i(768,768)
		root.content_scale_size = Vector2i(768,768)
		camera.position = Vector3(1.35,1.67,-1)
		camera.look_at(Vector3(1.35,1.67,0))
		camera.fov = 35
		var sheet := Image.create(2304,768,false,Image.FORMAT_RGB8)
		for index in 3:
			holders[0].get_node("HunterRig").rotation.y = 0.0 if blink_study else [0.0,0.65,PI/2][index]
			if blink_study:
				rigs[0].blink_clock = [0.0,3.27,3.42][index]-1.0/60
				Model.Outfit.Face.animate(rigs[0],"idle",0,1.0/60)
				Model.pose_arms(rigs[0],false,0)
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(frame,Rect2i(0,0,768,768),Vector2i(index*768,0))
		var result := sheet.save_png(ProjectSettings.globalize_path("res://../Shubian-ranger-"+("blink" if blink_study else "head")+"-study.png"))
		print("CHARACTER_HEAD_CAPTURE: ",result)
		if result!=OK: error = result
	if "--details" in OS.get_cmdline_user_args():
		layer.visible = false
		for index in [1,2]: holders[index].hide()
		for detail in ["knee","elbow"]:
			camera.position = Vector3(1.35,0.6,-1.6) if detail=="knee" else Vector3(2.1,1.25,-1.6)
			camera.look_at(Vector3(1.35,0.52,0) if detail=="knee" else Vector3(1.52,1.2,0))
			camera.fov = 24
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-joint-"+detail+".png"))
	world.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
