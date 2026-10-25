extends "res://tools/replay_throw_study.gd"
## Real held-button/projectile handling against a frozen model, not a live fight.
var target_model: CharacterBody3D
var contacts := 0
var initial_epoch := 0
var captured_return := false
func setup() -> void:
	await super.setup()
	target_model = get_nodes_in_group("monsters")[0]
	target_model.show()
	target_model.collision_layer = 1
	target_model.global_position = Vector3(0,0.05,-16)
	target_model.rotation = Vector3.ZERO
	target_model.CreatureModel.animate(target_model.mesh,target_model.data,0,"idle",0,0)
	target_model.label.hide()
	for marker in target_model.weak_markers: marker.hide()
	initial_epoch = fighter.motion_epoch
	fighter.hit_confirmed.connect(func(action: String, _beat: int, target: Node3D, _result: Dictionary):
		if action=="throw" and target==target_model: contacts += 1
	)
func step() -> void:
	super.step()
	if finished: return
	study_camera.position = fighter.global_position+Vector3(4.5,3,5)
	study_camera.look_at(fighter.global_position+Vector3(0,1,-2))
	study_camera.fov = 38
	title.text = "戍边 / 近距离投枪回收检查（固定模型，非实战）\n右键长按投出 · 命中保留伤害 · 过近落点不位移\n"+fighter.message
	if contacts>0 and fighter.projectile==null and fighter.rig.weapon.visible and not captured_return:
		captured_return = true
		capture_return.call_deferred()
func capture_return() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-close-throw-return.png"))
func finish() -> void:
	var horizontal := Vector2(fighter.global_position.x-origin.x,fighter.global_position.z-origin.z).length()
	var passed: bool = throw_seen and contacts==1 and captured_return and horizontal<0.001 and fighter.motion_epoch==initial_epoch and fighter.projectile==null
	print("CLOSE_THROW_STUDY: ",JSON.stringify({"passed":passed,"contacts":contacts,"horizontal_movement":horizontal,"weapon_return_visible":captured_return,"scope":"frozen target, actual held-button handler and physical projectile; not live AI or difficulty acceptance"}))
	world.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if passed else 1)
