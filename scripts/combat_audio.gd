extends AudioStreamPlayer3D
## Short positional cues; generated locally with no external sound assets.
static var streams: Dictionary = {}
var age := 0.0
var cue := ""
static func warmup_actions() -> void:
	for kind in ["thrust","sweep","throw","kick"]:
		if not streams.has(kind): streams[kind] = synthesize(kind)
static func emit_at(parent: Node3D, kind: String, point: Vector3) -> void:
	var sound := new()
	sound.cue = kind
	if not streams.has(kind): streams[kind] = synthesize(kind)
	sound.stream = streams[kind]
	var action_cue := kind in ["thrust","sweep","throw","kick"]
	sound.volume_db = -20 if action_cue else (-15 if kind=="warning" else -12)
	sound.max_distance = 12 if action_cue else (28 if kind=="warning" else 18)
	sound.unit_size = 4
	parent.add_child(sound)
	sound.global_position = point
	sound.add_to_group("combat_audio")
	if DisplayServer.get_name()!="headless": sound.play()
static func synthesize(kind: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration: float = {"warning":0.36,"thrust":0.13,"sweep":0.20,"throw":0.24,"kick":0.15}.get(kind,0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(kind.hash())
	var noise := 0.0
	var frames := int(duration*stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames*2)
	for frame in frames:
		var t := float(frame)/stream.mix_rate
		var envelope := minf(t/0.006,1.0)*pow(1-t/duration,2)
		var tone: float
		if kind in ["thrust","sweep","throw","kick"]:
			noise = lerpf(noise,rng.randf_range(-1,1),lerpf(0.48,0.16,t/duration))
			tone = noise*1.8
			if kind=="kick": tone = sin(TAU*(90*t-90*t*t))*0.7+noise*0.5
			envelope = minf(t/0.012,1.0)*pow(1-t/duration,2.2)
		elif kind=="guard":
			tone = sin(TAU*740*t)*exp(-t*20)+0.4*sin(TAU*1873*t)*exp(-t*30)
		elif kind=="warning":
			tone = sin(TAU*(130*t+130*t*t))+0.3*sin(TAU*271*t)*sin(TAU*47*t)
		else:
			tone = sin(TAU*(100*t-100*t*t))+0.35*sin(TAU*1247*t)*sin(TAU*183*t)*exp(-t*25)
		bytes.encode_s16(frame*2,int(clampf(tone*envelope*0.48,-0.95,0.95)*32767))
	stream.data = bytes
	return stream
func _process(delta: float) -> void:
	age += delta
	if age>0.55: queue_free()
