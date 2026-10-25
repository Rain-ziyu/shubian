extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	check(not world.hunter.ghosts.any(func(g): return g.visible),"new hunter has no unearned spectral layers before first physics frame")
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.combat.shadow_lifetimes.assign([180.0,3.0,0.5])
	p.animate(0,0)
	var count := 0
	for i in 5:
		var ghost: Node3D = p.ghosts[i]
		if ghost.visible: count += 1
		var material: ShaderMaterial = ghost.get_meta("spectral_material")
		check(material.shader.code.contains("ALPHA") and material.shader.code.contains("TIME"),"spectral shader has opacity and temporal flow")
		check(is_equal_approx(material.get_shader_parameter("phase_offset"),i*0.9),"layers use distinct pulse phases")
	check(count==3,"visible spectral layers match resource count")
	check(p.ghosts[0].get_meta("spectral_material")!=p.ghosts[1].get_meta("spectral_material"),"layers retain independent fade materials")
	var a: float = p.ghosts[0].get_meta("spectral_material").get_shader_parameter("life_fade")
	var b: float = p.ghosts[1].get_meta("spectral_material").get_shader_parameter("life_fade")
	var c: float = p.ghosts[2].get_meta("spectral_material").get_shader_parameter("life_fade")
	check(a>b and b>c and c>=0.2,"each layer fades by its own remaining lifetime")
	check(p.rig.weapon.get_node("Shaft").material_override is StandardMaterial3D,"held physical weapon keeps its original material")
	check(p.combat.shadow_lifetimes==[180.0,3.0,0.5],"visual update does not advance resources")
	check(float(p.ghosts[2].get_meta("spectral_material").get_shader_parameter("gain_flash"))>0.99,"newly earned shadow has a distinct acquisition highlight")
	p.animate(0.4,0)
	check(is_zero_approx(float(p.ghosts[2].get_meta("spectral_material").get_shader_parameter("gain_flash"))),"acquisition highlight settles while the earned shadow remains")
	p.combat.shadow_lifetimes.pop_back()
	p.animate(0,0)
	check(not p.ghosts[2].visible and p.ghosts[1].visible,"consuming a layer removes its visible spear without hiding the others")
	p.combat.shadow_lifetimes.append(180.0)
	p.animate(0,0)
	check(float(p.ghosts[2].get_meta("spectral_material").get_shader_parameter("gain_flash"))>0.99,"earning a replacement layer highlights it again")
	p.combat.health = 0
	p.animate(0,0)
	check(not p.ghosts.any(func(g): return g.visible),"death hides spectral layers")
	print("SHADOW_VISUAL_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
