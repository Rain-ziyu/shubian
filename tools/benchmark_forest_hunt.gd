extends "res://tests/replay_forest_hunt.gd"
## Real-time rendered expedition; all AI active, no fixed FPS or movie recording.
var started_us := 0
var previous_us := 0
var timings: Array[float] = []
var steady: Array[float] = []
var stalls: Array[Dictionary] = []
var maximum_physics_ms := 0.0
var maximum_process_ms := 0.0
var profile_nodes := {}
var profile_previous := {}
var profile_peaks := {}
var controller_us := 0
var sample_limit := 0.0
var draw_started_us := 0
var last_draw_ms := 0.0
var recent_events: Array[Dictionary] = []
var previous_pipelines := {}
var compilation_events: Array[Dictionary] = []
func setup() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Forest benchmark requires native rendering")
		quit(2)
		return
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--fixed-fps") or argument.begins_with("--write-movie"):
			printerr("Forest benchmark requires real-time simulation without movie recording")
			quit(2)
			return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sample-seconds="):
			var value := argument.trim_prefix("--sample-seconds=")
			if not value.is_valid_float() or float(value)<=0:
				printerr("Sample seconds must be positive")
				quit(2)
				return
			sample_limit = float(value)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await super.setup()
	world.navigation.profile_paths = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.camera_manual_time = 0
	profile_nodes = {"player":fighter,"visibility":fighter.get_node("OcclusionVisibility")}
	for creature in get_nodes_in_group("monsters"): profile_nodes[str(creature.data.id)] = creature
	for node: Node in profile_nodes.values(): node.set_meta("measure_frame_cost",true)
	started_us = Time.get_ticks_usec()
	previous_us = started_us
	previous_pipelines = pipeline_counts()
	process_frame.connect(sample_frame)
	RenderingServer.frame_pre_draw.connect(begin_draw)
	RenderingServer.frame_post_draw.connect(end_draw)
	fighter.hit_confirmed.connect(record_contact)
func begin_draw() -> void: draw_started_us = Time.get_ticks_usec()
func end_draw() -> void: last_draw_ms = (Time.get_ticks_usec()-draw_started_us)/1000.0
func record_contact(action: String, beat: int, victim: Node3D, result: Dictionary) -> void:
	recent_events.append({"wall_seconds":(Time.get_ticks_usec()-started_us)/1000000.0,"simulation_seconds":elapsed,"action":action,"beat":beat,"species":victim.data.id,"part":result.part,"weak":result.weak})
	if recent_events.size()>256: recent_events.pop_front()

func control() -> void:
	var start := Time.get_ticks_usec()
	super.control()
	controller_us += Time.get_ticks_usec()-start
func pipeline_counts() -> Dictionary:
	return {"canvas":int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),"mesh":int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),"surface":int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),"draw":int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),"specialization":int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))}
func sample_frame() -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	var frame_ms := (now-previous_us)/1000.0
	previous_us = now
	var pipeline_totals := pipeline_counts()
	var pipeline_delta := {}
	var compiled := false
	for key in pipeline_totals:
		pipeline_delta[key] = int(pipeline_totals[key])-int(previous_pipelines.get(key,0))
		compiled = compiled or int(pipeline_delta[key])>0
	if compiled:
		compilation_events.append({"wall_seconds":(now-started_us)/1000000.0,"simulation_seconds":elapsed,"species":monster.data.id if is_instance_valid(monster) else "travel","phase":monster.phase if is_instance_valid(monster) else "travel","player_action":fighter.combat.action,"delta":pipeline_delta})
		if compilation_events.size()>256: compilation_events.pop_front()
	previous_pipelines = pipeline_totals
	var costs := {}
	for component in profile_nodes:
		var total: int = profile_nodes[component].get_meta("frame_cost_total_us",0)
		costs[component] = (total-int(profile_previous.get(component,0)))/1000.0
		profile_previous[component] = total
	costs["controller"] = (controller_us-int(profile_previous.get("controller",0)))/1000.0
	profile_previous["controller"] = controller_us
	for component in costs: profile_peaks[component] = maxf(float(profile_peaks.get(component,0)),float(costs[component]))
	timings.append(frame_ms)
	if now-started_us>=2000000:
		steady.append(frame_ms)
		maximum_physics_ms = maxf(maximum_physics_ms,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		maximum_process_ms = maxf(maximum_process_ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	if frame_ms>33.33:
		stalls.append({"ms":snappedf(frame_ms,0.01),"species":monster.data.id if is_instance_valid(monster) else "travel","phase":monster.phase if is_instance_valid(monster) else "travel","wall_seconds":(now-started_us)/1000000.0,"script_cost_ms":costs,"render_submission_ms":last_draw_ms,"pipeline_compilation_delta":pipeline_delta,"pipeline_compilation_totals":pipeline_totals,"player_action":fighter.combat.action,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"recent_contacts":recent_events.slice(maxi(0,recent_events.size()-6)).duplicate(true)})
	if sample_limit>0 and elapsed>=sample_limit: finish.call_deferred()
func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var slow := 0
	for value in sorted:
		total += value
		if value>33.33: slow += 1
	return {"frames":sorted.size(),"mean_ms":total/sorted.size(),"p95_ms":sorted[int((sorted.size()-1)*0.95)],"p99_ms":sorted[int((sorted.size()-1)*0.99)],"max_ms":sorted[-1],"over_33ms":slow}
func finish() -> void:
	if finished: return
	var report := {"all_frames":stats(timings),"after_two_seconds":stats(steady),"stalls":stalls,"maximum_physics_ms":maximum_physics_ms,"maximum_process_ms":maximum_process_ms,"viewport":str(root.get_visible_rect().size),"adapter":RenderingServer.get_video_adapter_name(),"wall_seconds":(Time.get_ticks_usec()-started_us)/1000000.0,"simulation_seconds":elapsed,"scope":"native uncapped real-time full forest hunt from normal spawn, five AI active, no resource resets; local hardware only; excludes initial scene loading; privileged controller, not human difficulty acceptance"}
	report["navigation_slow_paths"] = world.navigation.path_events
	report["navigation_scope"] = "wall-clock stages for navigation calls >=2ms, last 64 events; includes controller and monster callers; timings do not distinguish CPU work from OS scheduling"
	report["peak_script_cost_ms"] = profile_peaks
	report["pipeline_compilations"] = pipeline_counts()
	report["pipeline_compilation_events"] = compilation_events
	report["sample_limit_seconds"] = sample_limit
	report["contact_events"] = recent_events
	if sample_limit>0: report["scope"] = "partial native real-time forest sample, all five AI active, no resource resets; not a full expedition or human difficulty acceptance"
	report["render_timing_scope"] = "frame_pre_draw to frame_post_draw wall time; rendering submission, not GPU execution time"
	var path := "res://../verification/forest-performance-"+str(int(Time.get_unix_time_from_system()))+"-"+str(OS.get_process_id())+".json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FOREST_PERFORMANCE: ",JSON.stringify(report))
	print("FOREST_PERFORMANCE_FILE: ",ProjectSettings.globalize_path(path))
	if sample_limit>0:
		finished = true
		flush_progress()
		for action in ["move_left","move_right","move_forward","move_back","sprint"]: Input.action_release(action)
		print("FOREST_PARTIAL_SAMPLE: completed diagnostic sample; no expedition acceptance")
		world.queue_free()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		quit(0)
		return
	super.finish()
