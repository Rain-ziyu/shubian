extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
const V = preload("res://scripts/visuals.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,500)
	root.content_scale_size = Vector2i(1600,500)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c4cdbf")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.35
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8,2.8,0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	stage.add_child(sun)
	V.piece(stage,Vector3(0,-0.2,0),Vector3(70,0.4,40),Color("8c9984"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	var holders: Array[Node3D] = []
	for index in data.species.size():
		var holder := Node3D.new()
		holder.position.x = (2-index)*9
		holder.rotation.y = 0.85
		stage.add_child(holder)
		holders.append(holder)
		var model := Model.create(holder,data.species[index])
		var label := Label3D.new()
		label.text = data.species[index].name
		label.position.y = 6.3
		label.font_size = 44
		label.pixel_size = 0.014
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(label)
		if "--no-export" not in OS.get_cmdline_user_args():
			assign_owners(model,model)
			var packed := PackedScene.new()
			var error := packed.pack(model)
			if error==OK: error = ResourceSaver.save(packed,"res://assets/models/"+str(data.species[index].id)+"-v1.tscn")
			print("CREATURE_EXPORT: ",data.species[index].id," ",error)
			if error!=OK: quit(1); return
	var reference := Node3D.new()
	reference.position.x = 22.5
	stage.add_child(reference)
	var human := Model.H.create(reference)
	human.weapon.hide()
	Model.H.pose_legs(human,"idle",0,false,0,0,0)
	Model.H.pose_arms(human,false,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(6,18,-80)
	camera.look_at(Vector3(0,2.3,0))
	camera.fov = 11
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var title := Label.new()
	title.position = Vector2(24,20)
	title.text = "SHUBIAN / FIVE CREATURES / SURFACE STUDY"
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("29392e"))
	layer.add_child(title)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-creatures-progress.png"))
	print("CREATURE_CAPTURE: ",error)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	reference.hide()
	for holder in holders:
		holder.hide()
		for child in holder.get_children():
			if child is Label3D: child.hide()
	for index in holders.size():
		var holder := holders[index]
		holder.show()
		holder.rotation.y = 0
		var size: float = data.species[index].size
		camera.position = holder.position+Vector3(size*2.2,size*1.5,-size*3)
		camera.look_at(holder.position+Vector3(0,size*0.60,0))
		camera.fov = 35
		title.text = "SHUBIAN / "+str(data.species[index].name)
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-creature-"+str(data.species[index].id)+".png"))
		if result!=OK: error = result
		if data.species[index].id=="mistfrill":
			Model.animate(holder.get_node("CreatureMesh"),data.species[index],0,"windup",data.species[index].windup,0)
			title.text = "SHUBIAN / MISTFRILL / LOADED THROAT SACS"
			await process_frame
			await RenderingServer.frame_post_draw
			result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-mistfrill-windup.png"))
			if result!=OK: error = result
		if data.species[index].id=="reedclaw":
			camera.position = holder.position+Vector3(size*4.8,size*1.1,size*0.6)
			camera.look_at(holder.position+Vector3(0,size*0.60,size*0.30))
			title.text = "SHUBIAN / REEDCLAW / SIDE SILHOUETTE"
			await process_frame
			await RenderingServer.frame_post_draw
			result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-reedclaw-side.png"))
			if result!=OK: error = result
		if data.species[index].id=="mossback":
			camera.position = holder.position+Vector3(size*2.0,size*1.2,size*2.8)
			camera.look_at(holder.position+Vector3(0,size*0.40,1.3))
			title.text = "SHUBIAN / MOSSBACK / FLEXIBLE ROOT - BONE CLUB"
			await process_frame
			await RenderingServer.frame_post_draw
			result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-creature-mossback-rear.png"))
			if result!=OK: error = result
		if data.species[index].id=="stormcrest":
			camera.position = holder.position+Vector3(size*1.4,size*1.3,size*0.65)
			camera.look_at(holder.position+Vector3(0,size*0.95,0))
			camera.fov = 40
			for state in ["idle","windup"]:
				Model.animate(holder.get_node("CreatureMesh"),data.species[index],0,state,data.species[index].windup,0)
				title.text = "SHUBIAN / STORMCREST / "+state.to_upper()
				for frame in 3: await process_frame
				await RenderingServer.frame_post_draw
				result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-stormcrest-plates-"+state+".png"))
				if result!=OK: error = result
		holder.hide()
	stage.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
func assign_owners(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		assign_owners(child,owner_node)
