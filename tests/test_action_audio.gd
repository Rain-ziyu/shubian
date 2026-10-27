extends SceneTree
const Audio = preload("res://scripts/combat_audio.gd")
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func clear_cues() -> void:
	for cue in get_nodes_in_group("combat_audio"): cue.queue_free()
	await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	await process_frame
	for kind in ["thrust","sweep","throw","kick","landing"]:
		check(Audio.streams.has(kind),"action stream is prepared before combat: "+kind)
		var stream: AudioStreamWAV = Audio.streams[kind]
		var peak := 0
		for i in stream.data.size()/2: peak = maxi(peak,absi(stream.data.decode_s16(i*2)))
		check(peak>1000 and peak<32767 and stream.get_length()<=0.25,"bounded non-clipped action PCM: "+kind)
		check(stream.data.decode_s16(0)==0 and abs(stream.data.decode_s16(stream.data.size()-2))<4,"action sound has quiet endpoints: "+kind)
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.35
	p.update_action_audio()
	check(get_nodes_in_group("combat_audio").is_empty(),"no whoosh during early windup")
	p.combat.elapsed = 0.37
	p.update_action_audio()
	var cues := get_nodes_in_group("combat_audio")
	check(cues.size()==1 and cues[0].cue=="sweep","sweep cue begins before the contact beat even without a target")
	p.update_action_audio()
	check(get_nodes_in_group("combat_audio").size()==1,"one cue per beat despite repeated updates")
	check(cues[0].volume_db<=-20 and cues[0].max_distance<=12,"action cues stay quieter and more local than warning cues")
	await clear_cues()
	p.combat.set_action("fourfold")
	for frame in 76:
		p.combat.advance(1.0/60)
		p.update_action_audio()
	cues = get_nodes_in_group("combat_audio")
	check(cues.size()==4,"fourfold emits four authored thrust beats")
	for cue in cues: check(cue.cue=="thrust","fourfold uses the thrust sound")
	await clear_cues()
	p.combat.set_action("finisher")
	p.combat.elapsed = 0.90
	p.action_audio_beats[0] = true
	p.update_action_audio()
	check(get_nodes_in_group("combat_audio").size()==1 and get_nodes_in_group("combat_audio")[0].cue=="kick","second finisher beat uses a foot thump")
	await clear_cues()
	p.combat.set_action("heavy")
	p.combat.elapsed = 1
	p.update_action_audio()
	check(get_nodes_in_group("combat_audio").is_empty(),"a stale beat does not play late")
	p.combat.health = 0
	p.combat.set_action("light")
	p.combat.elapsed = 0.2
	p.update_action_audio()
	check(get_nodes_in_group("combat_audio").is_empty(),"defeated hunter produces no new action sounds")
	print("ACTION_AUDIO_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
