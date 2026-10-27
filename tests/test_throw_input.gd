extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func button(pressed: bool, ctrl := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	return event
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var c = p.combat
	var start: Vector3 = p.global_position
	p._unhandled_input(button(true))
	check(c.action=="heavy","right press immediately starts sweep")
	c.advance(1.2)
	p._unhandled_input(button(false))
	check(c.action=="idle" and not is_instance_valid(p.projectile),"long hold release cannot throw or repeat sweep")
	check(p.global_position==start,"long right hold never teleports")
	p._unhandled_input(button(true))
	c.advance(0.05)
	p._unhandled_input(button(false))
	check(c.action=="heavy" and c.elapsed>0,"short release does not restart sweep")
	c.set_action("idle")
	c.shadow_lifetimes.assign([180.0])
	p._unhandled_input(button(true,true))
	check(c.action=="spin" and c.shadow_lifetimes.is_empty(),"Ctrl right retains intent spin")
	c.advance(1.5)
	p._unhandled_input(button(false,true))
	check(c.action=="idle" and not is_instance_valid(p.projectile),"modified release cannot trigger throw")
	print("THROW_INPUT_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
