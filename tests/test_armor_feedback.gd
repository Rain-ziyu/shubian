extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: CharacterBody3D = world.hunter
	player.set_physics_process(false)
	player.set_process(false)
	var monster: CharacterBody3D
	for actor in get_nodes_in_group("monsters"):
		actor.set_physics_process(false)
		actor.set_process(false)
		if actor.data.id=="mossback": monster = actor
	var origin := monster.global_position-monster.global_basis.z*4
	var before: float = monster.health
	var reduced: Dictionary = monster.receive_strike(10,origin,"light","body")
	check(reduced.armor_reduced and not reduced.weak and not reduced.armor_just_broken,"Front armor contact is distinct from weakness and armor break")
	check(is_equal_approx(before-monster.health,10*float(monster.data.front_armor)),"Armor feedback reports the actual reduced health loss")
	player.show_hit_feedback(monster.global_position+Vector3.UP,reduced,"light")
	var effects := get_nodes_in_group("hit_feedback")
	check(effects.size()==1 and effects[0].number.text.begins_with("重甲"),"Reduced contact has a readable armor label")
	check("重甲减伤" in player.message,"HUD explains the reduced damage")
	var weak: Dictionary = monster.receive_strike(10,origin,"light","tail")
	check(weak.weak and not weak.armor_reduced and not weak.armor_just_broken,"Actual weak point still bypasses armor and retains its own feedback")
	var broken: Dictionary = monster.receive_strike(200,origin,"heavy","body")
	check(broken.armor_just_broken and broken.armor_broken,"First actual armor break emits its transition")
	check(not monster.mesh.get_node("ArmorPlate0").visible,"Break feedback agrees with the removed armor model")
	player.show_hit_feedback(monster.global_position+Vector3.UP,broken,"heavy")
	effects = get_nodes_in_group("hit_feedback")
	check(effects.size()==2 and effects[1].number.text.begins_with("破甲"),"Breaking contact has a distinct damage label")
	check("破甲成功" in player.feedback.text,"Actual armor break produces the central combat cue")
	before = monster.health
	var after: Dictionary = monster.receive_strike(10,origin,"light","body")
	check(not after.armor_reduced and not after.armor_just_broken and after.armor_broken,"Later contacts do not repeat the break event")
	check(is_equal_approx(before-monster.health,10),"Later front contact has the promised unreduced damage")
	var clock: float = player.combat.elapsed
	var health: float = monster.health
	for effect in effects:
		effect.set_process(false)
		effect.advance_visual(0.1)
	check(player.combat.elapsed==clock and monster.health==health,"Armor presentation cannot change health or combat time")
	print("ARMOR_FEEDBACK_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
