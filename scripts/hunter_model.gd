extends RefCounted
const V = preload("res://scripts/visuals.gd")
const Fabric = preload("res://scripts/hunter_fabric.gd")
const Skinning = preload("res://scripts/hunter_skin.gd")
const Hand = preload("res://scripts/hunter_hand.gd")
const Outfit = preload("res://scripts/hunter_outfit.gd")
const Motion = preload("res://scripts/hunter_motion.gd")
const JointCloth = preload("res://scripts/hunter_joint_cloth.gd")
const STANCE_BLEND_SECONDS := 0.10
const BLENDED_STANCES := ["idle","light","heavy","pull","guard","reply","flash","fourfold","throw"]

static func tapered(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.material_override = V.mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

static func create(parent: Node3D) -> Dictionary:
	var root := V.pivot(parent,"HunterRig",Vector3.ZERO)
	var dark := Color("303834")
	var armor := Color("6a756b")
	var costume := Outfit.create(root)
	var pelvis := V.pivot(root,"Pelvis",Vector3(0,0.89,0))
	for part in costume.lower_parts:
		part.reparent(pelvis,false)
		part.position -= pelvis.position
	var torso := V.pivot(root,"Torso",Vector3(0,1.08,0))
	for part in costume.upper_parts:
		if str(part.name).begins_with("ShoulderPlate"): continue
		part.reparent(torso,false)
		part.position -= torso.position
	var joints := {}
	var arms := {}
	var legs := {}
	for side in [-1,1]:
		var shoulder := V.pivot(root,"Arm"+str(side),Vector3(side*0.27,1.43,0))
		var upper := Outfit.loft(root,"UpperArmSurface"+str(side),[Vector4(-0.5,0.073,0.070,0),Vector4(-0.35,0.084,0.078,-0.003),Vector4(-0.10,0.078,0.075,-0.004),Vector4(0.15,0.067,0.065,0),Vector4(0.40,0.054,0.054,0),Vector4(0.5,0.055,0.054,0)],Outfit.SKIN_TONE)
		var lower := Outfit.loft(root,"Bracer"+str(side),[Vector4(-0.5,0.063,0.058,0),Vector4(-0.15,0.073,0.062,0),Vector4(0.35,0.058,0.052,0),Vector4(0.5,0.048,0.045,0)],armor)
		V.piece(lower,Vector3(0,-0.06,-0.063),Vector3(0.065,0.28,0.012),Color("434b43"))
		if side==-1:
			var display := V.piece(lower,Vector3(0,-0.06,-0.071),Vector3(0.039,0.18,0.009),Color("8fb8a0"))
			display.material_override = V.mat(Color("8fb8a0"),true)
		var hand := Hand.create(root,side)
		var elbow_pad := Outfit.blob(root,"Elbow"+str(side),Vector3.ZERO,Vector3.ONE*0.12,dark)
		arms[side] = {"shoulder":shoulder,"rest_shoulder":shoulder.position,"upper":upper,"lower":lower,"hand":hand,"elbow":elbow_pad}
		joints["arm"+str(side)] = shoulder
		var leg := V.pivot(root,"Leg"+str(side),Vector3(side*0.14,0.89,0))
		var thigh := Outfit.loft(leg,"TrouserThigh",[Vector4(-0.43,0.08,0.072,0),Vector4(-0.34,0.10,0.09,0),Vector4(-0.16,0.112,0.10,0),Vector4(0,0.10,0.095,0)],dark)
		var knee := V.pivot(leg,"Knee",Vector3(0,-0.43,0))
		Outfit.patch(knee,"KneePlate",[Vector3(-0.065,0.065,-0.09),Vector3(0.065,0.065,-0.09),Vector3(0.085,-0.03,-0.105),Vector3(0,-0.12,-0.115),Vector3(-0.085,-0.03,-0.105)],armor)
		var shin := Outfit.loft(knee,"TrouserShin",[Vector4(-0.36,0.061,0.058,0),Vector4(-0.23,0.077,0.071,0),Vector4(-0.10,0.087,0.078,0),Vector4(0,0.078,0.072,0)],dark)
		Outfit.patch(knee,"ShinPlate",[Vector3(-0.065,-0.10,-0.09),Vector3(0.065,-0.10,-0.09),Vector3(0.055,-0.27,-0.085),Vector3(0,-0.33,-0.10),Vector3(-0.055,-0.27,-0.085)],armor)
		var ankle := V.pivot(knee,"Ankle",Vector3(0,-0.36,0))
		var boot := Outfit.boot(ankle)
		legs[side] = {"hip":leg,"knee":knee,"ankle":ankle,"thigh":thigh,"shin":shin,"boot":boot}
		joints["leg"+str(side)] = leg
	var rig := {"root":root,"torso":torso,"pelvis":pelvis,"joints":joints,"arms":arms,"legs":legs,"skirts":costume.skirts,"shoulders":costume.shoulders,"weapon":V.trident(root)}
	rig.head_parts = []
	for part in torso.get_children():
		if part is Node3D and part.get_meta("head_assembly",false):
			rig.head_parts.append({"source":part,"rest":part.transform})
	rig.weapon.name = "Trident"
	pose_arms(rig,false,0)
	rig.soft_joints = []
	for side in [-1,1]:
		var arm: Dictionary = arms[side]
		var shoulder_cloth := JointCloth.create(root,"JointClothShoulder"+str(side),Vector3(side*0.16,1.40,0),arm.shoulder.position,arm.elbow.position,0.055)
		rig.soft_joints.append({"source":shoulder_cloth,"upper":torso.get_node("Undercoat"),"lower":arm.upper})
		# Flexible underlayers stay inside the rigid sleeve/trouser openings to avoid intersecting rims.
		var elbow_cloth := JointCloth.create(root,"JointClothElbow"+str(side),arm.shoulder.position,arm.elbow.position,arm.hand.position,0.054)
		rig.soft_joints.append({"source":elbow_cloth,"upper":arm.upper,"lower":arm.lower})
		var leg: Dictionary = legs[side]
		var knee_cloth := JointCloth.create(root,"JointClothKnee"+str(side),Skinning.relative_transform(leg.hip,root).origin,Skinning.relative_transform(leg.knee,root).origin,Skinning.relative_transform(leg.ankle,root).origin,0.070)
		rig.soft_joints.append({"source":knee_cloth,"upper":leg.thigh,"lower":leg.shin})
	Fabric.apply(root)
	rig.skinning = Skinning.bind(rig)
	if ResourceLoader.exists("res://resources/animations/trident_library.tres"):
		var player := AnimationPlayer.new()
		player.name = "AnimationPreview"
		root.add_child(player)
		player.add_animation_library("",load("res://resources/animations/trident_library.tres"))
	return rig

static func segment(mesh: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var axis := end-start
	mesh.position = (start+end)*0.5
	mesh.quaternion = Quaternion(Vector3.UP,axis.normalized())
	mesh.scale.y = axis.length()

static func pose_arms(rig: Dictionary, armed: bool, gait: float, grip_weight := 1.0, main_grip := -1.0, finger_release := 0.0) -> void:
	for side in [-1,1]:
		var arm: Dictionary = rig.arms[side]
		var shoulder: Vector3 = arm.shoulder.position
		var target := shoulder+Vector3(0,-0.72,-0.015+sin(gait)*side*0.12)
		if armed:
			# Anatomical left stays head-side, right stays butt-side through rotation.
			var weight: float = main_grip if side==1 and main_grip>=0 else grip_weight
			target = target.lerp(rig.weapon.transform*Vector3(0,0.18 if side==-1 else -0.28,0),weight)
		var offset := target-shoulder
		var distance := offset.length()
		var middle := (shoulder+target)*0.5
		var bend: Vector3 = rig.torso.basis*(Vector3(side*0.6,-0.7,0.3) if armed else Vector3(side*0.12,-0.3,-1))
		var unit := offset.normalized()
		bend = (bend-unit*bend.dot(unit)).normalized()
		var height := sqrt(maxf(0,0.39*0.39-pow(distance*0.5,2)))
		var elbow := middle+bend*height
		segment(arm.upper,shoulder,elbow)
		# Use the anatomical elbow plane, avoiding shortest-arc roll and pole switches.
		var upper_axis := (elbow-shoulder).normalized()
		var elbow_normal := unit.cross(bend).normalized()
		arm.upper.basis = Basis(elbow_normal,upper_axis,elbow_normal.cross(upper_axis).normalized()).scaled_local(Vector3(1,shoulder.distance_to(elbow),1))
		segment(arm.lower,elbow,target)
		if not arm.has("rest_upper_basis"): arm.rest_upper_basis = arm.upper.basis.orthonormalized()
		var shoulder_plate: MeshInstance3D = rig.shoulders[side]
		shoulder_plate.position = shoulder
		var shoulder_turn: Basis = arm.upper.basis.orthonormalized()*arm.rest_upper_basis.inverse()
		shoulder_plate.basis = shoulder_turn
		arm.hand.position = target
		Hand.orient(arm.hand,elbow,rig.weapon.basis.y,clampf(main_grip if side==1 and main_grip>=0 else grip_weight,0,1) if armed else 0.0,finger_release)
		arm.elbow.position = elbow
	Skinning.update(rig)

static func pose_torso(rig: Dictionary, action: String, elapsed: float, gait: float, speed: float, delta: float, travel := Vector3.FORWARD, arrival_weight := 0.0) -> void:
	var value := Motion.sample(action,elapsed,gait,speed)
	var rotation := Vector3(value.y,value.z,-value.z*0.08)
	var position := Vector3(value.z*0.018,1.08,value.w)
	if action=="dodge":
		var direction := Vector3(travel.x,0,travel.z).normalized()
		if direction.is_zero_approx(): direction = Vector3.FORWARD
		var weight := sin(clampf(elapsed/0.55,0,1)*PI)
		rotation = Vector3(direction.z*0.23*weight,0,-direction.x*0.23*weight)
		position += direction*0.03*weight
		position.z -= value.w
	rotation.x -= 0.07*arrival_weight
	position.z -= 0.015*arrival_weight
	var weight := 1-exp(-delta*12) if delta>0 else 1.0
	rig.torso.rotation = rig.torso.rotation.move_toward(rotation,delta*6.5) if delta>0 else rotation
	rig.torso.position = rig.torso.position.lerp(position,weight)
	# Keep the gaze near the committed attack heading while the chest winds up.
	# All facial/hair meshes rotate around the same anatomical neck anchor.
	var head_pivot := Vector3(0,1.535-1.08,0)
	var compensation := Vector3.ZERO
	if action in ["light","heavy","pull","guard","reply","flash","fourfold","throw"]:
		compensation = Vector3(-rig.torso.rotation.x*0.45,-rig.torso.rotation.y*0.75,0)
	var adjustment := Transform3D(Basis.from_euler(compensation),head_pivot)
	adjustment.origin -= adjustment.basis*head_pivot
	for part in rig.head_parts: part.source.transform = adjustment*part.rest
	for side in [-1,1]:
		var arm: Dictionary = rig.arms[side]
		arm.shoulder.position = rig.torso.transform*(arm.rest_shoulder-Vector3(0,1.08,0))

static func pose_legs(rig: Dictionary, action: String, elapsed: float, armed: bool, gait: float, speed: float, delta: float, ground: Callable = Callable(), ground_normal: Callable = Callable(), travel := Vector3.FORWARD, arrival_weight := 0.0, motion_epoch := 0) -> void:
	# Blend only horizontal ordinary stances. Ground height and authored aerial,
	# stagger, turn and kick poses retain their existing solve and timing.
	var previous_action: String = rig.get("stance_action","")
	var discontinuity: bool = rig.get("stance_epoch",motion_epoch)!=motion_epoch
	if delta<=0 or discontinuity or action not in BLENDED_STANCES or previous_action not in BLENDED_STANCES:
		rig.stance_age = STANCE_BLEND_SECONDS
	elif previous_action!=action:
		rig.stance_from = {}
		for side in [-1,1]: rig.stance_from[side] = rig.legs[side].ankle.global_position
		rig.stance_age = 0.0
	rig.stance_action = action
	rig.stance_epoch = motion_epoch
	rig.stance_age = minf(STANCE_BLEND_SECONDS,float(rig.get("stance_age",STANCE_BLEND_SECONDS))+maxf(0,delta))
	var stance_weight := smoothstep(0,STANCE_BLEND_SECONDS,float(rig.stance_age))
	var drop := 0.09 if armed else 0.015
	var walking := action=="idle" and speed>0.1
	if walking: drop = 0.12
	if action=="guard": drop += 0.04*smoothstep(0,0.18,elapsed)
	if action=="reply": drop = 0.13+0.035*smoothstep(0,0.12,elapsed)*(1-smoothstep(0.12,0.26,elapsed))
	if action in ["plant","wait","counter_window"]: drop = 0.18
	if action=="dodge":
		var load := smoothstep(0,0.06,elapsed)
		var flight := smoothstep(0.06,0.14,elapsed)*(1-smoothstep(0.30,0.42,elapsed))
		var landing := smoothstep(0.30,0.40,elapsed)*(1-smoothstep(0.40,0.55,elapsed))
		drop = lerpf(drop,0.10,load*(1-smoothstep(0.42,0.55,elapsed)))+0.12*load*(1-smoothstep(0.06,0.14,elapsed))-0.05*flight+0.09*landing
	if action=="flash": drop += 0.06*smoothstep(0,0.08,elapsed)*(1-smoothstep(0.08,0.23,elapsed))
	if action=="throw": drop += 0.06*smoothstep(0,0.20,elapsed)*(1-smoothstep(0.20,0.38,elapsed))
	drop += 0.08*arrival_weight
	if action=="hurt": drop = 0.16
	if action=="spin": drop += 0.05*sin(Motion.turn_progress(action,elapsed)*PI)
	if action in ["light","heavy"]:
		var ready := 0.11 if action=="light" else 0.18
		var release := 0.25 if action=="light" else 0.43
		var release_from := 0.15 if action=="light" else 0.30
		# The sweep loads into the rear support leg before transferring forward.
		drop += (0.10 if action=="heavy" else 0.05)*smoothstep(0,ready,elapsed)*(1-smoothstep(release_from,release,elapsed))
	var body: Node3D = rig.root
	var shift := Motion.sample(action,elapsed,gait,speed).w*1.6 if action in ["light","heavy","hurt","reply","finisher","throw"] else 0.0
	body.position.z = lerpf(body.position.z,shift,1-exp(-delta*18)) if delta>0 else shift
	var previous_height := body.position.y
	body.position.y = -drop
	var hip_turn := Motion.sample(action,elapsed,gait,speed).z*0.45 if action in ["light","heavy"] else 0.0
	rig.pelvis.rotation.y = lerp_angle(rig.pelvis.rotation.y,hip_turn,1-exp(-delta*18)) if delta>0 else hip_turn
	for side in [-1,1]: rig.legs[side].hip.position = rig.pelvis.transform*Vector3(side*0.14,0,0)
	var targets := {}
	var normals := {}
	var planting := {}
	var lowest := 0.0
	for side in [-1,1]:
		var leg: Dictionary = rig.legs[side]
		var stance := -0.16 if side==-1 else 0.14
		if not armed: stance = 0
		if action=="guard": stance *= lerpf(1.0,1.4,smoothstep(0,0.18,elapsed))
		if action=="reply": stance *= 1.4
		var lift := 0.0
		if speed>0.1 and action not in ["dodge","flash"]:
			stance = sin(gait)*side*minf(0.28,speed*0.055)
			lift = maxf(0,cos(gait)*side)*minf(0.14,speed*0.025)
		if walking:
			var phase := wrapf(gait+(PI if side==1 else 0),0,TAU)
			var stride := PI/(4*2.6)
			if phase<PI/2:
				stance = lerpf(-stride,stride,phase/(PI/2))
				lift = 0
			else:
				var swing := (phase-PI/2)/(TAU-PI/2)
				stance = lerpf(stride,-stride,smoothstep(0,1,swing))
				lift = sin(swing*PI)*0.14
		if action in ["turn","spin"]:
			var turning := Motion.turn_progress(action,elapsed)
			lift += maxf(0,sin(turning*TAU*2+(PI if side==1 else 0)))*0.09
		if action=="finisher" and side==-1:
			var support := smoothstep(0.55,0.82,elapsed)*(1-smoothstep(1.16,1.40,elapsed))
			stance = lerpf(stance,0.08,support)
			lift = sin(support*PI)*0.035
		var target := Vector3(side*0.14,0.10-body.position.y+lift,stance)
		if action=="throw" and side==-1:
			var step := smoothstep(0.02,0.25,elapsed)*(1-smoothstep(0.50,0.80,elapsed))
			target.z -= 0.08*step
			target.y += 0.05*sin(smoothstep(0.02,0.25,elapsed)*PI)
		if action in ["dodge","flash"]:
			var direction := Vector3(travel.x,0,travel.z).normalized() if action=="dodge" else Vector3.FORWARD
			if direction.is_zero_approx(): direction = Vector3.FORWARD
			var lead := (-1 if direction.x<0 else 1) if absf(direction.x)>absf(direction.z)*0.5 else (-1 if direction.z<=0 else 1)
			var reach := 0.0
			if action=="dodge":
				var step := smoothstep(0.03,0.18,elapsed)*(1-smoothstep(0.38,0.55,elapsed))
				reach = lerpf(-0.10,0.16,smoothstep(0.08,0.33,elapsed))*step if side==lead else -0.20*step*(1-smoothstep(0.18,0.43,elapsed))
				lift = sin(smoothstep(0.04 if side==lead else 0.10,0.34 if side==lead else 0.44,elapsed)*PI)*(0.16 if side==lead else 0.12)
			else:
				var drive := smoothstep(0.08,0.23,elapsed)*(1-smoothstep(0.30,0.58,elapsed))
				reach = (0.18 if side==lead else -0.12)*drive
				lift = sin(smoothstep(0.02,0.23,elapsed)*PI)*0.10 if side==lead else 0.0
			target += direction*reach
			target.y += lift
		if action=="reply" and side==-1:
			var step := smoothstep(0.02,0.16,elapsed)*(1-smoothstep(0.42,0.67,elapsed))
			target.z -= step*0.06
			target.y += sin(smoothstep(0.02,0.16,elapsed)*PI)*0.045
		if action in ["light","heavy"] and side==-1:
			var step := smoothstep(0.03,0.18,elapsed)*(1-smoothstep(0.42,0.66 if action=="light" else 0.92,elapsed))
			target.z -= step*(0.10 if action=="light" else 0.06)
			if action=="heavy": target.x -= step*0.07
			var swing := smoothstep(0.03,0.18,elapsed)
			target.y += sin(swing*PI)*0.065
		if walking:
			var direction := Vector3(travel.x,0,travel.z).normalized()
			if direction.length_squared()<0.001: direction = Vector3.FORWARD
			target.x -= direction.x*stance
			target.z = -direction.z*stance
		target.z -= body.position.z
		if stance_weight<1 and rig.has("stance_from"):
			var from: Vector3 = body.to_local(rig.stance_from[side])
			target.x = lerpf(from.x,target.x,stance_weight)
			target.z = lerpf(from.z,target.z,stance_weight)
		normals[side] = Vector3.UP
		if action=="finisher" and side==1:
			var chamber := smoothstep(0.60,0.80,elapsed)
			var extension := smoothstep(0.80,0.95,elapsed)
			var weight := chamber*(1-smoothstep(1.02,1.32,elapsed))
			target.y += lerpf(0.55,0.62,extension)*weight
			target.z = lerpf(target.z,lerpf(-0.18,-0.72,extension)-body.position.z,weight)
		var turning := Motion.turn_progress(action,elapsed)
		var planted: bool = action in ["turn","spin"] and turning>0 and turning<1 and lift<0.001 and ground.is_valid()
		var walk_planted: bool = walking and lift<0.001 and ground.is_valid()
		var anchor_key := "walk_plant_world" if walking else "turn_plant_world"
		var inactive_key := "turn_plant_world" if walking else "walk_plant_world"
		if leg.hip.has_meta(inactive_key): leg.hip.remove_meta(inactive_key)
		planted = planted or walk_planted
		var anchored := false
		if leg.hip.has_meta(anchor_key):
			var anchor: Vector3 = body.to_local(leg.hip.get_meta(anchor_key))
			if planted and Vector2(anchor.x-leg.hip.position.x,anchor.z).length()<0.32 and (anchor-leg.hip.position).length()<0.78:
				target = anchor
				anchored = true
			else: leg.hip.remove_meta(anchor_key)
		planting[side] = planted
		# Keep the attacking foot on its authored arc; sample support/swing feet only.
		if ground.is_valid() and not (action=="finisher" and side==1 and elapsed>=0.60 and elapsed<1.32):
			var height: float = clampf(ground.call(Vector3(target.x,0,target.z)),-0.22,0.22)
			if not anchored: target.y += height
			lowest = minf(lowest,height)
			if ground_normal.is_valid():
				var normal: Vector3 = ground_normal.call(Vector3(target.x,0,target.z))
				normals[side] = Vector3.UP.lerp(normal,1-smoothstep(0.01,0.10,lift)).normalized()
		targets[side] = target
	# Lower the visual body for the downhill foot without moving the gameplay capsule.
	body.position.y = lerpf(previous_height,-drop+lowest,minf(1,delta*14)) if delta>0 else -drop+lowest
	for side in [-1,1]:
		var leg: Dictionary = rig.legs[side]
		var target: Vector3 = targets[side]
		target.y += -drop-body.position.y
		pose_leg(leg,target)
		if action=="finisher" and side==1:
			var extension := smoothstep(0.80,0.95,elapsed)*(1-smoothstep(1.02,1.32,elapsed))
			normals[side] = Vector3.UP.rotated(Vector3.RIGHT,PI/4*extension)
		pose_sole(leg,normals[side])
		var anchor_key := "walk_plant_world" if walking else "turn_plant_world"
		if planting[side] and not leg.hip.has_meta(anchor_key) and (not walking or (target-leg.hip.position).length()<0.78):
			leg.hip.set_meta(anchor_key,leg.ankle.global_position)
		if rig.has("skirts"):
			rig.skirts[side].rotation.x = clampf(leg.hip.rotation.x,0,1.3)*0.7

static func pose_sole(leg: Dictionary, normal: Vector3) -> void:
	# Tilt the Foot bone around the sole anchor, preserving the solved leg lengths.
	# The ankle controller is level in rig space after pose_leg.
	var tilt := Basis(Quaternion(Vector3.UP,normal.normalized()))
	leg.boot.basis = tilt.scaled_local(Vector3(0.18,0.15,0.30))
	leg.boot.position = Vector3(0,-0.10,0)+tilt*Vector3(0,0.075,-0.06)

static func pose_leg(leg: Dictionary, target: Vector3) -> void:
	var offset: Vector3 = target-leg.hip.position
	var distance := clampf(offset.length(),0.075,0.7899)
	# Roll the leg's bend plane sideways, preserving its anatomical forward pole.
	var roll := atan2(offset.x,-offset.y)
	var angle := atan2(-offset.z,Vector2(offset.x,offset.y).length())
	var hip_bend := acos(clampf((0.43*0.43+distance*distance-0.36*0.36)/(2*0.43*distance),-1,1))
	leg.hip.basis = Basis(Vector3.BACK,roll)*Basis(Vector3.RIGHT,angle+hip_bend)
	leg.knee.rotation = Vector3(-acos(clampf((distance*distance-0.43*0.43-0.36*0.36)/(2*0.43*0.36),-1,1)),0,0)
	leg.ankle.basis = (leg.hip.basis*leg.knee.basis).inverse()
