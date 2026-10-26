extends RefCounted
const Model = preload("res://scripts/hunter_model.gd")
static func apply(p: CharacterBody3D, restore_visibility := false) -> void:
	# Rebuild only the study model. Runtime visibility owns old rendered instances.
	p.get_node("OcclusionVisibility").free()
	for ghost in p.ghosts: ghost.reparent(p.get_parent())
	p.rig.skinning.skeleton.free()
	p.rig.erase("skinning")
	Model.pose_arms(p.rig,false,0)
	preload("res://scripts/hunter_mantle.gd").apply(p.rig)
	p.rig.skinning = Model.Skinning.bind(p.rig)
	p.rig.elbow_continuity = true
	p.rig.shaft_clearance = true
	for ghost in p.ghosts: ghost.reparent(p.rig.root)
	if restore_visibility:
		var visibility := preload("res://scripts/hunter_visibility.gd").new()
		visibility.name = "OcclusionVisibility"
		p.add_child(visibility)
