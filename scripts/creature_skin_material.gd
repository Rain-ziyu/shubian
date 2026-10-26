extends RefCounted
static func apply(root: Node3D, data: Dictionary) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/creature_skin.gdshader")
	var settings := {"mossback":[0,5.0,0.24,0.5],"thornhorn":[1,6.0,0.25,0.4],"mistfrill":[2,10.0,0.28,0.5],"reedclaw":[1,11.0,0.34,1.6],"stormcrest":[0,8.0,0.30,0.5]}
	var ventral := {"mossback":"92927a","thornhorn":"a49a7e","mistfrill":"8ca09a","reedclaw":"b3a782","stormcrest":"899ca0"}
	material.set_shader_parameter("ventral_tint",Color(ventral[data.id]))
	var style: Array = settings[data.id]
	for setting in [["pattern_style",style[0]],["pattern_count",style[1]],["pattern_strength",style[2]],["slant",style[3]]]: material.set_shader_parameter(setting[0],setting[1])
	for part in root.find_children("*","MeshInstance3D",true,false):
		if str(part.name) in ["BodySurface","HeadSurface","Jaw","LegSurface","TailSurface"] or str(part.name).begins_with("Forelimb"):
			part.material_override = material
			if str(part.name) in ["BodySurface","TailSurface","HeadSurface","Jaw"]: part.set_instance_shader_parameter("ventral_weight",0.70 if str(part.name) in ["HeadSurface","Jaw"] else 0.55)
			if str(part.name) in ["HeadSurface","Jaw"]: part.set_instance_shader_parameter("fine_scale_weight",0.35)
