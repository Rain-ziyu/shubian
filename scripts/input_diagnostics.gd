extends Node
## Opt-in local game-window trace. Never installs a global keyboard hook.
var hunter: CharacterBody3D
var directory := ""
var log_path := ""
var file: FileAccess
var sequence := 0
var input_sequence := 0
var last_feedback := ""
var last_shadows := -1

static func attach(world: Node, fighter: CharacterBody3D, destination := "") -> Node:
	var recorder = load("res://scripts/input_diagnostics.gd").new()
	recorder.name = "InputDiagnostics"
	recorder.hunter = fighter
	recorder.directory = destination
	world.add_child(recorder)
	return recorder

func _ready() -> void:
	if directory.is_empty(): directory = "user://input-diagnostics"
	directory = ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error==OK:
		log_path = directory.path_join("input-%d-%d-%d.jsonl" % [int(Time.get_unix_time_from_system()),OS.get_process_id(),Time.get_ticks_usec()])
		file = FileAccess.open(log_path,FileAccess.WRITE)
	if file==null:
		push_warning("Input diagnostics could not open its local log directory")
		set_process(false)
		set_process_input(false)
		return
	var revision := "development"
	var manifest_path := OS.get_executable_path().get_base_dir().path_join("build-manifest.json")
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary: revision = str(manifest.get("source_revision",revision))
	record("session_start",{"schema":2,"engine":Engine.get_version_info().string,"source_revision":revision,"scope":"opt-in events delivered to this game window; local file only"})
	hunter.combat.action_changed.connect(_on_action)
	hunter.action_requested.connect(_on_request)
	hunter.hit_confirmed.connect(_on_hit)
	get_window().title = "戍边 · 输入诊断（仅记录本游戏窗口）"
	print("WINDOW_INPUT_TRACE_READY")
	print("WINDOW_INPUT_TRACE_FILE: ",log_path)

func snapshot() -> Dictionary:
	if not is_instance_valid(hunter): return {"unavailable":true}
	var combat = hunter.combat
	return {"action":combat.action,"elapsed":combat.elapsed,"buffered":combat.buffered,"guard_reward":combat.guard_reward,"flash_window":combat.flash_window,"shadows":combat.shadow_lifetimes.size(),"health":combat.health,"stamina":combat.stamina,"feedback":hunter.feedback.text}

func _on_action(action: String) -> void:
	record("action_changed",{"action":action})

func _on_request(action: String, accepted: bool, reason: String) -> void:
	record("action_request",{"requested":action,"outcome":"started" if accepted else ("queued" if hunter.combat.buffered==action else "rejected"),"reason":reason})

func _on_hit(action: String, beat: int, target: Node3D, result: Dictionary) -> void:
	record("hit_confirmed",{"action":action,"beat":beat,"species":str(target.data.id),"part":str(result.get("part","")),"damage":float(result.get("damage",0)),"weak":bool(result.get("weak",false))})

func record(kind: String, fields: Dictionary = {}) -> void:
	if file==null: return
	sequence += 1
	fields["event"] = kind
	fields["sequence"] = sequence
	fields["input_sequence"] = input_sequence
	fields["milliseconds"] = Time.get_ticks_msec()
	fields["state"] = snapshot()
	file.store_line(JSON.stringify(fields))
	file.flush()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey and not event is InputEventMouseButton: return
	input_sequence += 1
	var fields := {"pressed":event.pressed,"ctrl":event.ctrl_pressed,"alt":event.alt_pressed,"shift":event.shift_pressed,"device":event.device}
	if event is InputEventKey:
		fields.merge({"physical":event.physical_keycode,"logical":event.keycode,"unicode":event.unicode,"echo":event.echo})
	else:
		fields.merge({"button":event.button_index,"button_mask":event.button_mask})
	record("key" if event is InputEventKey else "mouse",fields)

func _process(_delta: float) -> void:
	if hunter.feedback.text!=last_feedback:
		last_feedback = hunter.feedback.text
		if not last_feedback.is_empty(): record("feedback",{"text":last_feedback})
	var count: int = hunter.combat.shadow_lifetimes.size()
	if count!=last_shadows:
		record("shadow_count",{"previous":last_shadows,"count":count})
		last_shadows = count

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_IN: record("focus",{"focused":true})
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: record("focus",{"focused":false})

func _exit_tree() -> void:
	if file:
		record("session_end")
		file.close()
		file = null
