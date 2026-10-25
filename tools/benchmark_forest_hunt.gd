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
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await super.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fighter.camera_manual_time = 0
	profile_nodes = {"player":fighter,"visibility":fighter.get_node("OcclusionVisibility")}
	for creature in get_nodes_in_group("monsters"): profile_nodes[str(creature.data.id)] = creature
	for node: Node in profile_nodes.values(): node.set_meta("measure_frame_cost",true)
	started_us = Time.get_ticks_usec()
	previous_us = started_us
	process_frame.connect(sample_frame)
func control() -> void:
	var start := Time.get_ticks_usec()
	super.control()
	controller_us += Time.get_ticks_usec()-start
func sample_frame() -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	var frame_ms := (now-previous_us)/1000.0
	previous_us = now
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
		stalls.append({"ms":snappedf(frame_ms,0.01),"species":monster.data.id if is_instance_valid(monster) else "travel","phase":monster.phase if is_instance_valid(monster) else "travel","wall_seconds":(now-started_us)/1000000.0,"script_cost_ms":costs})
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
	report["peak_script_cost_ms"] = profile_peaks
	var path := "res://../verification/forest-performance-"+str(int(Time.get_unix_time_from_system()))+"-"+str(OS.get_process_id())+".json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FOREST_PERFORMANCE: ",JSON.stringify(report))
	print("FOREST_PERFORMANCE_FILE: ",ProjectSettings.globalize_path(path))
	super.finish()
