extends SceneTree
class VisualBlocker extends Node3D:
	var mesh: Node3D
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func capture() -> Image:
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func without_cue(cue: Node) -> Image:
	# Baseline capture temporarily disables the effect, then restores its owner state.
	var previous: Variant = cue.material.get_shader_parameter("enabled")
	cue.material.set_shader_parameter("enabled",false)
	var result := await capture()
	cue.material.set_shader_parameter("enabled",previous)
	return result
func difference(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var delta := a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(delta.r)+absf(delta.g)+absf(delta.b)>0.05: count += 1
	return count
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p = load("res://scripts/player.gd").new()
	stage.add_child(p)
	p.set_physics_process(false)
	var cue = p.get_node("OcclusionVisibility")
	cue.set_physics_process(false)
	check(not cue.parts.is_empty(),"cue targets rendered skin meshes")
	var part: MeshInstance3D = cue.parts[0]
	var original = part.material_override
	check(part.material_overlay==cue.material,"skin receives independent overlay")
	check(cue.material.shader!=null and cue.material.render_priority==10,"depth shader installed")
	var hp: float = p.combat.health
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.4,5)
	camera.look_at(Vector3(0,1,0))
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-30,25,0)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3,3,0.5)
	wall.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3,0.22,0.1)
	wall.material_override = material
	var blocker := VisualBlocker.new()
	stage.add_child(blocker)
	blocker.mesh = Node3D.new()
	blocker.add_child(blocker.mesh)
	blocker.mesh.add_child(wall)
	blocker.add_to_group("monsters")
	wall.position = Vector3(0,1,2)
	await process_frame
	await process_frame
	camera.make_current()
	if DisplayServer.get_name()!="headless":
		var hidden := await without_cue(cue)
		cue._physics_process(0)
		var highlighted := await capture()
		var blocked_pixels := difference(hidden,highlighted)
		check(blocked_pixels>300,"hidden body is visible through rendered non-collidable geometry")
		highlighted.save_png(ProjectSettings.globalize_path("res://../Shubian-occlusion-test.png"))
		box.size = Vector3(3,0.8,0.5)
		wall.position.y = 1.35
		var partial_base := await without_cue(cue)
		cue._physics_process(0)
		var partial_cue := await capture()
		check(difference(partial_base,partial_cue)>100,"partial obstruction still highlights the covered upper body")
		var shin: MeshInstance3D = p.rig.legs[-1].shin
		var leg_screen := Vector2i(camera.unproject_position(shin.to_global(shin.get_aabb().get_center())))
		var leg_region := Rect2i(leg_screen-Vector2i(6,8),Vector2i(12,16))
		var leg_pixels := difference(partial_base.get_region(leg_region),partial_cue.get_region(leg_region))
		check(leg_pixels<20,"upper body obstruction does not highlight unobstructed lower leg")
		print("OCCLUSION_PARTIAL_LEG_PIXELS: ",leg_pixels)
		partial_cue.save_png(ProjectSettings.globalize_path("res://../Shubian-partial-occlusion.png"))
		# Same scene with the former whole-character gate, for a like-for-like diagnostic.
		var saved_flags := []
		for piece in cue.parts:
			saved_flags.append(piece.get_instance_shader_parameter("blocked_part"))
			piece.set_instance_shader_parameter("blocked_part",true)
		var whole_body_cue := await capture()
		print("OCCLUSION_WHOLE_GATE_LEG_PIXELS: ",difference(partial_base.get_region(leg_region),whole_body_cue.get_region(leg_region)))
		for index in cue.parts.size(): cue.parts[index].set_instance_shader_parameter("blocked_part",saved_flags[index])
		cue._physics_process(0)
		wall.visible = false
		var clear := await without_cue(cue)
		cue._physics_process(0)
		var clear_highlight := await capture()
		var clear_pixels := difference(clear,clear_highlight)
		check(clear_pixels<20,"unobstructed body pixels preserve original appearance")
		print("OCCLUSION_RENDER_PIXELS: blocked=",blocked_pixels," clear=",clear_pixels)
		for sample in [["light",0.25],["heavy",0.43],["reply",0.26],["flash",0.23],["finisher",0.95]]:
			p.combat.set_action(sample[0])
			p.combat.elapsed = sample[1]
			p.animate(0,0)
			var pose_clear := await without_cue(cue)
			cue._physics_process(0)
			var pose_highlight := await capture()
			var pose_pixels := difference(pose_clear,pose_highlight)
			check(pose_pixels<20,str(sample[0])+" clear attack pose avoids self highlighting")
			print("OCCLUSION_POSE_PIXELS: ",sample[0],"=",pose_pixels)

	wall.visible = true
	wall.position = Vector3.ZERO
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 1.2
	wall.mesh = ring
	check(not cue.foreign_blocks(Vector3(0,3,0),Vector3.ZERO),"open space inside a mesh bounding box does not create a false obstruction")
	check(cue.foreign_blocks(Vector3(0.9,3,0),Vector3(0.9,0,0)),"actual foreground mesh surface still blocks the hunter")
	var snapshot: Array = cue.collect_surfaces()
	check(not cue.foreign_blocks(Vector3(0,3,0),Vector3.ZERO,snapshot),"shared frame geometry preserves the open mesh hole")
	check(cue.foreign_blocks(Vector3(0.9,3,0),Vector3(0.9,0,0),snapshot),"shared frame geometry preserves actual surface blocking")
	wall.position.x = 5
	check(not cue.foreign_blocks(Vector3(0.9,3,0),Vector3(0.9,0,0),cue.collect_surfaces()),"next frame refresh follows a moving blocker instead of leaving a ghost obstruction")
	check(part.material_override==original and p.combat.health==hp,"presentation preserves material and health")
	p.combat.set_action("idle")
	p.animate(0,0)
	wall.mesh = box
	box.size = Vector3(3,3,0.5)
	wall.position = Vector3(0,1,2)
	wall.show()
	cue._physics_process(0)
	check(cue.occluded,"changed blocking geometry is reflected immediately")
	var updates: int = cue.parameter_updates
	cue._physics_process(0)
	check(cue.parameter_updates==updates,"stable geometry does not resubmit identical shader state")
	wall.hide()
	cue._physics_process(0)
	check(not cue.occluded and cue.parameter_updates>updates,"removing blocker immediately clears cached shader state")
	updates = cue.parameter_updates
	for strength in [0.22,0.11,0.0]:
		p.feedback.hurt_flash = strength
		cue._physics_process(0)
		check(is_equal_approx(float(cue.material.get_shader_parameter("hurt_flash")),strength/0.22),"hurt flash retains each changing fade value")
	check(cue.parameter_updates==updates+3,"hurt fade only submits the changing material parameter")
	p.combat.health = 0
	cue._physics_process(0)
	check(cue.material.get_shader_parameter("enabled")==false,"death disables cue")
	print("HUNTER_VISIBILITY_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	# The camera mount is deliberately parented beside the hunter by player._ready.
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
