extends "res://tools/probe_shoulder_intersections.gd"
## Isolated cloth experiment, never installed in the game scene.
## Fixed-clock samples do not establish real-time cost or full-motion clearance.
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Cloth prototype requires native rendering")
		quit(2)
		return
	var no_collision := "--no-collision" in OS.get_cmdline_user_args()
	Engine.physics_ticks_per_second = 120
	root.size = Vector2i(800,600)
	root.content_scale_size = Vector2i(800,600)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("58655c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,-0.4,0)
	stage.add_child(light)
	var p := preload("res://scripts/player.gd").new()
	stage.add_child(p)
	p.set_physics_process(false)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	p.combat.drawn = true
	p.combat.set_action("idle")
	p.animate(0,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(1.45,1.65,-1.35)
	camera.look_at(Vector3(0,1.38,-0.05))
	camera.fov = 30
	camera.current = true
	var colliders := {}
	for side in [-1,1]:
		var body := AnimatableBody3D.new()
		body.collision_layer = 1<<20
		body.collision_mask = 0
		body.sync_to_physics = false
		var shape := CollisionShape3D.new()
		shape.shape = CapsuleShape3D.new()
		shape.shape.radius = 0.10
		shape.shape.height = 0.52
		body.add_child(shape)
		stage.add_child(body)
		colliders[side] = body
		body.global_transform = p.rig.arms[side].upper.global_transform.orthonormalized()
	var torso := AnimatableBody3D.new()
	torso.collision_layer = 1<<20
	torso.collision_mask = 0
	torso.sync_to_physics = false
	var torso_shape := CollisionShape3D.new()
	torso_shape.shape = BoxShape3D.new()
	torso_shape.shape.size = Vector3(0.35,0.42,0.25)
	torso.add_child(torso_shape)
	stage.add_child(torso)
	torso.global_position = Vector3(0,1.23,0)
	var cloths := {}
	var arm_meshes := {}
	for binding in p.rig.skinning.bindings:
		var label := str(binding.source.name)
		if label.begins_with("UpperArmSurface"): arm_meshes[-1 if label.ends_with("-1") else 1] = binding.rendered
		if label.begins_with("CapeHem"): binding.rendered.hide()
		if not label.begins_with("RainCape"): continue
		binding.rendered.hide()
		var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size(): vertices[i].x += signf(vertices[i].x)*0.035*smoothstep(0.16,0.28,absf(vertices[i].x))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool := SurfaceTool.new()
		tool.create_from(mesh,0)
		tool.index()
		var soft := SoftBody3D.new()
		soft.mesh = tool.commit()
		soft.material_override = binding.rendered.material_override
		soft.collision_layer = 1<<19
		soft.collision_mask = 0 if no_collision else 1<<20
		soft.linear_stiffness = 0.95
		soft.damping_coefficient = 0.08
		soft.total_mass = 0.25
		soft.simulation_precision = 12
		stage.add_child(soft)
		var points: PackedVector3Array = soft.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in points.size():
			if points[i].y>1.49: soft.set_point_pinned(i,true,soft.get_path_to(p.rig.torso))
		cloths[-1 if label.ends_with("-1") else 1] = soft
		print("SOFT_CLOTH_VERTICES: ",points.size())
	print("SOFT_PHYSICS: ",ProjectSettings.get_setting("physics/3d/physics_engine"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sheet := Image.create(2400,600,false,Image.FORMAT_RGB8)
	for frame in 360:
		await physics_frame
	p.combat.set_action("heavy")
	var snapshots := {22:0,52:1,72:2}
	var measurements := []
	for frame in 113:
		p.combat.elapsed = minf(0.92,frame/120.0)
		p.animate(1.0/120,0)
		for side in [-1,1]: colliders[side].global_transform = p.rig.arms[side].upper.global_transform.orthonormalized()
		torso.global_transform = p.rig.torso.global_transform
		torso.global_position += p.rig.root.global_basis*Vector3(0,0.15,0)
		await physics_frame
		if not snapshots.has(frame): continue
		var cell: int = snapshots[frame]
		for side in [-1,1]:
			var soft: SoftBody3D = cloths[side]
			var arrays: Array = soft.mesh.surface_get_arrays(0)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var faces := PackedVector3Array()
			for index in indices: faces.append(soft.to_global(soft.get_point_transform(index)))
			var skin := surface(arm_meshes[side],p.rig.skinning.skeleton)
			var cloth := TriangleMesh.new()
			var built := cloth.create_from_faces(faces)
			if not built:
				printerr("Prototype cloth triangle construction failed")
				quit(2)
				return
			var cape_edges := count_crossing_edges(faces,skin)
			var arm_edges := count_crossing_edges(skin.get_faces(),cloth)
			measurements.append({"time":frame/120.0,"side":side,"cape_edges":cape_edges,"arm_edges":arm_edges})
			print("SOFT_CROSSING: time=",frame/120.0," side=",side," cape_edges=",cape_edges," arm_edges=",arm_edges)
		camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(800,600)
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image,Rect2i(0,0,800,600),Vector2i(cell*800,0))
	var suffix := "-no-collision" if no_collision else ""
	var output := ProjectSettings.globalize_path("res://../Shubian-cape-softbody-trial"+suffix)
	sheet.save_png(output+".png")
	var file := FileAccess.open(output+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"prototype_only":true,"no_collision":no_collision,"scope":"One continuous heavy at120Hz after3s cloth settling; six shoulder pairs; no game integration, saved clip support, whole-map cost or human art acceptance. Cape hems omitted in this experiment.","physics_setting":ProjectSettings.get_setting("physics/3d/physics_engine"),"measurements":measurements},"  "))
	file.close()
	stage.queue_free()
	await process_frame
	quit()
