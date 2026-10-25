extends SceneTree
const H = preload("res://scripts/hunter_model.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var rig := H.create(actor)
	for x in [-0.12,0.12]:
		for z in [-0.16,0.16]:
			var leg: Dictionary = rig.legs[-1]
			var target := Vector3(leg.hip.position.x+x,0.19,z)
			H.pose_leg(leg,target)
			check(rig.root.to_local(leg.ankle.global_position).distance_to(target)<0.002,"leg reaches lateral ankle target")
			check(absf(leg.hip.global_position.distance_to(leg.knee.global_position)-0.43)<0.002 and absf(leg.knee.global_position.distance_to(leg.ankle.global_position)-0.36)<0.002,"lateral solve preserves both bone lengths")
	var held := 0
	var worst := 0.0
	var previous := {}
	for frame in 49:
		var t := 0.10+frame*0.01
		rig.root.rotation.y = TAU*smoothstep(0.10,0.58,t)
		H.pose_legs(rig,"turn",t,true,0,0,0.01,func(_point: Vector3): return 0.0)
		for side in [-1,1]:
			var leg: Dictionary = rig.legs[side]
			if not leg.hip.has_meta("turn_plant_world"):
				previous.erase(side)
				continue
			var anchor: Vector3 = leg.hip.get_meta("turn_plant_world")
			if previous.has(side) and anchor.distance_to(previous[side])<0.001:
				held += 1
				worst = maxf(worst,leg.ankle.global_position.distance_to(anchor))
			previous[side] = anchor
	check(held>=12,"turn retains stance anchors over multiple frames")
	check(worst<0.003,"held stance ankle remains fixed in world space")
	rig.root.rotation.y = TAU*smoothstep(0.10,0.58,0.30)
	H.pose_legs(rig,"turn",0.30,true,0,0,0,func(_point: Vector3): return 0.0)
	var old_anchor: Vector3 = rig.legs[-1].hip.get_meta("turn_plant_world")
	actor.position.x += 1
	H.pose_legs(rig,"turn",0.30,true,0,0,0,func(_point: Vector3): return 0.0)
	var fresh_anchor: Vector3 = rig.legs[-1].hip.get_meta("turn_plant_world")
	check(fresh_anchor.distance_to(old_anchor)>0.9,"large actor relocation resets unreachable old plant")
	check(rig.legs[-1].ankle.global_position.distance_to(fresh_anchor)<0.003,"reset plant remains reachable")
	H.pose_legs(rig,"turn",0.30,true,0,0,0)
	check(not rig.legs[-1].hip.has_meta("turn_plant_world") and not rig.legs[1].hip.has_meta("turn_plant_world"),"airborne pose releases world anchors")
	H.pose_legs(rig,"idle",0,true,0,0,0,func(_point: Vector3): return 0.0)
	check(not rig.legs[-1].hip.has_meta("turn_plant_world") and not rig.legs[1].hip.has_meta("turn_plant_world"),"leaving turn releases old stance anchors")
	held = 0
	worst = 0
	previous.clear()
	var previous_feet := {}
	var foot_jump := 0.0
	var jump_sample := {}
	for frame in 175:
		var t := minf(float(frame)/120,1.45)
		rig.root.rotation.y = TAU*H.Motion.turn_progress("finisher",t)
		H.pose_legs(rig,"finisher",t,true,0,0,1.0/120,func(_point: Vector3): return 0.0)
		for side in [-1,1]:
			var leg: Dictionary = rig.legs[side]
			var foot: Vector3 = leg.ankle.global_position
			if previous_feet.has(side) and foot.distance_to(previous_feet[side])>foot_jump:
				foot_jump = foot.distance_to(previous_feet[side])
				jump_sample = {"time":t,"side":side,"from":str(previous_feet[side]),"to":str(foot),"anchored":leg.hip.has_meta("turn_plant_world")}
			previous_feet[side] = foot
			if not leg.hip.has_meta("turn_plant_world"):
				previous.erase(side)
				continue
			var anchor: Vector3 = leg.hip.get_meta("turn_plant_world")
			if previous.has(side) and anchor.distance_to(previous[side])<0.001:
				held += 1
				worst = maxf(worst,foot.distance_to(anchor))
			previous[side] = anchor
	check(held>=8 and worst<0.003,"finisher rotation keeps planted stance feet fixed between steps")
	check(foot_jump<0.065,"finisher stepping and kick handoff avoid a visible ankle jump at 120Hz")
	actor.position = Vector3.ZERO
	rig.root.rotation = Vector3.ZERO
	var balls := {}
	var pivot_drift := 0.0
	for frame in 41:
		var time := 0.30+frame*0.01
		H.pose_legs(rig,"heavy",time,true,0,0,0,func(_point: Vector3): return 0.0)
		for side in [-1,1]:
			var ball: Vector3 = rig.legs[side].boot.to_global(Vector3(0,-0.5,-0.3))
			if frame==0: balls[side] = ball
			pivot_drift = maxf(pivot_drift,ball.distance_to(balls[side]))
	check(pivot_drift<0.002,"heavy sole rotates around the planted forefoot instead of sliding across flat ground")
	var rear: Node3D = rig.legs[1].boot
	var leading: Node3D = rig.legs[-1].boot
	check(rear.global_basis.orthonormalized().get_euler().y>0.35 and leading.global_basis.orthonormalized().get_euler().y>0.10,"rear and lead support feet turn with the sweep")
	var before_sole: Basis = rear.global_basis.orthonormalized()
	H.pose_legs(rig,"light",0,true,0,0,1.0/60,func(_point: Vector3): return 0.0)
	check(before_sole.get_rotation_quaternion().angle_to(rear.global_basis.orthonormalized().get_rotation_quaternion())<0.14,"heavy into light blends the support foot heading")
	H.pose_legs(rig,"heavy",0.92,true,0,0,0,func(_point: Vector3): return 0.0)
	check(absf(rear.global_basis.orthonormalized().get_euler().y)<0.001,"completed heavy recovers the neutral foot heading")
	print("HUNTER_FOOT_LOCK_CHECKS: ",checks," FAILURES: ",failures," HELD_FRAMES: ",held," WORST_DRIFT: ",worst," FINISHER_STEP: ",foot_jump," HEAVY_PIVOT_DRIFT: ",pivot_drift)
	print("FINISHER_FOOT_SAMPLE: ",JSON.stringify(jump_sample))
	actor.queue_free()
	await process_frame
	quit(1 if failures else 0)
