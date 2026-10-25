extends "res://tests/replay_encounter.gd"
## Privileged state-aware tactics, ordinary movement and mouse/action inputs; no damage injection.
var contacts := 0
var weak_contacts := 0
var interruptions := 0
var events: Array[Dictionary] = []
var frame := 0
func _init() -> void: controller_name = "weakpoint_tactics"
func setup() -> void:
	await super.setup()
	fighter.hit_confirmed.connect(on_contact)
	if monster.data.pattern=="mist": fighter.lock_target = null
func on_contact(action: String, beat: int, _target: Node3D, result: Dictionary) -> void:
	contacts += 1
	if result.weak: weak_contacts += 1
	if result.weak and monster.phase=="windup" and monster.stagger>0: interruptions += 1
	events.append({"time":snappedf(elapsed,0.01),"action":action,"beat":beat,"part":result.part,"weak":result.weak,"damage":result.damage,"phase":monster.phase,"stagger":monster.stagger})
func control() -> void:
	if result_saved: return
	elapsed += 1.0/60.0
	frame += 1
	var c = fighter.combat
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	if c.health<=0 or monster.health<=0 or elapsed>=120:
		finish_tactics()
		return
	# Headless display cannot capture the mouse; use the same logical look handler.
	var look_x := 0.0
	if monster.data.pattern=="mist":
		var head_offset: Vector3 = monster.Parts.volumes(monster)[0].center-fighter.global_position
		var aim_yaw := atan2(-head_offset.x,-head_offset.z)
		look_x = -wrapf(aim_yaw-fighter.yaw,-PI,PI)/0.003
	fighter.apply_look(Vector2(look_x,-(0.65-fighter.pitch)/0.0025))
	var away: Vector3 = fighter.global_position-monster.global_position
	away.y = 0
	var radial := away.normalized()
	if "--trace" in OS.get_cmdline_user_args() and frame%60==0:
		var head: Vector3 = monster.Parts.volumes(monster)[0].center
		var tip: Vector3 = fighter.weapon_contact_points(c.action,0)[0]
		events.append({"t":snappedf(elapsed,0.01),"range":away.length(),"action":c.action,"phase":monster.phase,"pitch":fighter.pitch,"tip_to_head":tip.distance_to(head)})
	var desired := 3.1
	var movement := -radial if away.length()>desired+0.1 else (radial if away.length()<desired-0.1 else Vector3.ZERO)
	if monster.data.pattern=="pulse":
		var rear: Vector3 = monster.global_basis.z
		var goal: Vector3 = monster.global_position+rear*desired
		var offset: Vector3 = goal-fighter.global_position
		offset.y = 0
		movement = offset.normalized() if offset.length()>0.2 else Vector3.ZERO
		if radial.dot(rear)<0.3: movement = radial.cross(Vector3.UP)+movement*0.3
	var danger := false
	for hazard in get_nodes_in_group("hazards"):
		var offset: Vector3 = fighter.global_position-hazard.global_position
		offset.y = 0
		if offset.length()<hazard.radius+0.6:
			danger = true
			movement = offset.normalized()*0.25+offset.normalized().cross(Vector3.UP)
	if monster.data.pattern=="mist" and monster.phase=="windup" and monster.clock>float(monster.data.windup)*0.78:
		var warned: Vector3 = fighter.global_position-monster.target_point
		warned.y = 0
		if warned.length()<4.6:
			danger = true
			movement = radial*0.2+radial.cross(Vector3.UP)
	var local := movement.normalized().rotated(Vector3.UP,-fighter.yaw)
	if local.x>0.1: Input.action_press("move_right")
	if local.x< -0.1: Input.action_press("move_left")
	if local.z>0.1: Input.action_press("move_back")
	if local.z< -0.1: Input.action_press("move_forward")
	if danger:
		Input.action_press("sprint")
		if c.action=="idle" and c.request("dodge"): decisions += 1
		return
	if away.length()>3.6: return
	if c.action!="idle" and (c.action in ["hurt","dodge"] or c.elapsed<float(c.MOVES[c.action].chain)): return
	if monster.phase in ["idle","recover","windup"]:
		var next := "light" if last_attack=="heavy" else "heavy"
		if c.request(next):
			last_attack = next
			decisions += 1
func finish_tactics() -> void:
	result_saved = true
	var result := {"species":monster.data.id,"controller":controller_name,"outcome":"victory" if monster.health<=0 else ("defeat" if fighter.combat.health<=0 else "timeout"),"seconds":snappedf(elapsed,0.01),"player_health":fighter.combat.health,"monster_health":monster.health,"contacts":contacts,"weak_contacts":weak_contacts,"interruptions":interruptions,"events":events,"scope":"single live monster; privileged state-aware input controller; no injected health damage shadows or hit confirmations; not human difficulty acceptance"}
	var passed: bool = monster.health<=0 and weak_contacts>0 and interruptions>0
	result["passed"] = passed
	var file := FileAccess.open("res://../Shubian-weakpoints-"+str(monster.data.id)+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	result.erase("events")
	print("WEAKPOINT_REPLAY: ",JSON.stringify(result))
	await create_timer(0.25).timeout
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
