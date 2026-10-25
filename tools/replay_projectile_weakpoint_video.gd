extends "res://tests/replay_encounter.gd"
## One aimed throw against a live AI; other enemies are frozen by the base fixture.
## No injected phases, health, resources, damage or hit confirmations. Not a victory test.
var pressed := false
var released := false
var weak_hit := false
var hit_part := ""
var initial_epoch := 0
var launch_seen := false
func setup() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Projectile weakpoint video requires native rendering")
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await super.setup()
	fighter.global_position = monster.global_position+Vector3(4.5,0.05,0)
	fighter.velocity = Vector3.ZERO
	fighter.lock_target = null
	fighter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	initial_epoch = fighter.motion_epoch
	fighter.hit_confirmed.connect(on_projectile_hit)
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var label := Label.new()
	label.position = Vector2(24,110)
	label.text = "戍边 / 单次投枪实测\n巨兽正常攻击 · 鼠标瞄准高处背棘 · 非通关演示"
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
func button(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	fighter._unhandled_input(event)
func control() -> void:
	if result_saved: return
	elapsed += 1.0/60
	var target: Vector3 = monster.mesh.get_node("Crest2").to_global(Vector3(0,monster.data.size*0.35,monster.data.size*0.015))
	var delta: Vector3 = target-fighter.rig.weapon.global_position
	var facing: Vector3 = target-fighter.global_position
	var heading := atan2(-facing.x,-facing.z)
	var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())-0.25
	fighter.apply_look(Vector2(-wrapf(heading-fighter.yaw,-PI,PI)/0.003,-(pitch-fighter.pitch)/0.0025))
	if is_instance_valid(fighter.projectile) and not launch_seen:
		launch_seen = true
		print("AIMED_THROW_LAUNCH: ",JSON.stringify({"from":fighter.projectile.global_position,"direction":fighter.projectile.direction,"target":target,"yaw":fighter.yaw,"body_yaw":fighter.rig.root.rotation.y,"pitch":fighter.pitch}))
	if elapsed>=0.10 and not pressed:
		pressed = true
		button(true)
	if elapsed>=0.65 and not released:
		released = true
		button(false)
	if elapsed>=3.2 or fighter.combat.health<=0:
		result_saved = true
		finish_probe.call_deferred()
func on_projectile_hit(action: String, _beat: int, target: Node3D, result: Dictionary) -> void:
	if action!="throw" or target!=monster: return
	hit_part = str(result.part)
	weak_hit = result.weak and result.part=="spine"
	print("AIMED_THROW_CONTACT: ",JSON.stringify(result))
	capture.call_deferred()
func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-live-projectile-spine.png"))
func finish_probe() -> void:
	var passed: bool = weak_hit and fighter.combat.health>0
	print("PROJECTILE_WEAKPOINT_REPLAY: ",JSON.stringify({"passed":passed,"part":hit_part,"weak":weak_hit,"player_health":fighter.combat.health,"monster_health":monster.health,"arrival":fighter.motion_epoch>initial_epoch,"scope":"one aimed held-button throw against live AI; other enemies frozen; no phase or resource injection; not a victory or difficulty test"}))
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if passed else 1)
