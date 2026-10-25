extends SceneTree
## CPU-only cold/warm timing of the real visibility component. Not an FPS test.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var hunter = world.hunter
	hunter.set_physics_process(false)
	hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cue = hunter.get_node("OcclusionVisibility")
	cue.set_physics_process(false)
	for monster in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	for monster in get_nodes_in_group("monsters"):
		monster.rotation = Vector3.ZERO
		monster.CreatureModel.animate(monster.mesh,monster.data,0,"idle",0,0)
		hunter.global_position = monster.global_position+Vector3(0,0,-2)
		hunter.rig.root.rotation = Vector3.ZERO
		hunter.animate(0,0)
		camera.global_position = monster.global_position+Vector3(0,2,7)
		camera.look_at(monster.global_position+Vector3(0,1,0))
		cue.triangle_meshes.clear()
		var measurements := []
		for iteration in 8:
			var start := Time.get_ticks_usec()
			cue._physics_process(1.0/60)
			measurements.append((Time.get_ticks_usec()-start)/1000.0)
		print("VISIBILITY_TIMING: ",JSON.stringify({"species":monster.data.id,"update_ms":measurements,"cached_geometries":cue.triangle_meshes.size(),"occluded":cue.occluded}))
	world.queue_free()
	await process_frame
	quit()
