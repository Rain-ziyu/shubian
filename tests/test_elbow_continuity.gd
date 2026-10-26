extends SceneTree

const Solver = preload("res://scripts/hunter_arm_clearance.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# A pole direction can flip near full extension. Transport the previous
	# elbow without changing the fixed shoulder, wrist or bone length.
	var shoulder := Vector3.ZERO
	var wrist := Vector3(0,0.6,0)
	var height := sqrt(0.39*0.39-0.3*0.3)
	var middle := wrist*0.5
	for fps in [30,60,120]:
		var delta: float = 1.0/fps
		var previous := middle+Vector3.RIGHT*height
		var pole := Solver.solve(shoulder,wrist,Vector3.LEFT,height,Transform3D.IDENTITY,1,previous,delta,false)
		check(pole.dot(Vector3.RIGHT)>0.999,"A preferred pole reversal must not flip the elbow")
		check(absf((middle+pole*height).distance_to(shoulder)-0.39)<0.00001,"Upper arm length stays fixed")
		check(absf((middle+pole*height).distance_to(wrist)-0.39)<0.00001,"Forearm length stays fixed")
		# Put the shaft on the previous elbow to exercise the avoidance path.
		var weapon := Transform3D(Basis.IDENTITY,previous)
		var avoided := Solver.solve(shoulder,wrist,Vector3.RIGHT,height,weapon,1,previous,delta,true)
		check(pole.angle_to(avoided)<=8.0*delta+0.0001,"Avoidance respects the angular speed limit")
	var authored := Solver.solve(shoulder,wrist,Vector3.LEFT,height,Transform3D.IDENTITY,1,middle+Vector3.RIGHT*height,0,false)
	check(authored.is_equal_approx(Vector3.LEFT),"Zero-delta authored sampling is deterministic")
	var stage := Node3D.new()
	root.add_child(stage)
	var player := preload("res://scripts/player.gd").new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	preload("res://tools/prepare_segmented_mantle.gd").apply(player)
	player.combat.drawn = true
	player.pitch = -0.25
	for action in ["pull","reply","guard","turn"]:
		var legacy := peak_step(player,action,false)
		var continuous := peak_step(player,action,true)
		print("ELBOW_ACTION_STEP: ",action," legacy=",legacy," continuous=",continuous)
		check(continuous<0.12,action+" stays below 12 cm per 120Hz sample")
		check(continuous<=legacy*(1.1 if action=="guard" else (0.4 if action=="turn" else 0.3)),action+" improves the elbow path without degrading guard")
	player.combat.set_action("turn")
	player.combat.elapsed = 0.40
	player.animate(0,0)
	var tail_grip: Vector3 = player.rig.weapon.transform*Vector3(0,-0.28,0)
	var guide_grip: Vector3 = player.rig.weapon.transform*Vector3(0,0.18,0)
	check(player.rig.arms[1].hand.position.distance_to(tail_grip)<0.001,"Right hand keeps the physical tail grip throughout the turn")
	check(player.rig.arms[-1].hand.position.distance_to(guide_grip)>0.15,"Guide hand releases during the upright turn")
	player.combat.elapsed = 0.60
	player.animate(0,0)
	guide_grip = player.rig.weapon.transform*Vector3(0,0.18,0)
	check(player.rig.arms[-1].hand.position.distance_to(guide_grip)<0.001,"Guide hand regains its actual grip at the chain opening")
	stage.queue_free()
	await process_frame
	print("ELBOW_CONTINUITY_CHECKS: ",checks," FAILURES: ",failures)
	quit(1 if failures else 0)

func peak_step(player: CharacterBody3D, action: String, continuous: bool) -> float:
	player.rig.elbow_continuity = continuous
	player.rig.shaft_clearance = continuous
	player.combat.set_action("idle")
	player.animate(0,0)
	var previous := {}
	for side in [-1,1]: previous[side] = player.rig.root.to_global(player.rig.arms[side].elbow.position)
	player.combat.set_action(action)
	var peak := 0.0
	var duration: float = player.Combat.MOVES[action].duration
	for frame in ceili(duration*120)+1:
		player.combat.elapsed = minf(duration,frame/120.0)
		player.animate(1.0/120,0)
		for side in [-1,1]:
			var point: Vector3 = player.rig.root.to_global(player.rig.arms[side].elbow.position)
			peak = maxf(peak,point.distance_to(previous[side]))
			previous[side] = point
	return peak
