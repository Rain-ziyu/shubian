extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
var world: Node3D
var p: CharacterBody3D
var m: CharacterBody3D
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func prepare(offset: Vector3) -> void:
	m.set_physics_process(false)
	m.global_position = Vector3(0,0.05,-10)
	m.rotation = Vector3.ZERO
	m.velocity = Vector3.ZERO
	m.stagger = 0
	m.phase = "windup"
	m.clock = 0
	m.rear_attack = false
	m.attack_done = false
	p.global_position = m.global_position+offset
	p.combat.health = 240
	p.combat.stamina = 100
	p.combat.guard_reward = 0
	p.combat.set_action("idle")
	p.yaw = PI
	p.rig.root.rotation.y = PI
	await physics_frame
	await physics_frame
func run_attack() -> void:
	for frame in 110: m._physics_process(1.0/60)
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	p = world.hunter
	p.set_physics_process(false)
	for foe in get_nodes_in_group("monsters"): foe.set_physics_process(false)
	m = get_nodes_in_group("monsters")[0]
	var neck: Node3D = m.mesh.get_node("Neck")
	Model.animate(m.mesh,m.data,0,"windup",m.data.windup,0)
	var loaded := neck.transform
	Model.animate(m.mesh,m.data,0,"active",0,0)
	check(loaded.is_equal_approx(neck.transform),"windup joins active pose without neck snap")
	Model.animate(m.mesh,m.data,0,"active",0.65,0)
	var follow := neck.transform
	Model.animate(m.mesh,m.data,0,"recover",0,0)
	check(follow.is_equal_approx(neck.transform),"active joins recovery pose without neck snap")
	Model.animate(m.mesh,m.data,0,"recover",m.data.recovery,0)
	check(absf(neck.rotation.y)<0.001,"follow-through returns to neutral")
	var trunk: Node3D = m.mesh.get_node("BodySurface")
	var tail: Node3D = m.mesh.get_node("Tail")
	for sample in [["windup",float(m.data.windup)],["active",0.0],["active",0.40],["active",0.65],["recover",0.0],["recover",float(m.data.recovery)]]:
		Model.animate(m.mesh,m.data,0,sample[0],sample[1],0)
		check(absf(trunk.rotation.z-0.12*neck.rotation.y)<0.001,"trunk load follows the visible head sweep "+str(sample))
		check(absf(tail.rotation.y+0.28*neck.rotation.y)<0.001,"tail counterbalances sweep rather than idling "+str(sample))
		for plate_index in 5:
			var plate: Node3D = m.mesh.get_node("ArmorPlate"+str(plate_index))
			check(plate.transform.is_equal_approx(trunk.transform*plate.get_meta("body_bind")),"armor remains attached during sweep weight transfer")

	check(m.head_rings.size()==2,"head and jaw both supply fitted contact profiles")
	await prepare(Vector3(0,0,-3.2))
	for frame in 66: m._physics_process(1.0/60)
	check(p.combat.health==240,"no damage during windup")
	var first_hit := -1.0
	for frame in 40:
		m._physics_process(1.0/60)
		if first_hit<0 and p.combat.health<240: first_hit = m.clock
	check(first_hit>=0.08 and first_hit<=0.45,"actual sweep hits within visible motion window")
	check(p.combat.health==198,"one sweep deals damage only once")
	await prepare(Vector3(0,0,-4.5))
	run_attack()
	check(p.combat.health==240,"warning edge without head contact causes no damage")
	await prepare(Vector3(0,4,-3.2))
	run_attack()
	check(p.combat.health==240,"head sweep rejects vertical separation")
	await prepare(Vector3(0,0,-3.2))
	p.combat.set_action("guard")
	p.combat.elapsed = 0.2
	run_attack()
	check(p.combat.health==240 and p.combat.guard_reward>0,"frontal head contact can be guarded")
	await prepare(Vector3(0,0,-3.2))
	m.stagger = 1.0
	run_attack()
	check(p.combat.health==240,"staggered windup cannot deliver a sweep")
	await prepare(Vector3(0,0,-3.2))
	world.obstacle(Vector3(0,2,-11.8),Vector3(5,4,0.2),Color.GRAY)
	await physics_frame
	await physics_frame
	run_attack()
	check(p.combat.health==240,"wall prevents head sweep damage")
	# Crossing the same physical trajectory must hit, while a teleport must not sweep its path.
	for teleport in [false,true]:
		await prepare(Vector3(5,0,-3.2))
		m.phase = "active"
		m.clock = 0.2
		Model.animate(m.mesh,m.data,0,"active",m.clock,0)
		m.previous_head = neck.global_transform
		m.previous_head_target = m.global_position+Vector3(-5,0,-3.2)
		m.previous_head_epoch = p.motion_epoch
		if teleport: p.motion_epoch += 1
		# Disable the wall for this isolated relative-motion check.
		for child in world.get_children():
			if child is StaticBody3D and child.position.is_equal_approx(Vector3(0,2,-11.8)): child.collision_layer = 0
		await physics_frame
		await physics_frame
		m._physics_process(1.0/60)
		check(p.combat.health==240 if teleport else p.combat.health==198,"teleport avoids swept path damage" if teleport else "fast hunter crossing contacts moving head")
	await prepare(Vector3(0,0,-3.2))
	m.phase = "active"
	m.clock = 0.5
	m._physics_process(1.0/60)
	check(p.combat.health==240,"late follow-through is no longer damaging")
	print("HEAD_SWEEP_CHECKS: ",checks," FAILURES: ",failures," FIRST_CONTACT=",first_hit)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
