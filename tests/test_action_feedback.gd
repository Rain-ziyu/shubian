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
	var c = p.combat
	var f = p.feedback
	var ui = world.combat_hud
	check(p.request_action("light") and "斜刺已发动" in f.text,"accepted request acknowledges actual action")
	check(not p.request_action("light") and "不能连发" in f.text,"repeated ordinary input explains rejection")
	c.advance(0.20)
	check(not p.request_action("heavy") and "预输入横扫" in f.text,"queued input is distinguished from immediate start")
	c.advance(0.18)
	check(c.action=="heavy" and "横扫已发动" in f.text,"buffer acknowledgement is replaced when queued action actually starts")
	ui.update_state(p,0)
	check(ui.action_phase.visible and "准备出招" in ui.action_phase.text,"center cue identifies windup")
	c.elapsed = 0.43
	ui.update_state(p,0)
	check("攻击生效" in ui.action_phase.text and absf(ui.action_progress.value-0.43)<0.001,"phase and progress follow authoritative attack clock")
	c.elapsed = 0.60
	ui.update_state(p,0)
	check("可衔接" in ui.action_phase.text,"legal followup window is shown")
	var before: float = c.health
	p.take_damage(10,p.global_position+Vector3.FORWARD,false)
	check(c.action=="hurt" and c.health==before-10 and "横扫被打断" in f.text,"real damage names the interrupted move")
	check(f.hurt_flash>0,"interruption drives a short character impact flash")
	c.advance(0.08)
	p.animate(0,0)
	check(p.rig.weapon.position.y<1.06 and p.rig.torso.rotation.x>0.2 and p.rig.root.position.z>0.05,"interruption also lowers the weapon and recoils the whole body")
	c.advance(0.56)
	f.advance(0.56)
	p.request_action("light")
	ui.update_state(p,0)
	check("横扫被打断" in ui.action_event.text and "斜刺" in ui.action_phase.text,"interruption remains readable while the next move starts")
	f.advance(0.7)
	ui.update_state(p,0)
	check(not ui.action_event.visible and f.hurt_flash==0,"transient notice and flash expire without stale state")
	c.set_action("idle")
	c.shadow_lifetimes.assign([180.0])
	p.request_action("spin")
	p.take_damage(10,p.global_position+Vector3.FORWARD,false)
	check(c.action=="spin" and "动作继续" in f.text and f.hurt_flash==0,"armored damage is distinguished from an interruption")
	f.advance(2)
	c.set_action("idle")
	check(not p.request_action("fourfold") and "枪影不足" in f.text,"resource failure is actionable")
	p.request_action("light")
	c.advance(0.20)
	check(not p.request_action("fourfold") and "预输入" in f.text,"resource combo can be buffered before its legal link")
	c.advance(0.18)
	check(c.action=="light" and c.shadow_lifetimes.is_empty() and "枪影不足" in f.text,"failed buffered combo replaces the stale queued notice with its actual reason")
	c.stamina = 0
	check(not p.request_action("dodge") and "耐力不足" in f.text,"dodge failure explains missing stamina")
	c.set_action("fourfold")
	c.elapsed = 0.43
	ui.update_state(p,0)
	check("第 2 段" in ui.action_phase.text,"multi-hit moves expose the actual current beat")
	f.strike_outcome("flash",true,3)
	check("闪刺命中" in f.text and "3/5" in f.text,"confirmed flash shows the actual shadow count")
	f.action_changed("hurt")
	f.strike_outcome("reply",false)
	check("被打断" in f.text,"late outcome cannot overwrite an interruption")
	ui.update_state(p,5)
	check(not ui.action_event.visible and not ui.action_progress.visible,"victory clears active combat presentation")
	check(ui.action_event.mouse_filter==Control.MOUSE_FILTER_IGNORE and ui.action_progress.mouse_filter==Control.MOUSE_FILTER_IGNORE,"new cues preserve combat input routing")
	print("ACTION_FEEDBACK_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
