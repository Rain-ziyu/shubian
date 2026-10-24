extends SceneTree
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	var trail = p.weapon_trail
	trail.set_process(false)
	await process_frame
	check(not trail.visible and trail.samples.is_empty(),"idle creates no phantom trail")
	p.combat.set_action("heavy")
	p.combat.elapsed = 0.43
	p.animate(0,0)
	p.on_strike(0)
	p.update_weapon_contacts()
	var tip: Vector3 = p.rig.weapon.get_node("TipContact").global_position
	check(trail.samples.size()==1 and not trail.visible,"first real strike sample starts without a fabricated sweep")
	p.combat.elapsed = 0.47
	p.animate(0,0)
	p.update_weapon_contacts()
	check(trail.visible and trail.mesh is ArrayMesh,"moving effective-frame markers form a visible strip")
	var vertices: PackedVector3Array = trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size()==6 and vertices[0].is_equal_approx(tip) and vertices[2].is_equal_approx(p.rig.weapon.get_node("TipContact").global_position),"strip follows actual previous and current tip positions")
	if DisplayServer.get_name()!="headless":
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(3.4,2.1,2.0)
		camera.look_at(Vector3(0,1,-0.4))
		camera.current = true
		camera.fov = 35
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.7,-0.5,0)
		stage.add_child(sun)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var shown := root.get_texture().get_image()
		shown.save_png(ProjectSettings.globalize_path("res://../Shubian-weapon-trail.png"))
		trail.hide()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var hidden := root.get_texture().get_image()
		var changed := 0
		for y in shown.get_height():
			for x in shown.get_width():
				var pixel := shown.get_pixel(x,y)-hidden.get_pixel(x,y)
				if absf(pixel.r)+absf(pixel.g)+absf(pixel.b)>0.04: changed += 1
		check(changed>20,"native renderer displays the swept weapon strip")
		print("WEAPON_TRAIL_RENDER_PIXELS: ",changed)
		trail.show()
	var count: int = trail.samples.size()
	p.update_weapon_contacts()
	check(trail.samples.size()==count,"repeated contact query does not duplicate a stationary sample")
	var health: float = p.combat.health
	var clock: float = p.combat.elapsed
	trail.advance_visual(0.06)
	check(p.combat.health==health and p.combat.elapsed==clock,"trail aging does not advance combat or damage")
	check(trail.find_children("*","CollisionObject3D",true,false).is_empty(),"trail adds no collision")
	trail.advance_visual(0.07)
	check(trail.samples.is_empty() and not trail.visible and trail.mesh==null,"trail expires after its short lifetime")
	trail.add_sample(Vector3.ZERO,Vector3.UP,"heavy0",false)
	trail.add_sample(Vector3.RIGHT,Vector3.ONE,"heavy0",false)
	p.motion_epoch += 1
	p.update_weapon_contacts()
	check(not trail.visible and trail.samples.size()<=1,"teleport epoch cannot connect a streak across the map")
	trail.add_sample(Vector3.ZERO,Vector3.UP,"heavy0",false)
	trail.add_sample(Vector3.RIGHT,Vector3.ONE,"heavy0",false)
	p.combat.set_action("hurt")
	check(not trail.visible and trail.samples.is_empty(),"interrupt clears active trail")
	p.combat.set_action("finisher")
	p.combat.elapsed = 0.95
	p.animate(0,0)
	p.on_strike(1)
	p.update_weapon_contacts()
	check(trail.samples.is_empty(),"kick beat does not create a weapon trail")
	trail.add_sample(Vector3.ZERO,Vector3.UP,"light0",false)
	trail.add_sample(Vector3.RIGHT,Vector3.ONE,"heavy0",false)
	check(not trail.visible,"different actions do not connect through an artificial strip")
	p.combat.health = 0
	p.update_weapon_contacts()
	check(trail.samples.is_empty() and not trail.visible,"death removes remaining trails")
	print("WEAPON_TRAIL_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
