extends SceneTree
const Player = preload("res://scripts/player.gd")
const Monster = preload("res://scripts/monster.gd")
const TailSkin = preload("res://scripts/creature_tail_skin.gd")
var checks := 0
var failures := 0
var stage: Node3D
var hunter: CharacterBody3D
var confirmed: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func fire(origin: Vector3, direction: Vector3):
	var shot = hunter.Projectile.new()
	shot.shooter = hunter
	shot.direction = direction.normalized()
	hunter.projectile = shot
	stage.add_child(shot)
	shot.global_position = origin
	shot.set_physics_process(false)
	shot.cancel_arrival()
	for frame in 60:
		if shot.finished: break
		shot._physics_process(0.025)
	return shot
func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	hunter = Player.new()
	stage.add_child(hunter)
	hunter.set_physics_process(false)
	hunter.set_process_unhandled_input(false)
	hunter.global_position = Vector3(30,0,30)
	hunter.hit_confirmed.connect(func(action: String, _beat: int, _target: Node3D, result: Dictionary): confirmed.append(action+":"+str(result.part)))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	var monsters := {}
	for species in data.species:
		var creature := Monster.new()
		creature.data = species
		stage.add_child(creature)
		creature.set_physics_process(false)
		creature.position = Vector3(50,0,0)
		monsters[species.id] = creature
	await physics_frame
	await physics_frame
	var mist = monsters.mistfrill
	mist.position = Vector3.ZERO
	mist.phase = "windup"
	mist.CreatureModel.animate(mist.mesh,mist.data,0,"windup",0.5,0)
	mist.update_weak_markers()
	await physics_frame
	var head: Vector3 = mist.mesh.get_node("Neck").to_global(Vector3(0,mist.data.size*0.14,-mist.data.size*0.42))
	var query := PhysicsRayQueryParameters3D.create(head+Vector3.FORWARD*4,head)
	check(stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"visible head lies outside the old body capsule ray")
	var health: float = mist.health
	var shot = fire(head+Vector3.FORWARD*4,Vector3.BACK)
	check(shot.remaining>10 and mist.health<health and mist.stagger>0,"actual projectile hits the protruding head and interrupts mist windup")
	check(is_equal_approx(health-mist.health,72),"head surface applies promised weakpoint damage")
	health = mist.health
	shot = fire(Vector3(0,0.25,-4),Vector3.BACK)
	check(mist.health==health and shot.remaining<=0,"projectile through empty space between legs is not a body hit")
	mist.position = Vector3(50,0,0)
	var reed = monsters.reedclaw
	reed.position = Vector3.ZERO
	reed.CreatureModel.animate(reed.mesh,reed.data,1.8,"idle",0,0)
	var tail: Node3D = reed.mesh.get_node("Tail")
	var rings: Array[Vector4] = TailSkin.contact_profile(tail,reed.tail_rings)
	var ring := rings[-4]
	var tail_point := tail.to_global(Vector3(ring.w,ring.y,ring.x))
	health = reed.health
	shot = fire(tail_point+Vector3.RIGHT*2,Vector3.LEFT)
	check(shot.remaining>10 and reed.health<health,"projectile hits the posed long tail outside the body capsule")
	check(is_equal_approx(health-reed.health,36),"distal tail does not inherit the tail-root weakness")
	reed.position = Vector3(50,0,0)
	var storm = monsters.stormcrest
	storm.position = Vector3.ZERO
	storm.phase = "windup"
	storm.CreatureModel.animate(storm.mesh,storm.data,0,"windup",0.1,0)
	var spine: Vector3 = storm.mesh.get_node("Crest2").to_global(Vector3(0,storm.data.size*0.35,storm.data.size*0.015))
	health = storm.health
	shot = fire(spine+Vector3.RIGHT*2,Vector3.LEFT)
	check(shot.remaining>10 and is_equal_approx(health-storm.health,72) and storm.disrupted==36,"visible high spine receives actual projectile weakpoint contact")
	hunter.global_position = Vector3(8,0,spine.z)
	hunter.yaw = PI/2
	hunter.pitch = -0.25
	hunter.combat.set_action("throw")
	hunter.combat.elapsed = 0.38
	hunter.animate(0,0)
	var aim: Vector3 = spine-hunter.rig.weapon.global_position
	var pitch := atan2(aim.y,Vector2(aim.x,aim.z).length())-0.25
	hunter.apply_look(Vector2(0,-(pitch-hunter.pitch)/0.0025))
	health = storm.health
	hunter.on_strike(0)
	shot = hunter.projectile
	shot.set_physics_process(false)
	shot.cancel_arrival()
	for frame in 60:
		if shot.finished: break
		shot._physics_process(0.025)
	check(is_equal_approx(health-storm.health,72),"normal aimed release can physically reach the visible high spine")
	var wall := StaticBody3D.new()
	wall.position = spine+Vector3.RIGHT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2,3,3)
	shape.shape = box
	wall.add_child(shape)
	stage.add_child(wall)
	await physics_frame
	await physics_frame
	health = storm.health
	shot = fire(spine+Vector3.RIGHT*2,Vector3.LEFT)
	check(storm.health==health and shot.finished and shot.global_position.x>0.8,"world wall wins before a farther visible weakpoint")
	check(confirmed==["throw:head","throw:tail_tip","throw:spine","throw:spine"],"only actual projectile contacts emit one correctly classified confirmation")
	print("PROJECTILE_PART_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
