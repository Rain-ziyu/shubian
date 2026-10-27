extends MeshInstance3D
## Short world-space strips from authored weapon markers; no collision or combat clock.
const LIFETIME := 0.12
var samples: Array[Dictionary] = []
var strip_mesh := ArrayMesh.new()
func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material_override = material
	hide()
func clear_trail() -> void:
	samples.clear()
	strip_mesh.clear_surfaces()
	mesh = null
	hide()
func add_sample(a: Vector3, b: Vector3, key: String, empowered: bool) -> void:
	if not samples.is_empty():
		var previous: Dictionary = samples[-1]
		if a.distance_to(previous.a)>2.5 or b.distance_to(previous.b)>2.5: clear_trail()
		elif key==previous.key and a.distance_squared_to(previous.a)+b.distance_squared_to(previous.b)<0.000001: return
	samples.append({"a":a,"b":b,"key":key,"age":0.0,"color":Color("ebce86") if empowered else Color("c3eee2")})
	rebuild()
func _process(delta: float) -> void: advance_visual(delta)
func advance_visual(delta: float) -> void:
	for sample in samples: sample.age += delta
	while not samples.is_empty() and float(samples[0].age)>=LIFETIME: samples.pop_front()
	rebuild()
func rebuild() -> void:
	strip_mesh.clear_surfaces()
	if samples.size()<2:
		mesh = null
		hide()
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for index in range(1,samples.size()):
		var before: Dictionary = samples[index-1]
		var after: Dictionary = samples[index]
		if before.key!=after.key: continue
		for corner in [0,1,2,1,3,2]:
			var sample: Dictionary = before if corner<2 else after
			var color: Color = sample.color
			color.a = (0.55 if corner%2==0 else 0.04)*clampf(1-float(sample.age)/LIFETIME,0,1)
			surface.set_color(color)
			surface.add_vertex(sample.a if corner%2==0 else sample.b)
		triangles += 2
	if triangles==0:
		mesh = null
		hide()
	else:
		surface.commit(strip_mesh)
		mesh = strip_mesh
		show()
