extends Node3D
## Presentation only: never advances, pauses or changes combat/physics state.
const Visuals = preload("res://scripts/visuals.gd")
static var normal_sound: AudioStreamWAV
static var weak_sound: AudioStreamWAV
var damage := 0.0
var weak := false
var armor_reduced := false
var armor_just_broken := false
var action := "light"
var force := 1.0
var sparks: Node3D
var age := 0.0
var lifetime := 0.55
var audio_enabled := true
var rays: Array[MeshInstance3D] = []
var flash_material: StandardMaterial3D
var number: Label3D

func _ready() -> void:
	add_to_group("hit_feedback")
	var color := Color("f4cd77") if weak else Color("a6e8de")
	if armor_just_broken: color = Color("ffc28c")
	elif armor_reduced: color = Color("b5bdcc")
	flash_material = Visuals.mat(color,true)
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	force = impact_force(action,weak)
	sparks = Node3D.new()
	add_child(sparks)
	for index in 6:
		var ray := Visuals.piece(sparks,Vector3.ZERO,Vector3(0.035,0.12,0.035)*force,color)
		ray.material_override = flash_material
		ray.rotation.z = index*PI/3
		rays.append(ray)
	number = Label3D.new()
	number.text = ("破甲 " if armor_just_broken else "重甲 " if armor_reduced else "弱点 " if weak else "")+str(roundi(damage))
	number.font_size = 52 if weak else 42
	number.pixel_size = 0.005
	number.modulate = color
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.outline_size = 8
	add_child(number)
	var sound := AudioStreamPlayer3D.new()
	if normal_sound==null: normal_sound = synthesize(false)
	if weak_sound==null: weak_sound = synthesize(true)
	sound.stream = weak_sound if weak else normal_sound
	sound.volume_db = (-13.0 if weak else -16.0)+clampf((force-1.0)*4.0,-1.0,2.0)
	sound.pitch_scale = clampf(1.0-(force-1.0)*0.28,0.86,1.08)
	sound.max_distance = 24
	add_child(sound)
	if audio_enabled and DisplayServer.get_name()!="headless": sound.play()
	advance_visual(0)

static func impact_force(move: String, is_weak: bool) -> float:
	var amount := 1.0
	match move:
		"heavy","turn","spin","rising","cleave": amount = 1.35
		"fourfold": amount = 0.8
		"finisher": amount = 1.5
		"flash","throw","reply": amount = 1.15
	return amount*(1.2 if is_weak else 1.0)

static func synthesize(is_weak: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var duration := 0.14 if is_weak else 0.10
	var frames := int(duration*stream.mix_rate)
	samples.resize(frames*2)
	for frame in frames:
		var t := float(frame)/stream.mix_rate
		var envelope := minf(t/0.002,1.0)*exp(-t*42)*(1-t/duration)
		var tone := sin(TAU*(950 if is_weak else 180)*t)+0.35*sin(TAU*2317*t)*sin(TAU*317*t)
		samples.encode_s16(frame*2,int(clampf(tone*envelope*0.50,-1,1)*32767))
	stream.data = samples
	return stream

func _process(delta: float) -> void: advance_visual(delta)

func advance_visual(delta: float) -> void:
	age += delta
	if age>=lifetime:
		queue_free()
		return
	var alpha := maxf(0,1-age/0.18)
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera): sparks.global_basis = camera.global_basis.orthonormalized()
	flash_material.albedo_color.a = alpha
	for index in rays.size():
		var angle := index*TAU/6
		rays[index].position = Vector3(sin(angle),cos(angle),0)*(0.04+age*1.2)*force
		rays[index].visible = alpha>0
	number.position.y = 0.16+age*0.8
	number.modulate.a = clampf((lifetime-age)/0.20,0,1)
