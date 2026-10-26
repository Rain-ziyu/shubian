extends "res://tests/test_counter_cloth.gd"
func prepare_player(player: CharacterBody3D) -> void:
	preload("res://tools/prepare_segmented_mantle.gd").apply(player)
