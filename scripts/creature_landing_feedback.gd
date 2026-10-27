extends Node3D
## A real grounded transition owns this short, collision-free presentation.
const Audio = preload("res://scripts/combat_audio.gd")
const LIFETIME := 0.45
static var fragment_mesh: SphereMesh
var points := PackedVector3Array()
var normals := PackedVector3Array()
var size := 2.6
var audio_enabled := true
var age := 0.0
var fragments: Array[Dictionary] = []
var appearance: StandardMaterial3D

func _ready() -> void:
	add_to_group("landing_feedback")
	top_level = true
	global_transform = Transform3D.IDENTITY
	if fragment_mesh==null:
		fragment_mesh = SphereMesh.new()
		fragment_mesh.radius = 0.018
		fragment_mesh.height = 0.036
		fragment_mesh.radial_segments = 6
		fragment_mesh.rings = 3
	appearance = StandardMaterial3D.new()
	appearance.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	appearance.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	appearance.albedo_color = Color("77745e")
	for contact in points.size():
		var normal := normals[contact].normalized()
		var basis := Basis(Quaternion(Vector3.UP,normal))
		for index in 8:
			var angle := (index+0.5)*TAU/8
			var radial := Vector3(sin(angle),0,cos(angle))
			var part := MeshInstance3D.new()
			part.mesh = fragment_mesh
			part.material_override = appearance
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.scale = Vector3.ONE*(0.8+index*0.05)*size/2.6
			add_child(part)
			# Eject from the outside of the supporting foot, not inside its mesh.
			var rim := Vector3(radial.x*size*0.12,0,radial.z*size*0.20)
			var origin := points[contact]+basis*rim
			var velocity := basis*(radial*(0.7+index%3*0.12)*size/2.6+Vector3.UP*(1.5+index%3*0.2))
			fragments.append({"part":part,"origin":origin,"velocity":velocity,"normal":normal,"ground":points[contact]})
	if audio_enabled and not points.is_empty(): Audio.emit_at(get_parent(),"landing",points[0])
	advance_visual(0)

func _process(delta: float) -> void: advance_visual(delta)

func advance_visual(delta: float) -> void:
	age += delta
	if age>=LIFETIME:
		queue_free()
		return
	appearance.albedo_color.a = 0.6*(1-age/LIFETIME)
	for fragment in fragments:
		var point: Vector3 = fragment.origin+fragment.velocity*age+Vector3.DOWN*4.9*age*age
		fragment.part.global_position = point
		fragment.part.visible = (point-fragment.ground).dot(fragment.normal)>=-0.001
