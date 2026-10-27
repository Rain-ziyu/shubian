extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	var monsters := get_nodes_in_group("monsters")
	for m in monsters: m.set_physics_process(false)
	var m = monsters[0]
	# Ordinary-hit recoil is visible without granting a gameplay interrupt.
	for side in [-1,1]:
		m.phase = "windup"
		m.clock = 0.2
		m.stagger = 0
		var before_clock: float = m.clock
		var source: Vector3 = m.global_position+m.global_basis*Vector3(side*3,0,0)
		m.receive_strike(1,source,"fourfold","body")
		check(m.phase=="windup" and m.clock==before_clock and m.stagger==0,"fourfold recoil does not restart or stagger the enemy")
		m.mesh.set_meta("impact_age",0.045)
		m.CreatureModel.animate(m.mesh,m.data,0,"idle",0,0)
		check(m.mesh.get_node("Neck").rotation.y*side>0.02 and m.mesh.get_node("BodySurface").rotation.z*side>0.015,"visible recoil follows the actual incoming side")
		m.mesh.set_meta("impact_age",0.09)
		m.CreatureModel.animate(m.mesh,m.data,0,"idle",0,0)
		check(m.mesh.get_node("Tail").rotation.y*side < -0.02,"tail balances the incoming-side recoil after the head")
		m.mesh.set_meta("impact_age",0.26)
		m.CreatureModel.animate(m.mesh,m.data,0,"idle",0,0)
		check(m.mesh.get_node("Neck").rotation.length()<0.001 and m.mesh.get_node("BodySurface").rotation.length()<0.001,"repeated recoil fully returns to authored pose")
		check(absf(m.mesh.get_node("Tail").rotation.y)<0.001,"tail recoil returns without accumulating over repeated hits")
	# Read the rendered mass response and support feet, not just metadata.
	for creature in monsters:
		creature.stagger = 0
		creature.phase = "idle"
		var origin: Vector3 = creature.global_position+creature.global_basis*Vector3(3,0,0)
		creature.mesh.set_meta("impact_age",0.26)
		creature.CreatureModel.animate(creature.mesh,creature.data,0,"idle",0,0)
		var neutral_y: float = creature.mesh.position.y
		var leg: Node3D = creature.mesh.get_node("Hind1")
		var bones: Skeleton3D = leg.get_node("LegSkeleton")
		var ankle: Vector3 = leg.to_global(bones.get_bone_global_pose(2).origin)
		creature.receive_strike(1,origin,"light","body")
		creature.mesh.set_meta("impact_age",0.045)
		creature.CreatureModel.animate(creature.mesh,creature.data,0,"idle",0,0)
		var light_y: float = creature.mesh.position.y
		var light_yaw: float = creature.mesh.get_node("Neck").rotation.y
		creature.receive_strike(1,origin,"heavy","body")
		creature.mesh.set_meta("impact_age",0.045)
		creature.CreatureModel.animate(creature.mesh,creature.data,0,"idle",0,0)
		check(neutral_y-creature.mesh.position.y>float(creature.data.size)*0.018,"heavy impact visibly compresses weight: "+str(creature.data.id))
		check(creature.mesh.position.y<light_y and creature.mesh.get_node("Neck").rotation.y>light_yaw*1.5,"heavy reaction exceeds light in both weight and head recoil")
		check(leg.to_global(bones.get_bone_global_pose(2).origin).distance_to(ankle)<0.003,"impact compression retains planted ankle: "+str(creature.data.id))
		check(creature.stagger==0 and creature.phase=="idle","visual weight response does not grant mechanical stagger")
		creature.mesh.set_meta("impact_age",0.26)
		creature.CreatureModel.animate(creature.mesh,creature.data,0,"idle",0,0)
		check(absf(creature.mesh.position.y-neutral_y)<0.0001,"impact weight fully recovers without accumulated sinking")
	m.phase = "idle"
	m.clock = 0
	var ui = world.combat_hud
	m.global_position = p.global_position+Vector3(0,0,-6)
	p.lock_target = null
	m.update_nameplate()
	check(m.label.visible and not str(m.data.weakness) in m.label.text,"nearby unselected creature has a short nameplate")
	m.phase = "windup"
	m.rear_attack = true
	m.update_nameplate()
	check("摆尾蓄势" in m.label.text,"unselected attacker still warns about rear attack")
	p.lock_target = m
	m.update_nameplate()
	ui.update_state(p,0)
	check(not m.label.visible,"locked creature has no duplicate world label")
	check(ui.target_strategy.visible and m.data.weakness in ui.target_strategy.text and "摆尾蓄势" in ui.target_hint.text,"locked target retains weakness and active warning")
	m.wall_stun = 0.3
	ui.update_state(p,0)
	check("撞击失衡" in ui.target_hint.text,"wall stun overrides ordinary attack hint")
	m.wall_stun = 0
	m.stagger = 0.3
	ui.update_state(p,0)
	check("失衡" in ui.target_hint.text,"stagger has a clear pursuit cue")
	m.stagger = 0
	m.rear_attack = false
	m.global_position = p.global_position+Vector3(0,0,-30)
	p.lock_target = null
	m.update_nameplate()
	check(not m.label.visible,"distant nameplate stays hidden")
	m.global_position = p.global_position+Vector3(0,0,-6)
	var hp: float = m.health
	m.health = 0
	m.update_nameplate()
	check(not m.label.visible,"corpse does not add combat label clutter")
	m.health = hp
	m.target = null
	m.update_nameplate()
	check(not m.label.visible,"missing hunter safely hides nameplate")
	m.target = p
	for target in monsters:
		p.lock_target = target
		target.phase = "windup"
		target.clock = target.data.windup*0.8
		target.rear_attack = false
		ui.update_state(p,0)
		await process_frame
		await process_frame
		check(target.combat_hint()==ui.target_hint.text,"panel warning matches actual selected species: "+str(target.data.id))
		check(ui.target_text.position.y+ui.target_text.get_minimum_size().y<ui.target_hint.position.y,"species text ends above warning row")
		check(not target.label.visible,"selection changes keep only one information panel")
	var charge = monsters[1]
	charge.clock = charge.data.windup*0.5
	check("蓄势跟踪" in charge.combat_hint(),"early charge tracks target")
	charge.clock = charge.data.windup*0.8
	check("方向已锁定" in charge.combat_hint(),"late charge advertises committed direction")
	p.combat.health = 0
	ui.update_state(p,0)
	m.update_nameplate()
	check(not ui.target_hint.visible and not ui.target_text.visible and not ui.target_strategy.visible and not m.label.visible,"hunter defeat clears target information")
	p.combat.health = 240
	p.lock_target = null
	ui.update_state(p,0)
	check(not ui.target_hint.visible and not ui.target_health.visible and not ui.target_strategy.visible,"unlock clears warning and health together")
	check(ui.target_hint.mouse_filter==Control.MOUSE_FILTER_IGNORE,"warning row leaves combat mouse input available")
	print("COMBAT_READABILITY_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
