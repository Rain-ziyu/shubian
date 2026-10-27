extends Node3D
const Visuals = preload("res://scripts/visuals.gd")
const Contact = preload("res://scripts/monster_projectile_contact.gd")
var contact = Contact.new()
var shooter: CharacterBody3D
var direction := Vector3.FORWARD
var speed := 27.0
var remaining := 16.0
var amount := 36.0
var finished := false
var arrival_cancelled := false
var visual: Node3D

func _ready() -> void:
	if is_instance_valid(shooter) and shooter.get_meta("measure_frame_cost",false): set_meta("measure_frame_cost",true)
	visual = Visuals.trident(self)
	visual.rotation.x = -PI/2
	look_at(global_position+direction)
	add_to_group("projectiles")

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec() if get_meta("measure_frame_cost",false) else 0
	advance_flight(delta)
	if started and is_instance_valid(shooter): shooter.set_meta("projectile_cost_total_us",int(shooter.get_meta("projectile_cost_total_us",0))+Time.get_ticks_usec()-started)

func advance_flight(delta: float) -> void:
	if finished: return
	if not is_instance_valid(shooter):
		finished = true
		queue_free()
		return
	var distance := minf(remaining,speed*delta)
	var end := global_position+direction*distance
	var query := PhysicsRayQueryParameters3D.create(global_position,end)
	# Movement-only anatomy blockers must not replace exact skin contact tests.
	query.collision_mask = 3
	if is_instance_valid(shooter): query.exclude = [shooter.get_rid()]
	var creatures := get_tree().get_nodes_in_group("monsters")
	var excluded := query.exclude
	for creature in creatures: excluded.append(creature.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var limit := global_position.distance_to(hit.position) if not hit.is_empty() else distance+0.0001
	var victim: Node3D
	var part := ""
	for creature in creatures:
		if creature.health<=0 or creature.collision_layer==0: continue
		var surface: Dictionary = contact.cast(creature,global_position,end)
		if surface.is_empty() or float(surface.distance)>=limit: continue
		limit = float(surface.distance)
		victim = creature
		part = str(surface.part)
		hit = {"position":surface.point,"collider":creature}
	if not hit.is_empty():
		var impact_origin := global_position
		global_position = hit.position
		if hit.collider.has_method("receive_strike"):
			if victim==null: part = preload("res://scripts/monster_parts.gd").at_point(hit.collider,hit.position)
			var result: Dictionary = hit.collider.receive_strike(amount,impact_origin,"throw",part)
			shooter.show_hit_feedback(hit.position,result,"throw")
			if result.get("hit",false): shooter.hit_confirmed.emit("throw",0,hit.collider,result)
		finish()
		return
	global_position = end
	remaining -= distance
	if remaining<=0: finish()

func cancel_arrival() -> void:
	arrival_cancelled = true

func finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(shooter) and shooter.projectile==self: shooter.finish_throw(global_position-direction*0.6,not arrival_cancelled)
	queue_free()
