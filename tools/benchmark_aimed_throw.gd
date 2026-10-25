extends "res://tools/replay_projectile_weakpoint_video.gd"
## Native real-time sampling of this one live-AI throw, not a whole-map benchmark.
var previous_us := 0
var action_frames: Array[float] = []
var slow_frames := []
var previous_costs := {}
func setup() -> void:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--fixed-fps") or argument.begins_with("--write-movie"):
			printerr("Aimed-throw benchmark requires real-time rendering without recording")
			quit(2)
			return
	await super.setup()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	previous_us = Time.get_ticks_usec()
	fighter.set_meta("measure_frame_cost",true)
	fighter.get_node("OcclusionVisibility").set_meta("measure_frame_cost",true)
	monster.set_meta("measure_frame_cost",true)
	process_frame.connect(sample_frame)
func sample_frame() -> void:
	if result_saved: return
	var now := Time.get_ticks_usec()
	var milliseconds := (now-previous_us)/1000.0
	previous_us = now
	var totals := {"player":fighter.get_meta("frame_cost_total_us",0),"visibility":fighter.get_node("OcclusionVisibility").get_meta("frame_cost_total_us",0),"monster":monster.get_meta("frame_cost_total_us",0),"projectile":fighter.get_meta("projectile_cost_total_us",0)}
	var costs := {}
	for component in totals:
		costs[component] = (int(totals[component])-int(previous_costs.get(component,0)))/1000.0
	previous_costs = totals
	if fighter.combat.action=="throw" or is_instance_valid(fighter.projectile) or fighter.arrival_pose_left>0:
		action_frames.append(milliseconds)
		if milliseconds>33.33: slow_frames.append({"ms":milliseconds,"elapsed":elapsed,"action":fighter.combat.action,"flight":is_instance_valid(fighter.projectile),"arrival_left":fighter.arrival_pose_left,"script_ms":costs})
func finish_probe() -> void:
	var values := action_frames.duplicate()
	values.sort()
	var total := 0.0
	var slow := 0
	for value in values:
		total += value
		if value>33.33: slow += 1
	if not values.is_empty():
		print("AIMED_THROW_PERFORMANCE: ",JSON.stringify({"frames":values.size(),"mean_ms":total/values.size(),"p99_ms":values[int((values.size()-1)*0.99)],"max_ms":values[-1],"over_33ms":slow,"slow_frames":slow_frames,"scope":"native 1280x720 uncapped throw/flight/arrival frames, one live AI, other four frozen; no fixed FPS or recording; local hardware only"}))
	await super.finish_probe()
