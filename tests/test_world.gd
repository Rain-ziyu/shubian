extends SceneTree
var failed := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	scene.hunter.set_process_input(false)
	scene.hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	var monsters := get_nodes_in_group("monsters")
	check(monsters.size()==5,"five monsters instantiated")
	var ids := {}
	for m in monsters:
		m.set_physics_process(false)
		ids[m.data.id] = true
		check(m.mesh.get_child_count()>5,"creature mesh exists: "+str(m.data.id))
		var front: Vector3 = -m.global_basis.z
		var initial: float = m.health
		m.phase = "idle"
		m.exposed = 0
		var normal: Dictionary = m.receive_strike(10,m.global_position+front*4,"light")
		m.health = initial
		m.phase = "windup" if m.data.weak_side=="front" else "recover"
		m.exposed = 2
		var weak_position: Vector3 = m.global_position-front*4
		if m.data.weak_side=="front": weak_position = m.global_position+front*4
		elif m.data.weak_side=="flank": weak_position = m.global_position+m.global_basis.x*4
		var weak: Dictionary = m.receive_strike(10,weak_position,"light")
		check(weak.weak and weak.damage>normal.damage,"weakness increases damage: "+str(m.data.id))
		if m.data.id=="mistfrill": check(m.stagger>0,"mist windup interrupt")
		if m.data.id=="stormcrest":
			m.phase = "windup"
			m.receive_strike(100,weak_position,"light")
			check(m.stagger>0,"crest accumulation interrupt")
		m.health = initial
	check(ids.size()==5,"five distinct species")
	var p = scene.hunter
	p.set_physics_process(false)
	var m = monsters[0]
	p.global_position = m.global_position+Vector3(0,0,2)
	p.rig.root.rotation.y = 0
	m.phase = "idle"
	m.stagger = 0
	var old_health: float = m.health
	p.combat.request("light")
	p.combat.advance(0.3)
	p.animate(0,0)
	p.update_weapon_contacts()
	check(m.health<old_health,"real strike signal reaches monster in world")
	var before: float = p.combat.health
	p.combat.set_action("idle")
	p.take_damage(30,m.global_position,false)
	check(p.combat.health==before-30 and p.combat.action=="hurt","monster damage interrupts player")
	p.combat.set_action("idle")
	p.combat.request("guard")
	p.combat.advance(0.2)
	before = p.combat.health
	p.take_damage(30,m.global_position,true)
	check(p.combat.health==before and p.combat.guard_reward>0,"world facing guard blocks attack")
	print("WORLD_CHECKS: ",checks," FAILURES: ",failed)
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
