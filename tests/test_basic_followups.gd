extends SceneTree
const Combat = preload("res://scripts/combat/trident_combat.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func mouse(p, right: bool, ctrl := false, alt := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	p._unhandled_input(e)
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	# This fixture injects events directly; native focus/mouse motion must not steer it.
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.yaw = 0
	p.pitch = -0.25
	p.rig.root.rotation.y = 0
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var c = p.combat
	c.drawn = true
	var paths := {}
	for next in Combat.FOLLOWUP_SOURCES:
		var source: String = Combat.FOLLOWUP_SOURCES[next]
		var opening := 0.38 if source=="dodge" else float(Combat.MOVES[source].chain)
		c.set_action("idle")
		check(not c.request(next),"cannot directly cast from idle: "+next)
		c.set_action(source)
		c.elapsed = opening-0.19
		mouse(p,source in ["light","pull"])
		check(c.action==source and c.buffered.is_empty(),"early input does not skip anticipation: "+next)
		c.elapsed = opening-0.10
		mouse(p,source in ["light","pull"])
		check(c.buffered==next,"input resolves to derived buffer: "+next)
		c.advance(0.11)
		check(c.action==next and c.elapsed==0,"buffer fires at legal link: "+next)
		check(c.shadow_lifetimes.is_empty(),"basic followup does not grant intent: "+next)
		var points := PackedVector3Array()
		for frame in 100:
			c.elapsed = float(frame)/100*float(Combat.MOVES[next].duration)
			p.animate(0,0)
			var tip: Vector3 = p.rig.weapon.get_node("TipContact").global_position
			points.append(tip)
			if frame%20==0:
				check(tip.is_finite(),"finite independent pose: "+next)
				for side in [-1,1]:
					var arm: Dictionary = p.rig.arms[side]
					check(arm.upper.basis.y.length()<0.40 and arm.lower.basis.y.length()<0.40,"arm bones keep length: "+next)
		paths[next] = points
		c.set_action(source)
		c.elapsed = opening-0.1
		mouse(p,source in ["light","pull"])
		if source=="dodge": c.elapsed = 0.33 # Past existing dodge immunity, before derived link.
		c.receive_damage(10,false)
		c.advance(0.12)
		check(c.action=="hurt" and c.buffered.is_empty(),"interruption cancels queued followup: "+next)
		c.set_action(source)
		c.elapsed = opening
		mouse(p,source in ["light","pull"])
		check(c.action==next,"legal direct input: "+next)
		var hits := []
		var callback := func(beat: int): hits.append(beat)
		c.strike.connect(callback)
		for frame in 120: c.advance(1.0/120)
		c.strike.disconnect(callback)
		check(hits.size()==1,"one strike per derived move: "+next)
	var target = get_nodes_in_group("monsters")[0]
	for m in get_nodes_in_group("monsters"): m.global_position = Vector3(60,0,60)
	p.global_position = Vector3.ZERO
	p.rig.root.rotation.y = 0
	for next in Combat.FOLLOWUP_SOURCES:
		target.global_position = Vector3(0,0,-2)
		target.health = 1000
		var impacts := []
		var confirmed := func(action: String, _beat: int, _target: Node, _result: Dictionary): impacts.append(action)
		p.hit_confirmed.connect(confirmed)
		c.set_action(next)
		c.shadow_lifetimes.clear()
		for frame in range(ceili(float(Combat.MOVES[next].duration)*120)+1):
			c.advance(1.0/120)
			p.animate(1.0/120,0)
			p.update_weapon_contacts()
		p.hit_confirmed.disconnect(confirmed)
		check(impacts.size()==1 and impacts[0]==next,"real blade path confirms exactly one contact: "+next)
		check(target.health<1000 and c.shadow_lifetimes.is_empty(),"derived hit damages without awarding intent: "+next)
		target.global_position = Vector3(60,0,60)
	var rise: PackedVector3Array = paths.rising
	var fall: PackedVector3Array = paths.cleave
	check(rise[54].y>rise[20].y+0.6,"rising cut visibly lifts the blade")
	check(fall[54].y<fall[22].y-0.6,"cleave visibly drops the blade")
	check(paths.advance_thrust[38].distance_to(paths.evade_thrust[38])>0.08,"stepping and evasive thrust have distinct paths")
	c.set_action("heavy")
	c.elapsed = 0.60
	c.shadow_lifetimes.assign([180.0])
	mouse(p,false,true)
	check(c.action=="fourfold","Ctrl left keeps priority over basic followup")
	c.set_action("heavy")
	c.elapsed = 0.60
	mouse(p,false,false,true)
	check(c.action=="turn","Alt left keeps priority over basic followup")
	c.set_action("dodge")
	c.elapsed = 0.38
	mouse(p,false)
	check(c.receive_damage(1,false)=="hurt","derived thrust does not inherit dodge immunity")
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(10,0.4,10)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.position = Vector3(0,19.8,0)
	await physics_frame
	for next in ["advance_thrust","evade_thrust"]:
		p.global_position = Vector3(0,20.02,0)
		p.rig.root.rotation.y = 0
		p.lock_target = null
		p.velocity = Vector3.ZERO
		c.set_action(next)
		for frame in 45:
			await physics_frame
			p.advance_physics(1.0/60)
		check(p.global_position.z< -0.4 and p.global_position.z> -1.0,"derived step travels a short physical distance: "+next)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4,4,0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.position = Vector3(0,21,-0.65)
	await physics_frame
	p.global_position = Vector3(0,20.02,0)
	p.velocity = Vector3.ZERO
	c.set_action("advance_thrust")
	for frame in 45:
		await physics_frame
		p.advance_physics(1.0/60)
	check(p.global_position.z> -0.25 and p.global_position.z< -0.1,"thrust step stops at wall instead of teleporting through")
	print("BASIC_FOLLOWUP_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
