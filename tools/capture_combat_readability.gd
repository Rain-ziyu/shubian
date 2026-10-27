extends SceneTree
## Frozen combat fixture through the player's actual spring-arm camera.
## Not live AI, input, or human difficulty acceptance.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.3).timeout
	var p = world.hunter
	p.set_physics_process(false)
	for monster in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	var m = get_nodes_in_group("monsters")[0]
	# Stand beyond the actual long snout rather than inside the head mesh.
	p.global_position = m.global_position+Vector3(0,0,float(m.data.size)*1.25+0.6)
	p.global_position.y = preload("res://scripts/forest_terrain.gd").height_at(p.global_position.x,p.global_position.z)+0.02
	p.lock_target = m
	p.yaw = 0
	p.pitch = -0.25
	p.rig.root.rotation.y = 0
	p.combat.drawn = true
	p.combat.set_action("guard")
	p.combat.elapsed = 0.18
	p.animate(0,0)
	m.rotation.y = PI
	m.phase = "windup"
	m.clock = m.data.windup*0.8
	m.rear_attack = false
	m.CreatureModel.animate(m.mesh,m.data,0,m.phase,m.clock,0)
	for frame in 120: p.update_camera_framing(1.0/60)
	p.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.combat_hud.update_state(p,0)
	m.update_nameplate()
	await physics_frame
	await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var saved := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-combat-readable.png"))
	print("COMBAT_READABILITY_CAPTURE: ",saved," locked_nameplate_hidden=",not m.label.visible," player_camera=",root.get_camera_3d()==p.camera," msaa_3d=",root.msaa_3d," / frozen guard and windup poses")
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if saved==OK else 1)
