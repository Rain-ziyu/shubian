extends SceneTree
const Monster = preload("res://scripts/monster.gd")
const V = preload("res://scripts/visuals.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func minimum_height(m: Node3D) -> float:
	var lowest := INF
	for part in m.mesh.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB = part.get_aabb()
		for i in 8:
			var point: Vector3 = part.to_global(bounds.position+bounds.size*Vector3(i&1,(i>>1)&1,(i>>2)&1))
			lowest = minf(lowest,point.y)
	return lowest
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_mesh := V.piece(stage,Vector3(0,-0.2,0),Vector3(80,0.4,80),Color.GRAY)
	floor_mesh.create_trimesh_collision()
	floor_mesh.get_child(0).collision_layer = 2
	var species: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json")).species
	for entry in species:
		var m := Monster.new()
		m.data = entry
		stage.add_child(m)
		m.set_physics_process(false)
		m.global_position.y = 0.02
		m.CreatureModel.animate(m.mesh,m.data,0,"windup",0.6,0)
		m.health = 0
		for tick in 90:
			m._physics_process(1.0/60)
			await physics_frame
		check(m.is_on_floor(),str(entry.id)+" defeated capsule rests on actual floor")
		check(m.mesh.rotation.z>1.3,str(entry.id)+" defeated creature rolls onto its side")
		check(minimum_height(m)>-0.03,str(entry.id)+" side fall keeps authored mesh bounds above flat ground")
		check(m.collision_layer==0 and not m.tell.visible and not m.rear_tell.visible and not m.lunge_tell.visible,"defeated creature stops blocking and warning")
		m._physics_process(2)
		check(m.mesh.rotation.z>1.5 and minimum_height(m)>-0.03,"defeated pose persists after the normal recovery duration")
		m.queue_free()
		await process_frame
	print("CREATURE_DEFEAT_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
