extends SceneTree
const Terrain = preload("res://scripts/forest_terrain.gd")
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
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.yaw = 0
	p.global_position = Vector3(0,0.05,0)
	p.combat.drawn = true
	p.combat.set_action("idle")
	p.animate(0,0)
	var ready_body: Vector3 = p.rig.root.position
	p.combat.set_action("plant")
	p.animate(0,0)
	check(p.rig.root.position.distance_to(ready_body)<0.001,"plant begins at the actual ready body height")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	var raised: float = p.rig.weapon.global_position.y
	var raised_body: float = p.rig.root.position.y
	check(raised_body>ready_body.y+0.025,"plant extends the legs while lifting the shaft")
	p.combat.elapsed = 0.5
	p.animate(0,0)
	check(raised>p.rig.weapon.global_position.y+0.25,"plant lifts spear before driving it down")
	check(raised_body-p.rig.root.position.y>0.14,"plant drives body weight down with the shaft")
	p.combat.elapsed = 0.65
	p.animate(0,0)
	var seated_body: Vector3 = p.rig.root.position
	var seated_weapon: Vector3 = p.rig.weapon.global_position
	p.combat.set_action("wait")
	p.animate(0,0)
	check(p.rig.root.position.distance_to(seated_body)<0.001 and p.rig.weapon.global_position.distance_to(seated_weapon)<0.003,"plant settles into waiting without a body or shaft jump")
	for point in [Vector2.ZERO,Vector2(48,40),Vector2(-48,42)]:
		p.global_position = Vector3(point.x,Terrain.mesh_height_at(point.x,point.y)+0.05,point.y)
		for action in ["plant","wait","counter_window"]:
			p.combat.set_action(action)
			p.combat.elapsed = 0.6 if action=="plant" else 0.1
			p.animate(0,0)
			var tip: Vector3 = p.rig.weapon.get_node("TipContact").global_position
			var ray := PhysicsRayQueryParameters3D.create(tip+Vector3.UP,tip-Vector3.UP,2)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and absf(tip.y-float(hit.position.y)+0.025)<0.015,"planted tip matches actual floor: "+action+" "+str(point))
	world.obstacle(Vector3(0,0.2,0),Vector3(3,0.4,3),Color.GRAY)
	p.global_position = Vector3(0,0.45,0)
	await physics_frame
	await physics_frame
	p.combat.set_action("wait")
	p.animate(0,0)
	check(absf(p.rig.weapon.get_node("TipContact").global_position.y-0.375)<0.015,"planted tip uses raised world obstacle rather than terrain below")
	p.global_position = Vector3(72,2,0)
	p.animate(0,0)
	for side in [-1,1]:
		check(p.rig.arms[side].shoulder.position.distance_to(p.rig.arms[side].hand.position)<0.8,"unsupported planting keeps reachable grips")
	print("PLANT_GROUND_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
