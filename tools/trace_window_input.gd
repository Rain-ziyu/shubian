extends SceneTree
## Opt-in diagnostic script: records events delivered to this game window only.
class InputRecorder extends Node:
	var file: FileAccess
	func record(kind: String, fields: Dictionary) -> void:
		fields["event"] = kind
		fields["milliseconds"] = Time.get_ticks_msec()
		var line := JSON.stringify(fields)
		print("WINDOW_INPUT_EVENT: ",line)
		if file:
			file.store_line(line)
			file.flush()
	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			record("key",{"pressed":event.pressed,"echo":event.echo,"physical":event.physical_keycode,"logical":event.keycode,"unicode":event.unicode,"device":event.device})
		elif event is InputEventMouseButton:
			record("mouse",{"pressed":event.pressed,"button":event.button_index})
	func _notification(what: int) -> void:
		if what==NOTIFICATION_WM_WINDOW_FOCUS_IN: print("WINDOW_FOCUS: in")
		elif what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: print("WINDOW_FOCUS: out")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var recorder := InputRecorder.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../verification"))
	var path := "res://../verification/window-input-"+str(int(Time.get_unix_time_from_system()))+"-"+str(OS.get_process_id())+".jsonl"
	recorder.file = FileAccess.open(path,FileAccess.WRITE)
	root.add_child(recorder)
	root.title = "戍边 · 输入诊断"
	print("WINDOW_INPUT_TRACE_READY")
	print("WINDOW_INPUT_TRACE_FILE: ",ProjectSettings.globalize_path(path))
