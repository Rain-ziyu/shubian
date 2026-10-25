extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ProjectSettings.get_setting("application/config/name")=="戍边","pack project settings loaded")
	check(not DirAccess.dir_exists_absolute("res://assets/concepts"),"concept references excluded")
	check(not DirAccess.dir_exists_absolute("res://tests") and not DirAccess.dir_exists_absolute("res://tools"),"test and build tools excluded")
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	check(database.species.size()==5,"pack includes monster database")
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var monsters := get_nodes_in_group("monsters")
	check(monsters.size()==5,"packed world instantiates five species")
	var fighter = world.hunter
	check(world.has_node("InputDiagnostics")==("--input-trace" in OS.get_cmdline_user_args()),"packed input recorder is opt-in")
	check(ResourceLoader.exists("res://scripts/input_diagnostics.gd"),"packed input diagnostic script is available")
	var start: Vector3 = fighter.global_position
	Input.action_press("move_forward")
	for frame in 15: await physics_frame
	Input.action_release("move_forward")
	check(fighter.global_position.distance_to(start)>0.2,"mapped movement works in pack")
	var monster = monsters[0]
	check(monster.mesh.has_node("Tail/TailSkeleton") and monster.mesh.has_node("Hind1/LegSkeleton"),"packed creature skin loads")
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	check(saved.has_node("Skeleton3D"),"saved hunter asset loads from pack")
	saved.free()
	fighter.global_position = monster.global_position+Vector3(0,0,2.5)
	fighter.lock_target = monster
	var health: float = monster.health
	fighter.request_action("light")
	for frame in 40: await physics_frame
	check(fighter.combat.drawn and monster.health<health,"packed weapon action causes actual contact damage")
	var cue = fighter.get_node("OcclusionVisibility")
	check(cue.parts.size()>0 and cue.material.shader!=null,"packed hunter occlusion shader and skin overlay load")
	fighter.set_physics_process(false)
	for creature in monsters: creature.set_physics_process(false)
	fighter.global_position = Vector3(0,0.05,-10)
	await physics_frame
	await physics_frame
	fighter.finish_throw(Vector3(0,0,-13))
	var effects := get_nodes_in_group("teleport_feedback")
	check(effects.size()==1 and fighter.global_position.z< -10,"packed safe arrival creates endpoint feedback")
	for frame in 30: await physics_frame
	check(get_nodes_in_group("teleport_feedback").is_empty(),"packed teleport feedback cleans up")
	print("PACKED_PREVIEW_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
