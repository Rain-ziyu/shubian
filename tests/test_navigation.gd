extends SceneTree
const Navigation = preload("res://scripts/forest_navigation.gd")
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
	var nav := Navigation.new()
	nav.add_obstacle(Vector3(0,2,0),Vector3(1,4,8))
	var path := nav.path(Vector3(-8,0,0),Vector3(8,0,0),1.0)
	check(path.size()>2,"path routes around wall")
	var detour := false
	var clear := true
	for point in path:
		if absf(point.z)>=6: detour = true
		if nav.obstacles[0].grow(1).has_point(Vector2(point.x,point.z)): clear = false
	check(detour and clear,"route respects creature clearance")
	var first_grid := nav.grid_for(1)
	check(first_grid==nav.grid_for(1),"grid cached between queries")
	nav.add_obstacle(Vector3(0,2,10),Vector3(2,4,2))
	check(first_grid!=nav.grid_for(1),"new obstacles invalidate cache")
	check(nav.path(Vector3(200,0,200),Vector3.ZERO,1).is_empty(),"outside world has no fabricated path")
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.hunter.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var prepared_count: int = world.navigation.cache.size()
	check(world.navigation.cache.has(0.5),"player clearance is prepared before gameplay")
	for monster in get_nodes_in_group("monsters"):
		var clearance := ceilf(float(monster.data.size)*0.54*2)/2
		check(world.navigation.cache.has(clearance),"species clearance is prepared before first pursuit: "+str(monster.data.id))
	for clearing in Terrain.CLEARINGS:
		var route: PackedVector3Array = world.navigation.path(Vector3(0,0,8),Vector3(clearing.x,0,clearing.y),1.5)
		check(not route.is_empty(),"large creature route between clearing and central path")
		var safe := true
		for p in route:
			for obstacle in world.navigation.obstacles:
				if obstacle.grow(1.5).has_point(Vector2(p.x,p.z)): safe = false
		check(safe,"forest route avoids trunks and rocks")
	check(world.navigation.cache.size()==prepared_count,"ordinary forest routes do not create a late clearance grid")
	print("NAVIGATION_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
