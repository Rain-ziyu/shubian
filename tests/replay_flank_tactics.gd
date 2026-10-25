extends "res://tests/replay_encounter.gd"
## State-aware test controller: mapped movement, no health/damage/resource injection.
func _init() -> void: controller_name = "flank_tactics"
func setup() -> void:
	await super.setup()
	if "--trace" in OS.get_cmdline_user_args():
		fighter.hit_confirmed.connect(func(action: String, _beat: int, victim: Node3D, result: Dictionary):
			if victim!=monster: return
			var tip: Vector3 = fighter.weapon_contact_points(action,0)[0]
			print("FLANK_CONTACT: ",JSON.stringify({"time":snappedf(elapsed,0.01),"action":action,"part":result.part,"weak":result.weak,"phase":monster.phase,"phase_time":monster.clock,"exposed":monster.exposed,"pitch":fighter.pitch,"tip_local":str(monster.mesh.to_local(tip)),"marker_local":str(monster.mesh.to_local(monster.weak_marker.global_position))}))
		)
func control() -> void:
	if result_saved: return
	var c = fighter.combat
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	if c.health<=0 or monster.health<=0 or elapsed>=120:
		super.control()
		return
	elapsed += 1.0/60
	if "--aim-flank" in OS.get_cmdline_user_args():
		# Lift the ordinary look input from the low ready angle toward the torso.
		fighter.apply_look(Vector2(0,fighter.pitch/0.0025))
	var away := fighter.global_position-monster.global_position
	away.y = 0
	var desired: float = float(monster.data.size)*0.33+1.7
	var flank: Vector3 = monster.global_basis.x
	var goal: Vector3 = monster.global_position+flank*desired
	var movement := goal-fighter.global_position
	movement.y = 0
	if monster.phase=="windup": movement = away.normalized().cross(Vector3.UP)
	if movement.length()<0.18: movement = Vector3.ZERO
	var local := movement.normalized().rotated(Vector3.UP,-fighter.yaw)
	if local.x>0.1: Input.action_press("move_right",absf(local.x))
	if local.x< -0.1: Input.action_press("move_left",absf(local.x))
	if local.z>0.1: Input.action_press("move_back",absf(local.z))
	if local.z< -0.1: Input.action_press("move_forward",absf(local.z))
	if away.length()>3.5: Input.action_press("sprint")
	if c.action!="idle" and (c.action in ["hurt","dodge"] or c.elapsed<float(c.MOVES[c.action].chain)): return
	var next := ""
	if monster.phase=="windup" and monster.clock>float(monster.data.windup)-0.35 and away.length()<4:
		next = "guard"
	elif monster.phase=="recover" and monster.exposed>0 and away.normalized().dot(flank)>0.55 and away.length()<3.5:
		next = "light" if last_attack=="heavy" else "heavy"
	elif monster.phase=="idle" and not c.drawn and away.length()<3.5: next = "light"
	if next!="" and c.request(next):
		decisions += 1
		if next in ["light","heavy"]: last_attack = next
