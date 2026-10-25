extends SceneTree
const Parts = preload("res://scripts/monster_parts.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var parts: Array[Dictionary] = [{"id":"head","center":Vector3.ZERO,"radius":0.2}]
	check(not Parts.cast_volumes(parts,Vector3(-2,0,0),Vector3.RIGHT,4,0.075).is_empty(),"fast trace crosses part between frame endpoints")
	check(Parts.cast_volumes(parts,Vector3(-2,0.4,0),Vector3.RIGHT,4,0.075).is_empty(),"nearby but untouched part misses")
	check(not Parts.cast_volumes(parts,Vector3.ZERO,Vector3.UP,0,0.075).is_empty(),"stationary overlapping blade contacts part")
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	var monsters := get_nodes_in_group("monsters")
	for creature in monsters: creature.set_physics_process(false)
	var m = monsters[0]
	p.global_position = Vector3.ZERO
	p.rig.root.rotation.y = 0
	m.global_position = Vector3(0,0,-2)
	p.combat.set_action("light")
	p.combat.elapsed = 0.25
	p.animate(0,0)
	var hp: float = m.health
	p.on_strike(0)
	check(m.health==hp,"beat starts window without instant radial damage")
	p.update_weapon_contacts()
	check(m.health<hp,"visible head contacts nearby part")
	var after: float = m.health
	for frame in 20: p.update_weapon_contacts()
	check(m.health==after,"one beat cannot damage same monster every physics frame")
	p.combat.set_action("hurt")
	check(p.strike_windows.is_empty(),"interruption clears outstanding contacts")
	p.combat.set_action("spin")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	m.global_position = Vector3(0,0,3)
	hp = m.health
	p.on_strike(0)
	p.update_weapon_contacts()
	check(m.health==hp,"spin does not hit entire circle before blade arrives")
	p.combat.set_action("reply")
	p.combat.elapsed = 0.26
	p.animate(0,0)
	var butt: PackedVector3Array = p.weapon_contact_points("reply",0)
	check(butt[0].distance_to(p.rig.weapon.to_global(Vector3(0,-0.98,0)))<0.001,"reply traces butt end")
	check(butt[0].distance_to(p.rig.weapon.to_global(Vector3(0,1.2,0)))>2,"reply does not trace forward prongs")
	var foot: PackedVector3Array = p.weapon_contact_points("finisher",1)
	check(foot.size()==1 and foot[0].distance_to(p.rig.legs[1].boot.to_global(Vector3(0,-0.5,-0.45)))<0.001,"finisher second beat uses actual forefoot sole")
	p.combat.set_action("fourfold")
	m.global_position = Vector3(0,0,-2)
	hp = m.health
	var landed := 0
	for beat in 4:
		var before: float = m.health
		p.combat.elapsed = float(p.Combat.MOVES.fourfold.hits[beat])
		p.animate(0,0)
		p.on_strike(beat)
		p.update_weapon_contacts()
		if m.health<before: landed += 1
	check(landed==4,"fourfold has four independent contact windows")
	p.combat.set_action("pull")
	p.combat.elapsed = 0.4
	p.animate(0,0)
	var hooks: PackedVector3Array = p.weapon_contact_points("pull",0)
	check(hooks.size()==2 and hooks[0].distance_to(p.rig.weapon.get_node("LeftHookContact").global_position)<0.001,"pull traces model's backward hook markers")
	hp = m.health
	m.velocity = Vector3.ZERO
	p.on_strike(0)
	p.update_weapon_contacts()
	check(m.health<hp and m.velocity.z>0,"actual hook contact pulls target toward player")
	var storm = monsters[4]
	storm.global_position = Vector3(0,0,-2)
	m.global_position = Vector3(30,0,30)
	storm.phase = "windup"
	storm.disrupted = 0
	p.combat.set_action("light")
	p.combat.elapsed = 0.25
	p.pitch = 0.65
	p.animate(0,0)
	var raised_tip: Vector3 = p.weapon_contact_points("light",0)[0]
	check(raised_tip.y>2.4,"looking upward lifts the arms and actual thrust tip above crouched stance")
	p.on_strike(0)
	p.update_weapon_contacts()
	check(storm.disrupted==0,"raised tip below visible high spine cannot gain a proxy weakpoint hit")
	storm.global_position = Vector3(40,0,40)
	var mist = monsters[2]
	mist.global_position = Vector3(0,0,3)
	mist.phase = "windup"
	mist.stagger = 0
	p.rig.root.rotation.y = PI
	p.yaw = PI
	p.combat.set_action("light")
	p.combat.elapsed = 0.25
	p.animate(0,0)
	p.on_strike(0)
	p.update_weapon_contacts()
	check(mist.stagger>0,"raised visible tip can interrupt exposed front mist sac")
	print("WEAPON_TRACE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
