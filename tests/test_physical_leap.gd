extends SceneTree
var world: Node3D
var p: CharacterBody3D
var m: CharacterBody3D
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func launch() -> float:
	m.set_physics_process(false)
	m.global_position = Vector3(0,0.01,-16)
	m.rotation = Vector3.ZERO
	m.velocity = Vector3.ZERO
	m.phase = "idle"
	m.clock = 0
	m.stagger = 0
	m.airborne_leap = false
	m.rear_attack = false
	m.health = m.data.health
	m.collision_layer = 1
	m.collision_mask = 3
	m.mesh.rotation = Vector3.ZERO
	p.global_position = Vector3(0,0.01,-18.8)
	p.combat.health = 240
	p.combat.set_action("idle")
	await physics_frame
	await physics_frame
	m.set_physics_process(true)
	var ground := m.global_position.y
	for frame in 150:
		await physics_frame
		if m.phase=="windup" and m.clock>float(m.data.windup)*0.78: p.global_position.x = 6
		if m.airborne_leap: break
	check(m.airborne_leap and not m.is_on_floor(),"live AI launches actual character body")
	return ground
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	p = world.hunter
	p.set_physics_process(false)
	for foe in get_nodes_in_group("monsters"):
		foe.set_physics_process(false)
		foe.global_position = Vector3(80+get_nodes_in_group("monsters").find(foe)*12,0,80)
		if foe.data.id=="reedclaw": m = foe
	var baseline := await launch()
	var peak := baseline
	var airborne_frames := 0
	var checked_peak := false
	for frame in 100:
		await physics_frame
		peak = maxf(peak,m.global_position.y)
		if not m.is_on_floor(): airborne_frames += 1
		if not checked_peak and m.phase=="active" and m.clock>=0.28:
			checked_peak = true
			check(m.global_position.y-baseline>0.8,"actual collider reaches visible leap height")
			check(absf(m.mesh.position.y)<0.05,"model does not add a second visual jump")
			var shape: CollisionShape3D = m.get_child(0)
			check(is_equal_approx(shape.global_position.y,m.global_position.y+shape.position.y),"collision capsule follows airborne actor")
			var query := PhysicsRayQueryParameters3D.create(m.global_position+Vector3(4,1,0),m.global_position+Vector3(-4,1,0),1,[p.get_rid()])
			var hit := m.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider==m,"airborne capsule is ray-hittable at its real height")
			query.from = m.global_position+Vector3(4,-0.2,0)
			query.to = m.global_position+Vector3(-4,-0.2,0)
			check(m.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"vacated space below airborne capsule is not falsely solid")
		if m.phase=="recover" and m.is_on_floor(): break
	check(checked_peak and peak-baseline<1.2,"one-metre ballistic leap stays bounded")
	check(airborne_frames>=30 and airborne_frames<=45,"flight duration matches committed lunge")
	check(m.is_on_floor() and not m.airborne_leap,"normal recovery lands and clears airborne state")
	check(absf(m.global_position.y-baseline)<0.05,"normal leap returns body to ground")
	check(p.combat.health==240,"late lateral escape still avoids damage")
	var landings := get_nodes_in_group("landing_feedback")
	check(landings.size()==1,"actual airborne-to-ground transition emits one landing effect")
	if not landings.is_empty():
		var effect = landings[0]
		effect.set_process(false)
		check(effect.points.size()==2 and effect.fragments.size()==16,"landing emits small fragments at both supporting feet")
		var fitted := true
		for point in effect.points:
			var hit: Dictionary = m.foot_ground_sample(point)
			fitted = fitted and not hit.is_empty() and point.distance_to(hit.get("position",Vector3.ZERO))<0.02
		check(fitted,"landing contact points are fitted to actual terrain")
		var health: float = p.combat.health
		var phase: String = m.phase
		var clock: float = m.clock
		effect.advance_visual(0.10)
		check(p.combat.health==health and m.phase==phase and m.clock==clock and effect.find_children("*","CollisionObject3D",true,false).is_empty(),"landing presentation changes no combat state or collision")
		effect.advance_visual(0.5)
		await process_frame
		check(not is_instance_valid(effect),"landing effect releases its transient objects")
	await launch()
	for frame in 20: await physics_frame
	m.receive_strike(1,p.global_position,"reply","body")
	check(m.airborne_leap and m.stagger>0,"airborne reply interrupts without freezing body")
	for frame in 100:
		await physics_frame
		if m.is_on_floor(): break
	check(m.is_on_floor() and not m.airborne_leap,"interrupted airborne body still lands")
	await launch()
	for frame in 15: await physics_frame
	var death_height := m.global_position.y
	m.health = 0
	await physics_frame
	check(m.collision_layer==0,"airborne corpse immediately stops blocking actors")
	for frame in 100:
		await physics_frame
		if m.is_on_floor(): break
	check(m.is_on_floor() and m.global_position.y<death_height-0.4,"airborne corpse falls onto world floor")
	check(m.collision_mask==0 and not m.airborne_leap,"landed corpse releases world collision and flight state")
	var roof = world.obstacle(Vector3(0,3.65,-20),Vector3(8,0.3,14),Color.GRAY)
	await physics_frame
	await physics_frame
	var roof_ground := await launch()
	var roof_peak := m.global_position.y
	var touched_roof := false
	for frame in 60:
		await physics_frame
		roof_peak = maxf(roof_peak,m.global_position.y)
		touched_roof = touched_roof or m.is_on_ceiling()
		if m.is_on_floor(): break
	check(touched_roof and roof_peak-roof_ground<0.8,"real overhead geometry limits physical jump height")
	check(m.is_on_floor() and not m.airborne_leap,"ceiling-blocked leap still lands")
	roof.queue_free()
	await physics_frame
	await physics_frame
	await launch()
	for frame in 15: await physics_frame
	world.set_process(false)
	p.queue_free()
	await process_frame
	for frame in 100:
		await physics_frame
		if m.is_on_floor(): break
	check(m.is_on_floor() and not m.airborne_leap,"removing target does not suspend creature in air")
	print("PHYSICAL_LEAP_CHECKS: ",checks," FAILURES: ",failures," PEAK=",peak-baseline," AIR_FRAMES=",airborne_frames)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
