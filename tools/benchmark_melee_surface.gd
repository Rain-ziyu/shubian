extends "res://tests/replay_weakpoints.gd"
## Native wall-clock frames; no recording, screenshots, fixed FPS or injected combat state.
var previous_us := 0
var measured: Array[float] = []
func setup() -> void:
	if DisplayServer.get_name()=="headless":
		quit(2)
		return
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--fixed-fps") or argument.begins_with("--write-movie"):
			quit(2)
			return
	await super.setup()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	previous_us = Time.get_ticks_usec()
	process_frame.connect(sample_frame)
func sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if not result_saved and elapsed>2: measured.append((now-previous_us)/1000.0)
	previous_us = now
func finish_tactics() -> void:
	var ordered := measured.duplicate()
	ordered.sort()
	var total := 0.0
	var slow := 0
	for value in ordered:
		total += value
		if value>33.33: slow += 1
	if not ordered.is_empty():
		print("MELEE_SURFACE_PERFORMANCE: ",JSON.stringify({"frames":ordered.size(),"mean_ms":total/ordered.size(),"p99_ms":ordered[int((ordered.size()-1)*0.99)],"max_ms":ordered[-1],"over_33ms":slow,"scope":"native uncapped single live AI fight, after first two seconds; other four frozen; privileged controller, not human difficulty acceptance"}))
	await super.finish_tactics()
