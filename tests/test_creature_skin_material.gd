extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	var configurations := {}
	for data in database.species:
		var model := Model.create(holder,data)
		var body: MeshInstance3D = model.get_node("BodySurface")
		check(body.material_override is ShaderMaterial,"runtime skin material loads: "+str(data.id))
		var material: ShaderMaterial = body.material_override
		configurations[str([material.get_shader_parameter("pattern_style"),material.get_shader_parameter("pattern_count"),material.get_shader_parameter("pattern_strength")])] = true
		var arrays := body.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		check(uv.size()==arrays[Mesh.ARRAY_VERTEX].size(),"body UV covers every vertex")
		var bounded := true
		for point in uv: bounded = bounded and point.x>=0 and point.x<=1.001 and point.y>=0 and point.y<=1.001
		check(bounded,"surface UV stays within authored profile")
		var tail: MeshInstance3D = model.get_node("Tail/TailSkeleton/SkinnedTail")
		var source_tail: MeshInstance3D = model.get_node("Tail/TailSurface")
		check(tail.material_override==material and tail.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]==source_tail.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV],"tail skin retains material and UV coordinates")
		var leg: MeshInstance3D = model.get_node("Hind1/LegSkeleton/Skin_LegSurface")
		check(leg.material_override==material and leg.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]==model.get_node("Hind1/LegSurface").mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV],"leg skin retains material and UV coordinates")
		var tail_uv: PackedVector2Array = tail.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		Model.animate(model,data,2.0,"active",0.25,4)
		check(tail.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]==tail_uv,"animated tail does not rewrite skin UV")
		var saved = load("res://assets/models/"+str(data.id)+"-v1.tscn").instantiate()
		holder.add_child(saved)
		check(saved.get_node("BodySurface").material_override is ShaderMaterial and saved.get_node("Tail/TailSkeleton/SkinnedTail").mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()>0,"saved model retains skin material and UV")
		if data.id=="reedclaw":
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var left := 0
			var right := 0
			for vertex in vertices.size():
				if colors[vertex].r>0.50 and colors[vertex].g>0.50:
					if vertices[vertex].x<0: left += 1
					else: right += 1
			check(left>20 and right>20,"both continuous body flanks carry readable soft-scale coloration")
			check(saved.get_node("BodySurface").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]==colors,"saved reedclaw retains the authored flank colors")
		if data.id=="stormcrest":
			Model.animate(model,data,0,"windup",data.windup,0)
			check(model.get_node("Crest0").material_override is StandardMaterial3D and model.get_node("Crest0").material_override.emission_energy_multiplier>0,"energy crest keeps independent charge cue")
	check(configurations.size()==5,"five species have distinct skin configurations")
	print("CREATURE_SKIN_MATERIAL_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
