extends SceneTree
## Actual player spring-arm projection on isolated, stationary encounter fixtures.
## Does not prove occlusion, live-combat readability, or visual art quality.
func _initialize(): call_deferred("run")
func projected(camera: Camera3D, points: Array[Vector3]) -> Dictionary:
	var low=Vector2(INF,INF)
	var high=Vector2(-INF,-INF)
	var visible:=0
	var rect=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	for point in points:
		var screen=camera.unproject_position(point)
		low=low.min(screen);high=high.max(screen)
		if not camera.is_position_behind(point) and rect.has_point(screen): visible+=1
	return {"visible":visible,"total":points.size(),"min":[low.x,low.y],"max":[high.x,high.y]}
func run():
	var world=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player=world.hunter
	player.set_physics_process(false);player.set_process_input(false);player.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var monsters=get_nodes_in_group("monsters")
	for monster in monsters:monster.set_physics_process(false)
	player.global_position=Vector3(100,.05,100);player.yaw=0;player.pitch=-.25
	var rows=[]
	for monster in monsters:
		for distance in [3.,6.,10.]:
			monster.global_position=player.global_position+Vector3(0,0,-distance)
			monster.rotation.y=PI
			monster.CreatureModel.animate(monster.mesh,monster.data,0,"idle",0,0)
			player.lock_target=monster
			for frame in range(180):player.update_camera_framing(1./60)
			await physics_frame
			await physics_frame
			var head: MeshInstance3D=monster.mesh.get_node("Neck/HeadSurface")
			var points: Array[Vector3]=[]
			for corner in range(8):points.append(head.to_global(head.mesh.get_aabb().get_endpoint(corner)))
			var hero=projected(player.camera,[player.global_position,player.global_position+Vector3.UP*1.8])
			rows.append({"species":monster.data.id,"distance":distance,"head_bounds":projected(player.camera,points),"hunter":hero,"spring_length":player.camera.get_parent().get_hit_length()})
		monster.global_position=Vector3(-100,0,-100)
	var report={"cases":rows,"scope":"isolated stationary idle pose, default pitch, actual spring arm; not occlusion or combat acceptance"}
	var folder=ProjectSettings.globalize_path("res://../verification/camera-projection")
	DirAccess.make_dir_recursive_absolute(folder)
	var file=FileAccess.open(folder+"/latest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("CAMERA_PROJECTION_AUDIT ",JSON.stringify(report))
	world.queue_free();await process_frame;quit()
