extends "res://tools/benchmark_forest_hunt.gd"
## Targeted native coverage, not a normal-spawn expedition or difficulty test.
var prepared := false
var cloud: Node3D
var initial_health := 0.0
var entered := false
var escaped := false
var escape_health := 0.0
var safe_seconds := 0.0
var safe_run := 0.0
var releases := 0
var observed := {}
var capture_requested := false

func setup() -> void:
	await super.setup()
	for candidate in get_nodes_in_group("monsters"):
		if candidate.data.id=="mistfrill": monster = candidate
	# Only the initial placement is privileged. AI, damage and movement stay live.
	fighter.global_position = monster.global_position-monster.global_basis.z*3.2
	fighter.global_position.y = preload("res://scripts/forest_terrain.gd").height_at(fighter.position.x,fighter.position.z)+0.15
	fighter.velocity = Vector3.ZERO
	fighter.lock_target = monster
	fighter.set_process_input(false)
	initial_health = fighter.combat.health
	sample_limit = 18.0
	prepared = true

func control() -> void:
	if not prepared or finished: return
	var start := Time.get_ticks_usec()
	elapsed += 1.0/60
	for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
	for hazard in get_nodes_in_group("hazards"):
		if hazard.kind!="mist": continue
		var id: int = hazard.get_instance_id()
		if not observed.has(id):
			observed[id] = true
			releases += 1
		if not is_instance_valid(cloud): cloud = hazard
	if is_instance_valid(cloud):
		entered = entered or cloud.contains_target()
		if not capture_requested and "--capture-mist" in OS.get_cmdline_user_args():
			capture_requested = true
			capture_cloud.call_deferred()
		if fighter.combat.health<initial_health or escaped:
			var away: Vector3 = fighter.global_position-cloud.global_position
			away.y = 0
			if away.length()<cloud.radius+1.2:
				movement(away if away.length()>0.1 else Vector3.RIGHT,true)
			elif not escaped:
				escaped = true
				escape_health = fighter.combat.health
			if escaped and not cloud.contains_target() and fighter.combat.health==escape_health:
				safe_run += 1.0/60
				safe_seconds = maxf(safe_seconds,safe_run)
			else: safe_run = 0.0
	else: safe_run = 0.0
	controller_us += Time.get_ticks_usec()-start

func capture_cloud() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-mist-live.png"))

func finish() -> void:
	if finished: return
	var result := {"passed":releases>0 and entered and escaped and safe_seconds>=2.0 and fighter.combat.health>0,"releases":releases,"entered_live_cloud":entered,"initial_health":initial_health,"health_after_escape":escape_health,"final_health":fighter.combat.health,"safe_seconds_while_cloud_live":safe_seconds,"escaped":escaped,"scope":"native live AI mist release; privileged initial placement, normal damage and sprint withdrawal; all five AI remain active; no attacks or resource resets; not full-map or human acceptance"}
	var steady_stats := stats(steady)
	result["frame_budget_met"] = not steady_stats.is_empty() and steady_stats.p99_ms<=16.67 and steady_stats.over_33ms==0
	result["passed"] = result.passed and result.frame_budget_met
	FileAccess.open("res://../verification/mist-release-"+str(OS.get_process_id())+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("MIST_RELEASE: ",JSON.stringify(result))
	await super.finish()
	if not result.passed: quit(1)
