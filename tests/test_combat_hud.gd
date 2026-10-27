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
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	var ui = world.combat_hud
	var c = p.combat
	c.health = 123
	c.stamina = 47
	c.shadow_lifetimes.assign([180.0,61.0,5.0])
	ui.update_state(p,2)
	check(ui.health.value==123 and ui.stamina.value==47,"resource bars reflect combat state")
	check(ui.health.position.y+ui.health.size.y<ui.stamina_text.position.y and ui.shadow_bars[0].position.y+ui.shadow_bars[0].size.y<ui.shadow_times[0].position.y,"resource bars do not overlap following labels")
	check(ui.shadow_times[0].text=="3:00" and ui.shadow_times[1].text=="1:01" and ui.shadow_times[2].text=="0:05","independent shadow lifetimes display")
	check(ui.shadow_times[3].text=="—" and ui.shadow_bars[3].value==0,"empty shadow slots stay empty")
	check("+30%" in ui.shadows.text,"shadow attack bonus is readable")
	check("idle" not in ui.status.text and "击退 2 / 5" in ui.status.text,"human-readable action and mission status")
	c.drawn = true
	c.guard_reward = 0.5
	ui.update_state(p,2)
	check("Ctrl 右手横扫" in ui.context.text,"successful guard shows next action")
	c.guard_reward = 0
	c.flash_window = 0.4
	ui.update_state(p,2)
	check("闪刺" not in ui.context.text,"retired flash window is not advertised")
	c.flash_window = 0
	c.set_action("reply")
	ui.update_state(p,2)
	check("右手横扫中" in ui.context.text and "命中获得" in ui.context.text,"counter sweep explains its actual reward condition")
	c.set_action("idle")
	p.heavy_held = 0.6
	ui.update_state(p,2)
	check(not ui.throw_charge.visible and not ui.throw_charge_text.visible,"retired throw charge never appears")
	check("投枪" not in ui.context.text and "投枪" not in ui.help.text and "瞬移" not in ui.help.text,"controls do not advertise retired throw")
	p.heavy_held = -1
	c.set_action("wait")
	c.elapsed = 12
	ui.update_state(p,2)
	check("18s" in ui.context.text and "Ctrl" in ui.context.text,"plant waiting time and input are readable")
	c.set_action("counter_window")
	ui.update_state(p,2)
	check("迎击架势" in ui.context.text,"counter stance has localized cue")
	p.lock_target = get_nodes_in_group("monsters")[0]
	ui.update_state(p,2)
	check(ui.target_health.visible and ui.target_health.value==p.lock_target.health,"locked target health is visible")
	check(p.lock_target.data.weakness in ui.target_text.text,"locked target weakness is visible")
	p.lock_target = null
	ui.update_state(p,2)
	check(not ui.target_health.visible and not ui.target_text.visible,"unlock removes stale target panel")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F1
	key.pressed = true
	ui._unhandled_key_input(key)
	check(ui.help.visible,"F1 opens control reference")
	key.echo = true
	ui._unhandled_key_input(key)
	check(ui.help.visible,"key repeat does not flicker help")
	key.echo = false
	ui._unhandled_key_input(key)
	check(not ui.help.visible,"F1 closes control reference")
	ui.update_state(p,5)
	check("林地已清理" in ui.status.text and "林地已清理" in ui.context.text,"victory replaces ordinary combat cue")
	c.health = 0
	ui.update_state(p,5)
	check("任务失败" in ui.status.text and "任务失败" in ui.context.text,"death has priority over victory")
	p.heavy_held = 0.6
	ui.update_state(p,5)
	check(not ui.throw_charge.visible,"failure hides stale held input")
	check(ui.surface.mouse_filter==Control.MOUSE_FILTER_IGNORE and ui.health.mouse_filter==Control.MOUSE_FILTER_IGNORE,"overlay does not capture combat mouse input")
	print("COMBAT_HUD_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
