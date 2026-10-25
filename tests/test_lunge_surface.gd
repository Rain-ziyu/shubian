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
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	var actor: CharacterBody3D
	for monster in get_nodes_in_group("monsters"):
		monster.set_physics_process(false)
		monster.global_position = Vector3(80+get_nodes_in_group("monsters").find(monster)*12,0,80)
		if monster.data.id=="reedclaw": actor = monster
	actor.global_position = Vector3(0,0.05,-16)
	actor.rotation = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor.phase = "idle"
	actor.clock = 0
	actor.stagger = 0
	actor.rear_attack = false
	p.global_position = Vector3(0,0.05,-19.7)
	p.combat.set_action("idle")
	p.combat.health = 240
	await physics_frame
	await physics_frame
	actor.set_physics_process(true)
	for frame in 180:
		await physics_frame
		if actor.phase=="active" and actor.clock>0: break
	actor.set_physics_process(false)
	check(actor.phase=="active","normal AI enters the first moving leap tick")
	var head: MeshInstance3D = actor.mesh.get_node("Neck/HeadSurface")
	var nose := head.to_global(Vector3(0,0,head.get_aabb().position.z))
	var gap: float = nose.z-(p.global_position.z+0.32)
	print("LUNGE_CONTACT_GAP: ",gap," clock=",actor.clock," health=",p.combat.health)
	check(gap>0.08,"first moving tick still has a visible nose-to-hunter capsule gap")
	check(p.combat.health==240,"the forward lane alone does not damage before surface contact")
	actor.set_physics_process(true)
	for frame in 100:
		await physics_frame
		if actor.phase=="recover": break
	actor.set_physics_process(false)
	check(is_equal_approx(p.combat.health,240-float(actor.data.damage)),"remaining in the moving creature path takes one normal hit")
	check(actor.phase=="recover" and actor.exposed>0,"contact-based leap retains the recovery weakness")
	print("LUNGE_SURFACE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
