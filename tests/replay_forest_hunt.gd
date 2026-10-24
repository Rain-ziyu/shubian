extends SceneTree
## Continuous expedition from the normal spawn; all five AI remain active.
## Privileged tactics controller, not human difficulty acceptance.
var world: Node3D
var fighter: CharacterBody3D
var monster: CharacterBody3D
var elapsed := 0.0
var route := PackedVector3Array()
var route_clock := 0.0
var last_attack := "heavy"
var finished := false
var contacts := {}
var weak_contacts := {}
var encounters: Array[Dictionary] = []
var distance_walked := 0.0
var previous := Vector3.ZERO
var previous_health := 240.0
var damage_events: Array[Dictionary] = []
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	if "--capture-victory" in OS.get_cmdline_user_args():
		if DisplayServer.get_name()=="headless":
			printerr("Victory capture requires native rendering")
			quit(2)
			return
		root.size = Vector2i(1280,720)
		root.content_scale_size = root.size
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	fighter = world.hunter
	previous = fighter.position
	fighter.hit_confirmed.connect(func(_action: String, _beat: int, victim: Node3D, result: Dictionary):
		var id: String = victim.data.id
		contacts[id] = int(contacts.get(id,0))+1
		if result.weak: weak_contacts[id] = int(weak_contacts.get(id,0))+1
	)
	physics_frame.connect(control)
func movement(direction: Vector3, sprint := false) -> void:
	var local := direction.normalized().rotated(Vector3.UP,-fighter.yaw)
	if local.x>0.1: Input.action_press("move_right",local.x)
	if local.x< -0.1: Input.action_press("move_left",-local.x)
	if local.z>0.1: Input.action_press("move_back",local.z)
	if local.z< -0.1: Input.action_press("move_forward",-local.z)
	if sprint: Input.action_press("sprint")
