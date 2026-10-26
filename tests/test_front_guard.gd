extends "res://tests/replay_input_sequence.gd"
## Front-start live-AI/input fixture. Placement and aim are calibrated, resources are not injected.
var checks := 0
var failures := 0
var guard_events := 0
var front_dot := 0.0
var expect_contact := true
var initial_distance := 0.0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func setup() -> void:
	# This fixture uses Q/Ctrl only. Incidental desktop mouse clicks must not
	# start an extra attack or change its calibrated aim.
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var blocker := Control.new()
	overlay.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	await super.setup()
	var distance := 2.8 if "--near" in OS.get_cmdline_user_args() else 3.6
	initial_distance = distance
	fighter.global_position = monster.global_position-monster.global_basis.z*distance
	fighter.yaw = PI
	fighter.rig.root.rotation.y = PI
	fighter.pitch = 0.25 if "--raised" in OS.get_cmdline_user_args() else -0.25
	front_dot = (-monster.global_basis.z).dot((fighter.global_position-monster.global_position).normalized())
func control() -> void:
	if result_saved: return
	elapsed += 1.0/60
	var c = fighter.combat
	if not c.shadow_lifetimes.is_empty() or c.health<=0 or elapsed>=8:
		finish_front()
		return
	set_movement(Vector3.ZERO)
	if c.action in ["reply","hurt"]: return
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
	check(flashes==0 and not hit_counts.has("light") and mouse_events==0,"new guard chain uses Q/Ctrl without extra mouse attacks")
	check(fighter.combat.shadow_lifetimes.size()==1 if expect_contact else fighter.combat.shadow_lifetimes.is_empty(),"shadow is earned only from the actual counter sweep contact")
	check(int(input_commands.get("reply",0))==1 if expect_contact else int(input_commands.get("reply",0))>=1,"single Ctrl press starts each earned counter sweep")
	check(fighter.combat.health>0,"guard chain preserves a living player")
	print("FRONT_GUARD_RESULT: ",JSON.stringify({"expected_contact":expect_contact,"start_distance":initial_distance,"aim_pitch":fighter.pitch,"guards":guard_events,"contacts":hit_counts,"shadows":fighter.combat.shadow_lifetimes.size(),"counter_presses":counter_presses,"health":fighter.combat.health,"seconds":elapsed,"scope":"stationary front-start live single AI, mapped engine events, no injected health resources or hit confirmations; not physical Windows input or human acceptance"}))
	print("FRONT_GUARD_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
