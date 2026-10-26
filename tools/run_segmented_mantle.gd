extends SceneTree
## Interactive costume study; leaves the configured game/model untouched.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: CharacterBody3D = world.hunter
	preload("res://tools/prepare_segmented_mantle.gd").apply(player,true)
	player.animate(0,0)
	await physics_frame
	print("SEGMENTED_MANTLE_PREVIEW_READY: optional study, not accepted final art")
	if "--study-smoke" in OS.get_cmdline_user_args():
		await physics_frame
		await process_frame
		quit()
