extends RefCounted
const Terrain = preload("res://scripts/forest_terrain.gd")
const CELL := 2.0
var obstacles: Array[Rect2] = []
var cache := {}
# Enabled only by the diagnostic benchmark; normal gameplay keeps no samples.
var profile_paths := false
var path_events: Array[Dictionary] = []

func add_obstacle(position: Vector3, size: Vector3) -> void:
	obstacles.append(Rect2(Vector2(position.x-size.x/2,position.z-size.z/2),Vector2(size.x,size.z)))
	cache.clear()

func grid_for(radius: float) -> AStarGrid2D:
	var clearance := ceilf(radius*2)/2
	if cache.has(clearance): return cache[clearance]
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-29,-29,59,59)
	grid.cell_size = Vector2.ONE*CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(-29,30):
		for x in range(-29,30):
			var point := Vector2(x*CELL,z*CELL)
			var solid := absf(point.x)>59-clearance or absf(point.y)>59-clearance
			for obstacle in obstacles:
				if obstacle.grow(clearance+1).has_point(point):
					solid = true
					break
			var slope := Vector2(Terrain.height_at(point.x+0.5,point.y)-Terrain.height_at(point.x-0.5,point.y),Terrain.height_at(point.x,point.y+0.5)-Terrain.height_at(point.x,point.y-0.5)).length()
			if slope>0.85: solid = true
			grid.set_point_solid(Vector2i(x,z),solid)
	cache[clearance] = grid
	return grid

func nearest_free(grid: AStarGrid2D, point: Vector3) -> Vector2i:
	var center := Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
	var best := Vector2i(9999,9999)
	var distance := INF
	for z in range(-4,5):
		for x in range(-4,5):
			var cell := center+Vector2i(x,z)
			if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
				var d := Vector2(cell.x*CELL-point.x,cell.y*CELL-point.z).length_squared()
				if d<distance:
					distance = d
					best = cell
	return best

func path(start: Vector3, destination: Vector3, radius: float) -> PackedVector3Array:
	var began := Time.get_ticks_usec() if profile_paths else 0
	var cached := cache.has(ceilf(radius*2)/2) if profile_paths else false
	var grid := grid_for(radius)
	var grid_done := Time.get_ticks_usec() if profile_paths else 0
	var from := nearest_free(grid,start)
	var to := nearest_free(grid,destination)
	var endpoints_done := Time.get_ticks_usec() if profile_paths else 0
	var result := PackedVector3Array()
	if from.x==9999 or to.x==9999: return result
	var cells := grid.get_id_path(from,to)
	var search_done := Time.get_ticks_usec() if profile_paths else 0
	for cell in cells:
		result.append(Vector3(cell.x*CELL,Terrain.height_at(cell.x*CELL,cell.y*CELL),cell.y*CELL))
	if profile_paths:
		var done := Time.get_ticks_usec()
		if done-began>=2000:
			path_events.append({"at_us":done,"total_ms":(done-began)/1000.0,"grid_ms":(grid_done-began)/1000.0,"endpoints_ms":(endpoints_done-grid_done)/1000.0,"search_ms":(search_done-endpoints_done)/1000.0,"waypoints_ms":(done-search_done)/1000.0,"cached_grid":cached,"radius":radius,"points":result.size()})
			if path_events.size()>64: path_events.pop_front()
	return result
