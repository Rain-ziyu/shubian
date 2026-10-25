extends SceneTree
## Development entry point; packaged preview also supports --input-trace.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	if world.get_node_or_null("InputDiagnostics")==null:
		preload("res://scripts/input_diagnostics.gd").attach(world,world.hunter,"res://../verification/window-input")
