extends SceneTree
const Feedback = preload("res://scripts/hit_feedback.gd")
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
	p.set_process(false)
	var monsters := get_nodes_in_group("monsters")
	for creature in monsters:
		creature.set_physics_process(false)
		creature.set_process(false)
	var m = monsters[0]
	p.global_position = Vector3.ZERO
	p.rig.root.rotation.y = 0
	m.global_position = Vector3(0,0,-2)
	m.rotation.y = PI/2
	p.combat.set_action("light")
	p.combat.elapsed = 0.25
	p.animate(0,0)
	p.on_strike(0)
	p.update_weapon_contacts()
	var effects := get_nodes_in_group("hit_feedback")
	check(effects.size()==1,"actual contact spawns exactly one feedback effect")
	if effects.is_empty(): quit(1); return
	var effect = effects[0]
	effect.set_process(false)
	check(not effect.weak and effect.number.text==str(roundi(effect.damage)),"ordinary contact has ordinary damage number")
	check(m.impact_meshes[0].material_overlay!=null,"contact highlights monster without replacing base material")
	var elapsed: float = p.combat.elapsed
	var hp: float = p.combat.health
	var monster_hp: float = m.health
	var phase: String = m.phase
	effect.advance_visual(0.1)
	p._process(0.08)
	m._process(0.08)
	check(p.combat.elapsed==elapsed and p.combat.health==hp and m.health==monster_hp and m.phase==phase,"visual advancement does not alter combat clock health or phase")
	check(absf(p.camera.h_offset)<=0.04 and absf(p.camera.v_offset)<=0.04,"camera impact stays within small optical offset")
	p._process(0.3)
	check(is_zero_approx(p.camera.h_offset) and is_zero_approx(p.camera.v_offset),"camera returns to neutral")
	m._process(0.3)
	check(m.impact_meshes[0].material_overlay==null,"monster flash overlay clears")
	p.update_weapon_contacts()
	check(get_nodes_in_group("hit_feedback").size()==1,"same beat does not repeat feedback")
	effect.advance_visual(0.6)
	await process_frame
	check(not is_instance_valid(effect),"short-lived effect cleans up after expiry")
	m.stagger = 0
	m.receive_strike(10,p.global_position,"fourfold","body")
	check(m.stagger==0,"feedback does not give fourfold mechanical stagger")
	var weak: Dictionary = m.receive_strike(10,p.global_position,"light","tail")
	p.show_hit_feedback(Vector3(0,2,-2),weak)
	var gold = get_nodes_in_group("hit_feedback")[0]
	check(gold.weak and gold.number.text.begins_with("弱点"),"weak point contact is explicitly identified")
	check(gold.global_position==Vector3(0,2,-2),"feedback is placed at contact")
	check(Feedback.impact_force("heavy",false)>Feedback.impact_force("light",false),"heavy contact has stronger visual impulse than light")
	check(Feedback.impact_force("fourfold",false)<Feedback.impact_force("light",false),"rapid fourfold beats stay compact")
	check(gold.force>Feedback.impact_force("light",false),"weak point amplifies the contact impulse")
	p.camera.global_rotation = Vector3(0.2,PI/2,0)
	gold.advance_visual(0)
	check(gold.sparks.global_basis.is_equal_approx(p.camera.global_basis.orthonormalized()),"side camera sees the full spark plane")
	p.camera.global_rotation = Vector3(-0.1,-PI/3,0)
	gold.advance_visual(0)
	check(gold.sparks.global_basis.is_equal_approx(p.camera.global_basis.orthonormalized()),"spark plane follows a changed camera angle")
	var normal_audio := Feedback.synthesize(false)
	var weak_audio := Feedback.synthesize(true)
	check(normal_audio.data.size()>4000 and weak_audio.data.size()>normal_audio.data.size(),"two nonempty PCM sounds are generated")
	check(normal_audio.data.decode_s16(0)==0 and abs(normal_audio.data.decode_s16(normal_audio.data.size()-2))<4,"sound envelope starts and ends quietly")
	var silent := Feedback.new()
	silent.audio_enabled = false
	world.add_child(silent)
	var played := false
	for child in silent.get_children():
		if child is AudioStreamPlayer3D: played = played or child.playing
	check(not played,"preparation can draw feedback without playing its impact sound")
	print("HIT_FEEDBACK_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
