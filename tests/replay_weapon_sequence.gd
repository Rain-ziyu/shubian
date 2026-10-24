extends "res://tests/replay_encounter.gd"
## Uses normal requests and mapped movement against a live monster. State-aware, not a human playtest.
var stage := 0
var guard_count := 0
var hit_counts := {}
var events: Array[Dictionary] = []
var consumptions := {}
var counter_shadows := -1
var finisher_shadows := -1
var observed_action := "idle"
var previous_shadows := 0
var spin_beats := 0
var reply_push_seen := false
var reply_start := Vector3.ZERO
var reply_push_until := -1.0

func setup() -> void:
	await super.setup()
	fighter.combat.action_changed.connect(record_action)
	fighter.hit_confirmed.connect(record_hit)
	fighter.combat.strike.connect(func(_beat: int):
		if fighter.combat.action=="spin": spin_beats += 1
	)

func record_action(action: String) -> void:
	var shadows: int = fighter.combat.shadow_lifetimes.size()
	events.append({"time":snappedf(elapsed,0.001),"action":action,"shadows":shadows,"health":fighter.combat.health})
	if action in ["fourfold","spin"]: consumptions[action] = previous_shadows-shadows
	if action=="fourfold": stage = 1
	if action=="spin": stage = 2
	if action=="counter_window": counter_shadows = shadows
	if action=="finisher":
		finisher_shadows = shadows
		stage = 3

func record_hit(action: String, beat: int, _target: Node3D, result: Dictionary) -> void:
	hit_counts[action] = int(hit_counts.get(action,0))+1
	events.append({"time":snappedf(elapsed,0.001),"contact":action,"beat":beat,"part":result.part,"damage":result.damage,"shadows":fighter.combat.shadow_lifetimes.size()})
	if action=="reply":
		reply_start = monster.global_position
		reply_push_until = elapsed+0.25

func control() -> void:
	if result_saved: return
	elapsed += 1.0/60.0
	var c = fighter.combat
	if reply_push_until>elapsed and monster.global_position.distance_to(reply_start)>0.15: reply_push_seen = true
	if c.health<=0 or monster.health<=0 or elapsed>=90 or (stage==3 and c.action=="idle"):
		set_movement(Vector3.ZERO)
		finish_sequence()
		return
	var away: Vector3 = fighter.global_position-monster.global_position
	away.y = 0
	var movement := -away.normalized() if away.length()>1.75 else Vector3.ZERO
	var local := movement.rotated(Vector3.UP,-fighter.yaw)
	set_movement(local)
	previous_shadows = c.shadow_lifetimes.size()
	if c.action=="wait":
		if monster.phase=="windup" and monster.clock>float(monster.data.windup)-0.22: request_action("counter_window")
		return
	if c.action in ["hurt","dodge","plant","counter_window","finisher","fourfold","spin"]: return
	if stage==2 and not c.shadow_lifetimes.is_empty():
		request_action("plant")
		return
	if not c.shadow_lifetimes.is_empty():
		request_action("fourfold" if stage==0 else "spin")
	elif c.guard_reward>0:
		guard_count += 1
		events.append({"time":snappedf(elapsed,0.001),"event":"guard_success","health":c.health})
		request_action("reply")
	elif c.flash_window>0:
		request_action("flash")
	elif monster.phase=="windup" and monster.clock>float(monster.data.windup)-0.32:
		request_action("guard")

func request_action(action: String) -> void:
	fighter.combat.request(action)

func set_movement(local: Vector3) -> void:
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	if local.x>0.1: Input.action_press("move_right")
	if local.x< -0.1: Input.action_press("move_left")
	if local.z>0.1: Input.action_press("move_back")
	if local.z< -0.1: Input.action_press("move_forward")

func sequence_checks() -> Dictionary:
	return {
		"natural_guard_chain":guard_count>=3,
		"reply_contacts":int(hit_counts.get("reply",0))>=3,
		"flash_contacts":int(hit_counts.get("flash",0))>=3,
		"fourfold_four_contacts":int(hit_counts.get("fourfold",0))==4,
		"spin_two_hit_beats":spin_beats==2,
		"spin_contacts":int(hit_counts.get("spin",0))>=1,
		"reply_physically_pushes_target":reply_push_seen,
		"combo_resource_costs":consumptions.get("fourfold",0)==1 and consumptions.get("spin",0)==1,
		"counter_keeps_existing_shadow":counter_shadows>=1 and counter_shadows==finisher_shadows,
		"finisher_two_contacts":int(hit_counts.get("finisher",0))==2,
		"alive":fighter.combat.health>0
	}

func finish_sequence() -> void:
	result_saved = true
	var checks := sequence_checks()
	var passed := true
	for value in checks.values(): passed = passed and value
	var result := {"passed":passed,"checks":checks,"seconds":snappedf(elapsed,0.01),"player_health":fighter.combat.health,"monster_health":monster.health,"contacts":hit_counts,"events":events,"scope":"live single monster; privileged state-aware controller; no injected health shadows or hit confirmations; not difficulty acceptance"}
	var file := FileAccess.open("res://../Shubian-weapon-sequence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("WEAPON_SEQUENCE: ",JSON.stringify({"passed":passed,"checks":checks,"seconds":result.seconds,"contacts":hit_counts,"health":fighter.combat.health}))
	quit(0 if passed else 1)
