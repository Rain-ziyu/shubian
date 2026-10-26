extends "res://tools/probe_shoulder_intersections.gd"
func prepare_player(player: CharacterBody3D) -> void:
	include_joints = true
	preload("res://tools/prepare_segmented_mantle.gd").apply(player)
