extends SceneTree
class CountingContact:
	extends "res://scripts/monster_projectile_contact.gd"
	var builds := 0
	func fitted_volumes(monster: Node3D) -> Array[Dictionary]:
		builds += 1
		return super.fitted_volumes(monster)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	world.hunter.set_physics_process(false)
	world.hunter.set_process_input(false)
	world.hunter.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for monster in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	await physics_frame
	await physics_frame
	var plain := CountingContact.new()
	var batched := CountingContact.new()
	var seen := {}
	var queries := 0
	var plain_us := 0
	var batched_us := 0
	for monster: CharacterBody3D in get_nodes_in_group("monsters"):
		for pose in [["idle",0.0],["windup",float(monster.data.windup)*0.75],["active",0.25],["recover",0.10]]:
			monster.CreatureModel.animate(monster.mesh,monster.data,0,pose[0],pose[1],0)
			var s: float = monster.data.size
			var volumes: Array[Dictionary] = monster.Parts.volumes(monster)
			var leg: Node3D = monster.mesh.get_node("Hind1")
			var bones: Skeleton3D = leg.get_node("LegSkeleton")
			var anchors: Array[Vector3] = [volumes[0].center,monster.mesh.get_node("BodySurface").to_global(monster.mesh.get_node("BodySurface").mesh.get_aabb().get_center()),monster.mesh.get_node("Tail").to_global(Vector3(0,0,s*0.6)),bones.to_global(bones.get_bone_global_pose(1).origin),bones.to_global(bones.get_bone_global_pose(2).origin)]
			var batch := {}
			var before := batched.builds
			var same := true
			for center in anchors:
				for radius in [0.0,0.075,0.16]:
					var start := center+Vector3(s*1.5,0,0)
					var began := Time.get_ticks_usec()
					var expected := plain.cast(monster,start,center,radius)
					plain_us += Time.get_ticks_usec()-began
					began = Time.get_ticks_usec()
					var actual := batched.cast(monster,start,center,radius,batch)
					batched_us += Time.get_ticks_usec()-began
					same = same and actual==expected
					if not actual.is_empty(): seen[actual.part] = true
					queries += 1
			check(same,"all hit fields match fresh casts for "+str(monster.data.id)+" / "+str(pose))
			check(batched.builds-before==1,"one posed volume build per explicit target/pose batch")
	check(seen.has("head") and seen.has("limb") and (seen.has("tail") or seen.has("tail_tip")),"equivalence queries exercise head, posed limbs and tail contacts")
	check(plain.builds==queries and batched.builds==20,"fresh casts rebuild while each new pose batch gets a fresh snapshot")
	print("CONTACT_BATCH_MEASURE: queries=",queries," plain_builds=",plain.builds," batch_builds=",batched.builds," plain_ms=",plain_us/1000.0," batch_ms=",batched_us/1000.0," parts=",seen.keys())
	print("CONTACT_BATCH_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
