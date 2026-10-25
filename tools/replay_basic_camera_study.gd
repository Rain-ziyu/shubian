extends SceneTree
## Normal combat clock and default player camera; frozen distant AI, not difficulty proof.
var world: Node3D
var fighter: CharacterBody3D
var elapsed := 0.0
var slot := 0
var captured := {}
var events: Array[Dictionary] = []
var finished := false
const REQUESTS := [{"at":0.30,"action":"light"},{"at":1.30,"action":"heavy"},{"at":2.50,"action":"pull"},{"at":3.60,"action":"turn"}]
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	fighter = world.hunter
	fighter.set_process_unhandled_input(false)
	if "--before" in OS.get_cmdline_user_args():
		fighter.camera.get_parent().spring_length = 5.8
		fighter.camera.get_parent().rotation.y = 0
		fighter.camera.rotation.y = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	await physics_frame
	await physics_frame
	physics_frame.connect(control)
func control() -> void:
	if finished: return
	elapsed += 1.0/60
	if slot<REQUESTS.size() and elapsed>=float(REQUESTS[slot].at):
		var action: String = REQUESTS[slot].action
		events.append({"action":action,"accepted":fighter.request_action(action)})
		slot += 1
	var action: String = fighter.combat.action
	var sample_time := 0.29 if action=="light" else 0.47
	if action in ["light","heavy"] and fighter.combat.elapsed>=sample_time and not captured.has(action):
		captured[action] = true
		capture.call_deferred(action)
	if elapsed>5.0:
		finished = true
		finish.call_deferred()
func capture(action: String) -> void:
	await RenderingServer.frame_post_draw
	var variant := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-player-camera-"+action+"-"+variant+".png"))
	var tip: Vector2 = fighter.camera.unproject_position(fighter.rig.weapon.get_node("TipContact").global_position)
	var base: Vector2 = fighter.camera.unproject_position(fighter.rig.weapon.get_node("HeadBaseContact").global_position)
	var back: Vector2 = fighter.camera.unproject_position(fighter.rig.torso.to_global(Vector3(0,0.2,0)))
	print("BASIC_CAMERA_MARKERS: ",JSON.stringify({"action":action,"variant":variant,"head_span_pixels":tip.distance_to(base),"tip_back_separation_pixels":tip.distance_to(back),"action_time":fighter.combat.elapsed}))

func finish() -> void:
	print("BASIC_CAMERA_STUDY: ",JSON.stringify({"events":events,"captures":captured.keys(),"scope":"default camera, normal requests and combat clock; other AI frozen; not difficulty acceptance"}))
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
