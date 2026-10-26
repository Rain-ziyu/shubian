extends SceneTree
const Terrain = preload("res://scripts/forest_terrain.gd")
const Hazard = preload("res://scripts/hazard.gd")
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
	world.hunter.set_physics_process(false)
	for m in get_nodes_in_group("monsters"):
		m.set_physics_process(false)
		if m.data.pattern not in ["pulse","mist"]: continue
		var center := Vector3(38,Terrain.mesh_height_at(38,12),12)
		var radius: float = 4.0 if m.data.pattern=="mist" else m.data.reach
		m.update_area_warning(center,radius)
		var mesh: ArrayMesh = m.tell.mesh
		var maximum := 0.0
		var error := 0.0
		for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = m.tell.to_global(vertex)
			maximum = maxf(maximum,Vector2(point.x-center.x,point.z-center.z).length())
			error = maxf(error,absf(point.y-Terrain.effect_height_at(point.x,point.z)-0.06))
		check(absf(maximum-radius)<0.001,str(m.data.id)+" circular warning matches damage radius")
		check(error<0.001,str(m.data.id)+" warning follows terrain and water height")
		m.rotation.y += 0.7
		m.update_area_warning(center,radius)
		check(m.tell.mesh==mesh and m.tell.global_basis.is_equal_approx(Basis.IDENTITY),"stationary warning caches geometry without rotating its ground fit")
		var hazard := Hazard.new()
		hazard.kind = m.data.pattern
		hazard.radius = radius
		hazard.target = world.hunter
		world.add_child(hazard)
		hazard.set_physics_process(false)
		hazard.global_position = center
		hazard.conform_ground()
		check(hazard.surface.mesh is ArrayMesh and hazard.boundary.mesh is ArrayMesh,"active area has a terrain-fitted disc and boundary")
		var active_vertices: PackedVector3Array = hazard.surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var warning_vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var difference := 0.0
		for i in mini(active_vertices.size(),warning_vertices.size()):
			difference = maxf(difference,active_vertices[i].distance_to(warning_vertices[i]))
		check(active_vertices.size()==warning_vertices.size() and difference<0.0001,"warning and active fill match within world-transform precision")
		world.hunter.global_position = center+Vector3(radius*0.8,0,radius*0.8)
		check(not hazard.contains_target(),"former square corner outside circle is safe")
		m.update_area_warning(center,radius)
		var prepared: ArrayMesh = m.tell.mesh
		var prepared_transform: Transform3D = m.tell.global_transform
		m.spawn_hazard(center,radius,1.0,9.0,m.data.pattern)
		var reused = get_nodes_in_group("hazards").back()
		reused.set_physics_process(false)
		reused.conform_ground()
		check(reused.surface.mesh==prepared,"active area reuses the exact prepared warning geometry")
		var anchor: Vector3 = prepared.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
		m.update_area_warning(center+Vector3(2,0,0),radius)
		check(reused.surface.to_global(anchor).distance_to(prepared_transform*anchor)<0.0001,"new warning cannot move the active area's retained world-space geometry")
		m.update_area_warning(center,radius)
		m.update_area_warning(center,radius+0.5)
		check(absf(m.tell.mesh.get_aabb().size.x-2*(radius+0.5))<0.001,"warning cache refreshes when only the radius changes")
		m.spawn_hazard(center,radius,1.0,9.0,m.data.pattern)
		var fallback = get_nodes_in_group("hazards").back()
		fallback.set_physics_process(false)
		fallback.conform_ground()
		check(fallback.surface.mesh!=m.tell.mesh and absf(fallback.surface.mesh.get_aabb().size.x-2*radius)<0.001,"mismatched prepared radius falls back to the correct active disc")

	print("AREA_WARNING_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
