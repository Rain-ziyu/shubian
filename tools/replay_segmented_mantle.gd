extends "res://tests/replay_input_sequence.gd"
## Same live input controller, using only the optional segmented costume study.
func setup() -> void:
	await super.setup()
	preload("res://tools/prepare_segmented_mantle.gd").apply(fighter,true)
	fighter.animate(0,0)
