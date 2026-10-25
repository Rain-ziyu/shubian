extends SceneTree
const H = preload("res://scripts/hunter_model.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := H.create(holder)
	var count := 0
	for binding in rig.skinning.bindings:
		var material := binding.source.material_override as ShaderMaterial
		if material==null or not material.shader.resource_path.ends_with("hunter_fabric.gdshader"): continue
		count += 1
		var arrays: Array = binding.source.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var valid: bool = uv.size()==arrays[Mesh.ARRAY_VERTEX].size()
		for point in uv: valid = valid and point.is_finite() and point.x>=-0.001 and point.y>=-0.001 and point.x<=1.001 and point.y<=1.001
		check(valid,"cloth UV coordinates cover every vertex and remain normalized")
		check(binding.rendered.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]==uv,"skinned cloth preserves authored UV")
		check(binding.rendered.material_override==material,"rendered cloth uses intended fabric material")
	check(count==13,"garments and covered elbow/knee joints receive fabric treatment")
	check(rig.root.get_node("Torso/Head").material_override is StandardMaterial3D,"face retains original skin material")
	check(rig.arms[-1].lower.material_override is StandardMaterial3D,"bracer retains armor material")
	for side in [-1,1]:
		var skin := rig.arms[side].upper.material_override as StandardMaterial3D
		check(skin!=null and skin.albedo_color.is_equal_approx(H.Outfit.SKIN_TONE),"exposed upper arm shares the facial skin tone")
		var shoulder_skin := rig.root.get_node("JointClothShoulder"+str(side)).material_override as StandardMaterial3D
		check(shoulder_skin!=null and shoulder_skin.albedo_color.is_equal_approx(H.Outfit.SKIN_TONE),"exposed shoulder connection keeps skin rather than cloth appearance")
	check(rig.legs[-1].boot.material_override is StandardMaterial3D,"boots retain colored sole material")
	check(rig.weapon.get_node("Shaft").material_override is StandardMaterial3D,"weapon retains metal material")
	var cape: ShaderMaterial = rig.root.get_node("Torso/RainCape1").material_override
	var coat: ShaderMaterial = rig.root.get_node("Torso/Undercoat").material_override
	check(cape.get_shader_parameter("wetness")>coat.get_shader_parameter("wetness"),"exposed cape has stronger damp response than protected inner layer")
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	holder.add_child(saved)
	var saved_count := 0
	for mesh in saved.get_node("Skeleton3D").get_children():
		if not mesh is MeshInstance3D: continue
		var label := str(mesh.get_meta("source_part",""))
		if label.begins_with("RainCape") or label.begins_with("CapeHem"):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var arm: int = saved.get_node("Skeleton3D").find_bone("LeftUpperArm" if label.ends_with("-1") else "RightUpperArm")
			var blended := false
			for vertex in weights.size()/4: blended = blended or (bones[vertex*4+1]==arm and weights[vertex*4+1]>0.1)
			check(blended,"saved cape preserves yielding arm weights: "+label)
		if str(mesh.get_meta("source_part","")).begins_with("UpperArmSurface"):
			var saved_skin := mesh.material_override as StandardMaterial3D
			check(saved_skin!=null and saved_skin.albedo_color.is_equal_approx(H.Outfit.SKIN_TONE),"saved upper arm retains skin rather than cloth material")
		var material := mesh.material_override as ShaderMaterial
		if material!=null and material.shader.resource_path.ends_with("hunter_fabric.gdshader"):
			saved_count += 1
			check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()>0,"saved cloth retains UV")
	check(saved_count==count,"saved model retains every runtime fabric material")
	print("HUNTER_FABRIC_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
