extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func mouse(p: Node, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	p._unhandled_input(event)
func key(p: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	p._unhandled_input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.combat.set_action("reply")
	p.combat.advance(0.08)
	var followup := InputEventMouseButton.new()
	followup.button_index = MOUSE_BUTTON_LEFT
	followup.pressed = true
	followup.ctrl_pressed = true
	p._unhandled_input(followup)
	check(p.combat.buffered=="flash","early Ctrl left selects flash rather than resource combo")
	p.combat.advance(0.18)
	p.combat.confirm_hit()
	p.combat.advance(0.15)
	check(p.combat.action=="flash","early Ctrl left executes after confirmed reply")
	p.combat.confirm_hit()
	check(p.combat.shadow_lifetimes.size()==1,"confirmed flash earns one shadow")
	p.combat.shadow_lifetimes.clear()
	p.combat.set_action("idle")
	mouse(p,true)
	p.heavy_held = 0.2
	mouse(p,false)
	check(p.combat.action=="heavy","short right release performs sweep")
	p.combat.set_action("idle")
	mouse(p,true)
	p.heavy_held = 0.5
	mouse(p,false)
	check(p.combat.action=="throw","long right release performs throw")
	for next in ["hurt","dodge","guard","light"]:
		p.combat.set_action("idle")
		mouse(p,true)
		p.heavy_held = 0.6
		p.combat.set_action(next)
		check(p.heavy_held<0,"new action cancels held charge: "+next)
		p.combat.advance(2)
		mouse(p,false)
		check(p.combat.action=="idle","release after recovery does not throw: "+next)
	p.combat.set_action("idle")
	mouse(p,true)
	p.heavy_held = 0.6
	key(p,KEY_R)
	mouse(p,false)
	check(not p.combat.drawn and p.combat.action=="idle","sheathe cancels old charged release")
	mouse(p,true)
	p.heavy_held = 0.6
	key(p,KEY_ESCAPE)
	mouse(p,false)
	check(p.combat.action=="idle","mouse release cancels old charged release")
	mouse(p,true)
	p.heavy_held = 0.6
	p._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	mouse(p,false)
	check(p.combat.action=="idle","window focus loss cancels old charged release")
	p.combat.set_action("light")
	mouse(p,true)
	p.heavy_held = 0.5
	p.combat.advance(0.7)
	mouse(p,false)
	check(p.combat.action=="throw","charge begun during prior move survives its normal recovery")
	p.combat.set_action("throw")
	p.combat.elapsed = 0.38
	p.animate(0,0)
	mouse(p,true)
	p.heavy_held = 0.6
	p.on_strike(0)
	check(p.heavy_held<0,"weapon departure clears a second right-button hold begun during throw preparation")
	mouse(p,false)
	check(p.heavy_held<0,"release ignored during flight cannot preserve stale charge")
	print("THROW_INPUT_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
