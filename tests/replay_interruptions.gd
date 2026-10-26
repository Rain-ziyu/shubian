extends "res://tests/replay_encounter.gd"
## Earns shadows naturally, then deliberately takes live attacks during each special.
var stage := 0
var last_health := 240.0
var fourfold_interrupted := false
var spin_held := false
var fourfold_contacts := 0
var spend_checks: Array[bool] = []
var events: Array[Dictionary] = []

func setup() -> void:
	await super.setup()
	fighter.hit_confirmed.connect(func(action: String, _beat: int, _target: Node3D, _result: Dictionary):
		if action=="fourfold": fourfold_contacts += 1
	)

func control() -> void:
	if result_saved: return
	elapsed += 1.0/60.0
	var c = fighter.combat
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	if c.health<last_health:
		events.append({"time":snappedf(elapsed,0.001),"stage":stage,"action_on_damage":c.action,"damage":last_health-c.health})
		if stage==2:
			fourfold_interrupted = c.action=="hurt"
			stage = 3
		elif stage==5:
			spin_held = c.action=="spin"
			stage = 6
	last_health = c.health
	if c.health<=0 or monster.health<=0 or elapsed>=90 or (stage==6 and c.action=="idle"):
		finish_interruptions()
		return
	var away: Vector3 = fighter.global_position-monster.global_position
	away.y = 0
	var local := (-away.normalized() if away.length()>1.75 else Vector3.ZERO).rotated(Vector3.UP,-fighter.yaw)
	if local.x>0.1: Input.action_press("move_right")
	if local.x< -0.1: Input.action_press("move_left")
	if local.z>0.1: Input.action_press("move_back")
	if local.z< -0.1: Input.action_press("move_forward")
	if stage in [2,5,6]: return
	if stage in [0,3] and not c.shadow_lifetimes.is_empty():
		stage += 1
	if stage in [1,4]:
		# Fourfold may start in windup because it cannot stop the attack.
		# Spin must start later: otherwise its launch prevents any incoming hit,
		# and the harness accidentally measures the next attack after spin ends.
		var exposed: bool = monster.phase=="windup" and monster.clock>float(monster.data.windup)-0.25 if stage==1 else monster.phase=="active" and monster.clock>=0.20
		if c.action=="idle" and exposed:
			var before: int = c.shadow_lifetimes.size()
			if c.request("fourfold" if stage==1 else "spin"):
				spend_checks.append(before-c.shadow_lifetimes.size()==1)
				stage += 1
		return
	if c.action in ["hurt","flash"]: return
	if c.guard_reward>0: c.request("reply")
	elif c.flash_window>0: c.request("flash")
	elif monster.phase=="windup" and monster.clock>float(monster.data.windup)-0.32: c.request("guard")

func finish_interruptions() -> void:
	result_saved = true
	var checks := {"fourfold_interrupted_by_live_attack":fourfold_interrupted,"fourfold_landed_before_interruption":fourfold_contacts>=1 and fourfold_contacts<4,"spin_takes_damage_without_interrupt":spin_held,"both_spend_one_naturally_earned_shadow":spend_checks.size()==2 and not spend_checks.has(false),"alive":fighter.combat.health>0}
	var passed := true
	for value in checks.values(): passed = passed and value
	var result := {"passed":passed,"checks":checks,"seconds":snappedf(elapsed,0.01),"player_health":fighter.combat.health,"events":events,"scope":"live single monster; state-aware deliberate exposure; no injected damage health shadows or hit confirmations"}
	var file := FileAccess.open("res://../Shubian-interruptions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("INTERRUPTION_REPLAY: ",JSON.stringify(result))
	quit(0 if passed else 1)
