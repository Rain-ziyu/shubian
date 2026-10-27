extends SceneTree
## Export one known species without rewriting the other four assets.
func _initialize() -> void:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--species="): requested = argument.trim_prefix("--species=")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in data.species:
		if str(species.id)!=requested: continue
		var holder := Node3D.new()
		var model := preload("res://scripts/creature_model.gd").create(holder,species)
		owners(model,model)
		var scene := PackedScene.new()
		var error := scene.pack(model)
		if error==OK: error=ResourceSaver.save(scene,"res://assets/models/"+requested+"-v1.tscn")
		print("CREATURE_EXPORT: ",requested," result=",error)
		holder.free()
		quit(0 if error==OK else 1)
		return
	printerr("Pass --species= followed by a known monsters.json species id")
	quit(2)

func owners(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		owners(child,owner_node)
