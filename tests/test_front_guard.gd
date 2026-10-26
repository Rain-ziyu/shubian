extends "res://tests/replay_input_sequence.gd"
## Front-start live-AI/input fixture. Placement and aim are calibrated, resources are not injected.
var checks := 0
var failures := 0
var guard_events := 0
var front_dot := 0.0
var expect_contact := true
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func setup() -> void:
	await super.setup()
	expect_contact = "--far" not in OS.get_cmdline_user_args()
	var distance := 2.8 if expect_contact else 3.6
	fighter.global_position = monster.global_position-monster.global_basis.z*distance
	fighter.yaw = PI
	fighter.rig.root.rotation.y = PI
	fighter.pitch = 0.25
	front_dot = (-monster.global_basis.z).dot((fighter.global_position-monster.global_position).normalized())
	single_flash = true
func control() -> void:
	if result_saved: return
	elapsed += 1.0/60
	var c = fighter.combat
	if not c.shadow_lifetimes.is_empty() or c.health<=0 or elapsed>=8:
		finish_front()
		return
	set_movement(Vector3.ZERO)
	if c.action=="reply" and c.elapsed>=0.08 and not flash_sent: request_action("flash")
	if c.action in ["reply","flash","hurt"]: return
	if c.guard_reward>0:
		guard_events += 1
		request_action("reply")
	elif c.action=="idle" and monster.phase=="windup" and monster.clock>float(monster.data.windup)-0.32:
		request_action("guard")
func finish_front() -> void:
	result_saved = true
	check(front_dot>0.95,"encounter starts in front of the monster")
	check(guard_events>=1,"normal frontal attack is actually guarded")
	var replies: int = hit_counts.get("reply",0)
	var flashes: int = hit_counts.get("flash",0)
	check(replies==1 if expect_contact else replies==0,"physical reply contact matches this calibrated distance")
	check(flashes==1 if expect_contact else flashes==0,"only confirmed reply can lead to a physical flash hit")
	check(fighter.combat.shadow_lifetimes.size()==1 if expect_contact else fighter.combat.shadow_lifetimes.is_empty(),"shadow is earned only from the real flash contact")
	check(flash_presses==1 if expect_contact else flash_presses>=1,"early flash input is sent once per reply")
	check(fighter.combat.health>0,"guard chain preserves a living player")
	print("FRONT_GUARD_RESULT: ",JSON.stringify({"expected_contact":expect_contact,"guards":guard_events,"contacts":hit_counts,"shadows":fighter.combat.shadow_lifetimes.size(),"flash_presses":flash_presses,"health":fighter.combat.health,"seconds":elapsed,"scope":"stationary front-start live single AI, mapped engine events, no injected health resources or hit confirmations; not physical Windows input or human acceptance"}))
	print("FRONT_GUARD_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
