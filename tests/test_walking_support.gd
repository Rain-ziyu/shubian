extends SceneTree
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
class FacingTarget:
	extends Node3D
	var health := 100
	var data := {"size":2.0}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_mesh := Player.Visuals.piece(stage,Vector3(0,-0.2,-15),Vector3(40,0.4,70),Color.GRAY)
	floor_mesh.create_trimesh_collision()
	var p := Player.new()
	stage.add_child(p)
	p.set_physics_process(false)
	p.position = Vector3(0,0.02,0)
	p.yaw = 0
	await physics_frame
	await physics_frame
	for sprint in [false,true]:
		Input.action_press("move_forward")
		if sprint: Input.action_press("sprint")
		var start := p.position
		var previous := {}
		var streak := {-1:0,1:0}
		var held := 0
		var longest := 0
		var worst := 0.0
		for frame in 120:
			p._physics_process(1.0/60)
			await physics_frame
			for side in [-1,1]:
				var leg: Dictionary = p.rig.legs[side]
				if not leg.hip.has_meta("walk_plant_world"):
					previous.erase(side)
					streak[side] = 0
					continue
				var anchor: Vector3 = leg.hip.get_meta("walk_plant_world")
				if previous.has(side) and anchor.distance_to(previous[side])<0.001:
					held += 1
					streak[side] += 1
					longest = maxi(longest,streak[side])
					worst = maxf(worst,leg.ankle.global_position.distance_to(anchor))
				else: streak[side] = 0
				previous[side] = anchor
		check(p.position.distance_to(start)>8,"walking trial actually travels across the floor")
		check(held>20 and longest>=4,"walk and sprint retain stance anchors over multiple frames")
		check(worst<0.002,"grounded walking ankle remains fixed in world space")
		print("WALKING_SUPPORT sprint=",sprint," held=",held," longest=",longest," drift=",worst)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	p._physics_process(1.0/60)
	for side in [-1,1]:
		check(not p.rig.legs[side].hip.has_meta("walk_plant_world"),"stopping clears walking anchors")
	for mode in ["airborne","guard"]:
		p.walk_clock = 0
		Player.HunterModel.pose_legs(p.rig,"idle",0,false,0,4.5,0,func(_point: Vector3): return 0.0)
		check(p.rig.legs[-1].hip.has_meta("walk_plant_world"),"transition trial starts with a real walking anchor")
		if mode=="airborne":
			Player.HunterModel.pose_legs(p.rig,"idle",0,false,0,4.5,0)
		else:
			Player.HunterModel.pose_legs(p.rig,"guard",0.2,true,0,4.5,0,func(_point: Vector3): return 0.0)
		check(not p.rig.legs[-1].hip.has_meta("walk_plant_world"),"airborne and combat transitions release walking anchors")
	var facing := FacingTarget.new()
	stage.add_child(facing)
	p.lock_target = facing
	p.camera_manual_time = 999
	for axis in [Vector2(0,1),Vector2(1,0),Vector2(-1,0),Vector2(1,-1).normalized()]:
		p.position = Vector3(0,0.02,0)
		p.rig.root.rotation.y = 0
		p.walk_clock = 0
		p.combat.set_action("idle")
		p.combat.drawn = true
		var action := "move_back" if axis.y>0 else "move_forward"
		if axis.y!=0: Input.action_press(action,absf(axis.y))
		if axis.x!=0: Input.action_press("move_right" if axis.x>0 else "move_left",absf(axis.x))
		var direction := Vector3(axis.x,0,axis.y)
		var first := Vector3.ZERO
		var last := Vector3.ZERO
		var samples := 0
		var anchors := {}
		var held := 0
		var drift := 0.0
		for frame in 31:
			# A moving facing fixture isolates strafing from changes in target bearing.
			facing.position = p.position+Vector3.FORWARD*15
			p._physics_process(1.0/60)
			await physics_frame
			for side in [-1,1]:
				var leg: Dictionary = p.rig.legs[side]
				if not leg.hip.has_meta("walk_plant_world"):
					anchors.erase(side)
					continue
				var anchor: Vector3 = leg.hip.get_meta("walk_plant_world")
				if anchors.has(side) and anchor.distance_to(anchors[side])<0.001:
					held += 1
					drift = maxf(drift,leg.ankle.global_position.distance_to(anchor))
				anchors[side] = anchor
			var phase := wrapf(p.walk_clock,0,TAU)
			if phase>PI/2+0.2 and phase<TAU-0.2:
				var foot: Vector3 = p.rig.legs[-1].ankle.global_position-p.global_position
				if samples==0: first = foot
				last = foot
				samples += 1
		check(samples>10 and (last-first).dot(direction)>0.35,"locked swing foot advances along actual travel: "+str(axis))
		check(held>5 and drift<0.002,"locked strafing preserves support foot anchors: "+str(axis))
		for key in ["move_forward","move_back","move_left","move_right"]: Input.action_release(key)
	print("WALKING_SUPPORT_CHECKS: ",checks," FAILURES: ",failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
