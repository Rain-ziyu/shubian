extends SceneTree
const Terrain = preload("res://scripts/forest_terrain.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	world.hunter.set_physics_process(false)
	check(get_nodes_in_group("terrain").size()==1,"one terrain instance")
	check(Terrain.height_at(0,0)==0,"central combat route remains level")
	check(Terrain.height_at(48,40)>0.5,"forest has raised terrain")
	check(Terrain.height_at(41,0)<0,"stream has recessed bed")
	for center in Terrain.CLEARINGS:
		check(is_zero_approx(Terrain.height_at(center.x,center.y)),"combat clearing remains navigable")
	for point in [Vector2(0,0),Vector2(48,40),Vector2(-48,42),Vector2(40,0)]:
		var probe := PhysicsRayQueryParameters3D.create(Vector3(point.x,10,point.y),Vector3(point.x,-5,point.y),2)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(probe)
		check(not hit.is_empty(),"terrain is solid from above")
		if not hit.is_empty():
			check(absf(hit.position.y-Terrain.height_at(point.x,point.y))<0.02,"collision matches rendered ground")
			check(hit.normal.y>0.72,"surface is walkable and normals face up")
	var p = world.hunter
	p.global_position = Vector3(72,1,0)
	p.combat.set_action("idle")
	p.finish_throw(Vector3(78,0,0))
	check(p.global_position.x==72,"unsupported landing cancels displacement")
	var cached_match := true
	for x in range(-Terrain.HALF,Terrain.HALF+1,Terrain.STEP):
		for z in range(-Terrain.HALF,Terrain.HALF+1,Terrain.STEP):
			cached_match = cached_match and Terrain.grid_height(x,z)==Terrain.height_at(x,z)
	check(cached_match,"all cached grid heights exactly match the authored surface")
	check(Terrain.grid_heights.size()==3721,"fixed-grid height cache stays bounded to the map vertices")
	print("TERRAIN_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