func control() -> void:
	if finished: return
	elapsed += 1.0/60
	var travelled := fighter.position-previous
	travelled.y = 0
	distance_walked += travelled.length()
	previous = fighter.position
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	var c = fighter.combat
	if c.health<previous_health:
		var enemies: Array[Dictionary] = []
		for candidate in get_nodes_in_group("monsters"):
			if candidate.health>0 and fighter.position.distance_to(candidate.position)<22:
				enemies.append({"species":candidate.data.id,"phase":candidate.phase,"clock":candidate.clock,"range":fighter.position.distance_to(candidate.position)})
		var event := {"time":snappedf(elapsed,0.01),"health":c.health,"action":c.action,"position":fighter.position,"enemies":enemies}
		damage_events.append(event)
		print("FOREST_HUNT_DAMAGE: ",JSON.stringify(event))
	previous_health = c.health
	if c.health<=0 or elapsed>600:
		finish()
		return
	if is_instance_valid(monster) and monster.health<=0:
		encounters.append({"species":monster.data.id,"time":snappedf(elapsed,0.01),"player_health":c.health})
		monster = null
	if not is_instance_valid(monster):
		var nearest := INF
		for candidate in get_nodes_in_group("monsters"):
			if candidate.health<=0: continue
			var distance: float = fighter.position.distance_to(candidate.position)
			if distance<nearest:
				nearest = distance
				monster = candidate
		if not is_instance_valid(monster):
			finish()
			return
		route_clock = 0
		fighter.lock_target = monster
		print("FOREST_HUNT_TARGET: ",monster.data.id," time=",elapsed," health=",c.health)
	var away := fighter.position-monster.position
	away.y = 0
	if away.length()>10:
		route_clock -= 1.0/60
		if route_clock<=0:
			route = world.navigation.path(fighter.position,monster.position,0.5)
			route_clock = 0.6
		while not route.is_empty() and Vector2(route[0].x-fighter.position.x,route[0].z-fighter.position.z).length()<0.65: route.remove_at(0)
		if not route.is_empty(): movement(route[0]-fighter.position,true)
		return
	var pattern: String = monster.data.pattern
	var radial := away.normalized()
	var move := Vector3.ZERO
	var next := ""
	if pattern in ["charge","leap"]:
		var flank: Vector3 = monster.global_basis.x
		move = monster.position+flank*(float(monster.data.size)*0.33+1.7)-fighter.position
		if monster.phase=="windup": move = radial.cross(Vector3.UP)
		var windup: float = monster.data.rear_attack.windup if monster.rear_attack else monster.data.windup
		if monster.phase=="windup" and monster.clock>windup-0.16 and away.length()<6: next = "dodge"
		elif monster.phase=="recover" and monster.exposed>0 and radial.dot(flank)>0.55 and away.length()<3.5: next = "attack"
		elif monster.phase=="idle" and not c.drawn and away.length()<3.5: next = "attack"
		if c.guard_reward>0: next = "reply"
		elif c.flash_window>0: next = "flash"
		elif not c.shadow_lifetimes.is_empty() and monster.phase=="recover" and away.length()<3.5: next = "spin"
	elif pattern in ["mist","pulse"]:
		var desired := 3.1 if pattern=="mist" else 1.85
		move = -radial if away.length()>desired+0.1 else (radial if away.length()<desired-0.1 else Vector3.ZERO)
		if pattern=="mist":
			fighter.lock_target = null
			var head: Vector3 = monster.Parts.volumes(monster)[0].center-fighter.position
			var aim := atan2(-head.x,-head.z)
			fighter.apply_look(Vector2(-wrapf(aim-fighter.yaw,-PI,PI)/0.003,-(0.65-fighter.pitch)/0.0025))
		else:
			var rear: Vector3 = monster.global_basis.z
			move = monster.position+rear*desired-fighter.position
			if radial.dot(rear)<0.3: move = radial.cross(Vector3.UP)+move.normalized()*0.3
		if away.length()<3.6: next = "attack"
	else:
		move = -radial if away.length()>2.7 else Vector3.ZERO
		if c.guard_reward>0: next = "reply"
		elif c.flash_window>0: next = "flash"
		elif monster.phase=="windup" and monster.clock>0.35: next = "guard"
		elif monster.phase in ["recover","idle"]: next = "spin" if not c.shadow_lifetimes.is_empty() else "attack"
	var danger := false
	for hazard in get_nodes_in_group("hazards"):
		var offset: Vector3 = fighter.position-hazard.position
		offset.y = 0
		if offset.length()<hazard.radius+0.6:
			danger = true
			move = offset.normalized()*0.25+offset.normalized().cross(Vector3.UP)
	if pattern=="mist" and monster.phase=="windup" and monster.clock>float(monster.data.windup)*0.78:
		var warned: Vector3 = fighter.position-monster.target_point
		warned.y = 0
		if warned.length()<4.6:
			danger = true
			move = radial*0.2+radial.cross(Vector3.UP)
	move.y = 0
	if move.length()>0.18: movement(move,danger or away.length()>3.5)
	if danger:
		if c.action=="idle": c.request("dodge")
		return
	if c.action!="idle" and (c.action in ["hurt","dodge"] or c.elapsed<float(c.MOVES[c.action].chain)): return
	if next=="attack": next = "light" if last_attack=="heavy" else "heavy"
	if next!="" and c.request(next) and next in ["light","heavy"]: last_attack = next
func finish() -> void:
	finished = true
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	var passed: bool = encounters.size()==5 and fighter.combat.health>0
	var result := {"passed":passed,"seconds":snappedf(elapsed,0.01),"player_health":fighter.combat.health,"encounters":encounters,"contacts":contacts,"weak_contacts":weak_contacts,"damage_events":damage_events,"distance_walked":distance_walked,"scope":"normal spawn, continuous resources, all five AI active; privileged tactics controller; not human difficulty acceptance"}
	print("FOREST_HUNT: ",JSON.stringify(result))
	FileAccess.open("res://../Shubian-forest-hunt.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	if "--capture-victory" in OS.get_cmdline_user_args():
		world.combat_hud.update_state(fighter,encounters.size())
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://../Shubian-forest-hunt-result.png")
		var error := root.get_texture().get_image().save_png(path)
		print("FOREST_HUNT_CAPTURE: result=",error," path=",path)
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
