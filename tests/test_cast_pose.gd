extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func cue(model: Node3D, data: Dictionary) -> float:
	if data.pattern=="mist": return model.get_node("Neck/Frill").scale.x-1
	var material: StandardMaterial3D = model.get_node("Crest0").material_override
	# Warm light is the interrupted open-spine state, not residual charging.
	return material.emission_energy_multiplier if material.emission.b>=material.emission.r else 0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for data in database.species:
		if data.pattern not in ["mist","pulse"]: continue
		var model := Model.create(holder,data)
		var neck: Node3D = model.get_node("Neck")
		Model.animate(model,data,0,"windup",0,0)
		var empty := cue(model,data)
		Model.animate(model,data,0,"windup",data.windup*0.5,0)
		var partial := cue(model,data)
		Model.animate(model,data,0,"windup",data.windup,0)
		var full := cue(model,data)
		check(empty<partial and partial<full,"charge cue builds progressively: "+str(data.id))
		if data.pattern=="pulse":
			var body: MeshInstance3D = model.get_node("BodySurface")
			var lowest := INF
			for vertex in body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				lowest = minf(lowest,body.to_global(vertex).y)
			check(lowest>=0,"deep pulse anticipation keeps visible belly above flat ground")
		var loaded_body := model.transform
		var loaded_neck := neck.transform
		Model.animate(model,data,0,"active",0,0)
		check(loaded_body.is_equal_approx(model.transform) and loaded_neck.is_equal_approx(neck.transform),"cast starts without body or neck phase snap")
		check(is_equal_approx(cue(model,data),full),"frill or crest joins release without instant reset")
		Model.animate(model,data,0,"active",0.25,0)
		check(cue(model,data)>0 and cue(model,data)<full,"charge cue discharges progressively")
		Model.animate(model,data,0,"active",0.65,0)
		var end_body := model.transform
		var end_neck := neck.transform
		Model.animate(model,data,0,"recover",0,0)
		check(end_body.is_equal_approx(model.transform) and end_neck.is_equal_approx(neck.transform),"cast release joins recovery continuously")
		check(absf(cue(model,data))<0.0001,"recovery has no charging cue")
		Model.animate(model,data,0,"recover",data.recovery,0)
		check(absf(neck.rotation.x)<0.001 and absf(model.position.y)<0.001,"body and neck return to neutral")
		var other := Model.create(holder,data)
		Model.charge_visuals(model,data,"windup",data.windup)
		Model.charge_visuals(other,data,"idle",0)
		check(is_equal_approx(cue(model,data),full),"cue materials are isolated between creatures")
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.hunter.set_physics_process(false)
	for monster in get_nodes_in_group("monsters"):
		monster.set_physics_process(false)
		if monster.data.pattern not in ["mist","pulse"]: continue
		monster.phase = "windup"
		monster.clock = monster.data.windup*0.8
		Model.animate(monster.mesh,monster.data,0,"windup",monster.clock,0)
		check(cue(monster.mesh,monster.data)>0,"live windup exposes visual cue")
		monster.receive_strike(100,monster.global_position+Vector3(4,0,0),"light","head" if monster.data.pattern=="mist" else "spine")
		monster._physics_process(1.0/60)
		check(monster.stagger>0 and absf(cue(monster.mesh,monster.data))<0.0001,"weakpoint interruption cancels charging cue immediately")
		if monster.data.pattern=="pulse":
			var exposed: StandardMaterial3D = monster.mesh.get_node("Crest0").material_override
			check(monster.weak_part_active("spine") and exposed.emission.r>exposed.emission.b and exposed.emission_energy_multiplier>0,"cancelled charge retains a distinct warm open-spine cue")
		check(get_nodes_in_group("hazards").is_empty(),"interrupted windup does not spawn attack hazard")
		Model.charge_visuals(monster.mesh,monster.data,"windup",monster.data.windup)
		monster.health = 0
		monster._physics_process(1.0/60)
		check(absf(cue(monster.mesh,monster.data))<0.0001,"death cancels charging cue")
	print("CAST_POSE_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
