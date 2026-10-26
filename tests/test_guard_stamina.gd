extends SceneTree
const Combat = preload("res://scripts/combat/trident_combat.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c = Combat.new()
	c.stamina = 30
	c.request("guard")
	c.advance(0.2)
	check(c.stamina==30,"guard stance does not regenerate stamina")
	check(c.receive_damage(40)=="guarded" and c.stamina==15,"successful block retains fifteen stamina cost")
	c.advance(0.4)
	check(c.stamina==15,"remaining guard time does not refund block cost")
	check(c.receive_damage(40)=="guarded" and c.stamina==0,"multiple incoming hits pay separate block costs")
	c.advance(0.2)
	check(c.stamina==0,"empty guard stamina stays empty")
	check(c.request("reply"),"earned reply remains available at zero stamina")
	check(c.receive_damage(40)=="immune" and c.health==240,"successful reply keeps required damage immunity")
	c.confirm_hit()
	check(c.shadow_lifetimes.size()==1 and c.flash_window==0,"counter sweep contact directly grants intent without a flash followup")
	var exhausted = Combat.new()
	exhausted.stamina = 10
	exhausted.request("guard")
	exhausted.advance(0.2)
	check(exhausted.receive_damage(40)=="hurt" and exhausted.health==200,"insufficient stamina lets an attack break guard")
	check(exhausted.stamina==10 and exhausted.guard_reward==0,"failed guard grants no reward or negative stamina")
	exhausted.advance(0.55)
	var recovering: float = exhausted.stamina
	exhausted.advance(1)
	check(is_equal_approx(exhausted.stamina-recovering,18),"idle recovery remains eighteen per second")
	check(exhausted.request("dodge") and exhausted.stamina<recovering,"movement recovery can restore a dodge")
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.yaw = 0
	p.rig.root.rotation = Vector3.ZERO
	p.combat.health = 240
	p.combat.stamina = 10
	p.combat.set_action("guard")
	p.combat.elapsed = 0.2
	p.take_damage(40,p.global_position+Vector3.FORWARD*2,true)
	check("耐力不足" in p.message and p.combat.action=="hurt","real guard failure explains stamina exhaustion")
	for setup in [[100.0,true,0.2,Vector3.BACK],[10.0,false,0.2,Vector3.FORWARD],[10.0,true,0.05,Vector3.FORWARD]]:
		p.combat.health = 240
		p.combat.stamina = setup[0]
		p.combat.set_action("guard")
		p.combat.elapsed = setup[2]
		p.take_damage(40,p.global_position+setup[3]*2,setup[1])
		check(not "耐力不足" in p.message,"rear, unblockable and startup damage are not mislabeled as exhaustion")
	p.combat.set_action("guard")
	p.combat.stamina = 10
	p.combat.guard_reward = 0
	world.combat_hud.update_state(p,0)
	check("耐力不足" in world.combat_hud.context.text,"guard HUD warns before next failed block")
	p.combat.guard_reward = 0.8
	world.combat_hud.update_state(p,0)
	check("Ctrl 右手横扫" in world.combat_hud.context.text,"earned reply prompt has priority over low stamina warning")
	print("GUARD_STAMINA_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
