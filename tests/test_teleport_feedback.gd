extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.yaw = 0
	p.rig.root.rotation = Vector3.ZERO
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	p.global_position = Vector3(0,0.05,-10)
	p.combat.drawn = true
	p.animate(0,0)
	await physics_frame
	var before: Transform3D = p.rig.root.global_transform
	var hp: float = p.combat.health
	var stamina: float = p.combat.stamina
	var original = p.rig.root.find_children("*","MeshInstance3D",true,false)[0].material_override
	p.finish_throw(Vector3(0,0,-13))
	var effects := get_nodes_in_group("teleport_feedback")
	check(effects.size()==1,"successful arrival creates exactly one effect")
	var effect = effects[0]
	effect.set_process(false)
	check(effect.departure.is_equal_approx(before),"departure preserves original world transform")
	check(effect.arrival.is_equal_approx(p.rig.root.global_transform),"arrival matches destination")
	check(effect.ghosts.size()==2 and effect.rings.size()==2,"two endpoint snapshots and rings")
	check(effect.find_children("*","CollisionObject3D",true,false).is_empty(),"effect has no collision objects")
	check(p.rig.root.find_children("*","MeshInstance3D",true,false)[0].material_override==original,"source material remains unchanged")
	var source_skeletons = p.rig.root.find_children("*","Skeleton3D",true,false)
	var cloned = effect.ghosts[0].find_children("*","Skeleton3D",true,false)
	var matching: bool = cloned.size()==source_skeletons.size() and not cloned.is_empty()
	for i in mini(cloned.size(),source_skeletons.size()):
		for bone in source_skeletons[i].get_bone_count():
			matching = matching and cloned[i].get_bone_pose(bone).is_equal_approx(source_skeletons[i].get_bone_pose(bone))
	check(matching,"snapshot preserves skeleton poses")
	var visible_parts := 0
	for mesh in p.rig.root.find_children("*","MeshInstance3D",true,false):
		if mesh.is_visible_in_tree(): visible_parts += 1
	var lean_snapshot := true
	for ghost in effect.ghosts:
		var meshes: Array = ghost.find_children("*","MeshInstance3D",true,false)
		lean_snapshot = lean_snapshot and meshes.size()==visible_parts
		for mesh in meshes:
			lean_snapshot = lean_snapshot and mesh.material_override==effect.material and mesh.material_overlay==null
			for property in mesh.get_property_list():
				if str(property.name).begins_with("instance_shader_parameters/"): lean_snapshot = false
	check(lean_snapshot,"snapshots retain only visible geometry and no original instance-shader parameters")
	check(p.combat.health==hp and p.combat.stamina==stamina,"presentation preserves combat resources")
	var ready_height: float = p.rig.root.position.y
	for tick in 3: p._physics_process(1.0/60)
	p.animate(0,0)
	check(p.rig.root.position.y<ready_height-0.06,"successful arrival bends knees to absorb the landing")
	check(p.combat.action=="idle" and p.combat.elapsed==0,"arrival presentation does not introduce an action lock")
	for side in [-1,1]:
		var sole: Vector3 = p.rig.legs[side].ankle.to_global(Vector3(0,-0.1,0))
		var probe := PhysicsRayQueryParameters3D.create(sole+Vector3.UP*0.5,sole-Vector3.UP*0.5,2)
		var ground: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(probe)
		check(not ground.is_empty() and sole.y>=ground.position.y-0.003,"arrival compression keeps the actual sole above the floor")
	check(p.combat.request("light") and p.arrival_pose_weight()==0,"arrival yields immediately to a legal follow-up attack")
	p.take_damage(10,p.global_position+Vector3.FORWARD*3,true)
	check(p.combat.health==hp-10 and p.combat.action=="hurt" and p.arrival_pose_weight()==0,"arrival pose grants no immunity and yields to actual hit reaction")
	p._physics_process(0.3)
	check(p.arrival_pose_left==0 and p.combat.elapsed>=0.29,"arrival timer expires without pausing the combat clock")
	p.finish_throw(Vector3(0,0,-18),false)
	check(get_nodes_in_group("teleport_feedback").size()==1,"cancelled arrival creates no effect")
	p.finish_throw(p.global_position)
	check(get_nodes_in_group("teleport_feedback").size()==1,"stationary return creates no effect")
	effect._process(0.175)
	check(effect.material.albedo_color.a<0.1 and effect.rings[0].scale.x>1,"effect fades and expands")
	effect._process(0.18)
	await process_frame
	await process_frame
	check(get_nodes_in_group("teleport_feedback").is_empty(),"effect cleans up after lifetime")
	print("TELEPORT_FEEDBACK_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
