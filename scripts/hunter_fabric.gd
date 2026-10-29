extends RefCounted
## Material treatment only; garment geometry and combat markers are unchanged.
static func apply(root: Node3D) -> void:
	for part in root.find_children("*","MeshInstance3D",true,false):
		var label := str(part.name)
		if label.begins_with("JointClothShoulder") or label.begins_with("JointClothElbow"): continue
		if label not in ["Undercoat","CoatPanel","TrouserThigh","TrouserShin","CrossedCollar","InnerCollar","Collar"] and not label.begins_with("RainCape") and not label.begins_with("Sleeve") and not label.begins_with("JointCloth"): continue
		var original := part.material_override as StandardMaterial3D
		if original==null: continue
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/hunter_fabric.gdshader")
		material.set_shader_parameter("base_color",original.albedo_color)
		material.set_shader_parameter("wetness",0.55 if label.begins_with("RainCape") else 0.20)
		material.set_shader_parameter("pattern_seed",float(absi(label.hash())%1000)*0.031)
		material.set_shader_parameter("canvas_map",preload("res://assets/textures/cloth/ranger-waxed-canvas.png"))
		material.set_shader_parameter("canvas_weight",0.65 if label.begins_with("RainCape") else 0.0)
		part.material_override = material
