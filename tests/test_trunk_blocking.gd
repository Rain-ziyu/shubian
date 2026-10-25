extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player = world.hunter
	player.set_physics_process(false)
	var monsters := get_nodes_in_group("monsters")
	for index in monsters.size():
		monsters[index].set_physics_process(false)
		monsters[index].global_position = Vector3(60+index*12,0,60)
	for monster in monsters:
		monster.global_position = Vector3(0,0.05,-12)
		monster.rotation = Vector3.ZERO
		monster.CreatureModel.animate(monster.mesh,monster.data,0,"idle",0,0)
		var body: MeshInstance3D = monster.mesh.get_node("BodySurface")
		var surface := body.mesh.generate_triangle_mesh()
		for side in [-1,1]:
			player.global_position = monster.global_position+Vector3(0,0,side*6)
			await physics_frame
			await physics_frame
			for tick in 90:
				player.velocity = Vector3(0,-0.5,-side*6)
				player.move_and_slide()
				await physics_frame
			var distance: float = absf(monster.to_local(player.global_position).z)
			check(distance>float(monster.data.size)*(0.44 if side<0 else 0.53),"physical movement cannot enter elongated trunk: "+str(monster.data.id))
			for height in [1.1,1.5]:
				var point := body.to_local(player.to_global(Vector3(0,height,0)))
				var exit := surface.intersect_segment(point,Vector3(float(monster.data.size)*3,point.y,point.z))
				check(exit.is_empty(),"hunter chest/head stays outside visible resting trunk: %s side=%d height=%.1f point=%s" % [monster.data.id,side,height,str(point)])
		monster.global_position = Vector3(60+monsters.find(monster)*12,0,60)
	print("TRUNK_BLOCKING_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
