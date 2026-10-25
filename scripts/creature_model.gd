extends RefCounted
const V = preload("res://scripts/visuals.gd")
const H = preload("res://scripts/hunter_model.gd")
const Surface = preload("res://scripts/creature_surface.gd")
const TailSkin = preload("res://scripts/creature_tail_skin.gd")
const LegSkin = preload("res://scripts/creature_leg_skin.gd")
const GAIT_PER_METER := 4.2

static func jaw_pose(data: Dictionary, phase: String, clock: float) -> Transform3D:
	var ready: float = {"sweep":0.16,"charge":0.08,"leap":0.10,"mist":0.30,"pulse":0.04}[data.pattern]
	var wide: float = {"sweep":0.26,"charge":0.20,"leap":0.30,"mist":0.36,"pulse":0.24}[data.pattern]
	var opening := 0.0
	if phase=="windup": opening = ready*smoothstep(0,float(data.windup),clock)
	elif phase=="active":
		opening = lerpf(ready,wide,smoothstep(0,0.12,clock))
		if data.pattern!="mist": opening *= 1-smoothstep(0.35,0.65,clock)
	elif phase=="recover" and data.pattern=="mist": opening = wide*(1-smoothstep(0,0.45,clock))
	var hinge := Vector3(0,float(data.size)*0.01,-float(data.size)*0.12)
	var rotation := Basis(Vector3.RIGHT,-opening)
	return Transform3D(rotation,hinge)

static func sweep_angles(phase: String, clock: float, windup: float, recovery: float) -> Vector2:
	if phase=="windup": return Vector2(-0.20*clampf(clock/windup,0,1),-0.65*smoothstep(0,windup,clock))
	if phase=="active": return Vector2(-0.20*(1-smoothstep(0,0.30,clock)),lerpf(-0.65,0.85,smoothstep(0,0.40,clock)))
	if phase=="recover": return Vector2(0,0.85*(1-smoothstep(0,recovery,clock)))
	return Vector2.ZERO

static func create(parent: Node3D, data: Dictionary) -> Node3D:
	var root := V.pivot(parent,"CreatureMesh",Vector3.ZERO)
	var s: float = data.size
	var c := Color(data.color)
	var quad: bool = "quadruped" in data.body
	var y := s*0.50 if quad else s*0.64
	var body := Surface.profile(root,"BodySurface",[Vector4(-0.56,0.08,0.12,0.03),Vector4(-0.42,0.28,0.23,0.025),Vector4(-0.15,0.37,0.285,0),Vector4(0.20,0.34,0.26,0),Vector4(0.43,0.22,0.20,-0.025),Vector4(0.56,0.08,0.12,-0.025)],s,c)
	body.position.y = y
	if data.id=="reedclaw": body.scale = Vector3(0.80,0.85,1)
	elif data.id=="mistfrill": body.scale = Vector3(0.85,0.90,1)
	var neck := V.pivot(root,"Neck",Vector3(0,y,-s*0.40))
	var head_width := 0.78 if data.id in ["reedclaw","mistfrill"] else 1.0
	Surface.profile(neck,"HeadSurface",[Vector4(-0.715,0.012*head_width,0.008,0.06),Vector4(-0.707,0.025*head_width,0.016,0.06),Vector4(-0.69,0.035*head_width,0.02,0.06),Vector4(-0.61,0.14*head_width,0.065,0.085),Vector4(-0.42,0.19*head_width,0.14,0.14),Vector4(-0.28,0.16*head_width,0.145,0.12),Vector4(-0.09,0.135,0.17,0.08),Vector4(0.12,0.10,0.15,0)],s,c.lightened(0.03))
	Surface.profile(neck,"Jaw",[Vector4(-0.68,0.006*head_width,0.004,-0.04),Vector4(-0.66,0.035*head_width,0.015,-0.04),Vector4(-0.58,0.13*head_width,0.035,-0.05),Vector4(-0.30,0.145*head_width,0.055,-0.045),Vector4(-0.12,0.06,0.025,0.01)],s,c.darkened(0.16))
	var jaw := neck.get_node("Jaw") as MeshInstance3D
	var hinge := Vector3(0,s*0.01,-s*0.12)
	var jaw_arrays: Array = jaw.mesh.surface_get_arrays(0)
	var jaw_vertices: PackedVector3Array = jaw_arrays[Mesh.ARRAY_VERTEX]
	for vertex in jaw_vertices.size(): jaw_vertices[vertex] -= hinge
	jaw_arrays[Mesh.ARRAY_VERTEX] = jaw_vertices
	var jaw_mesh := ArrayMesh.new()
	jaw_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,jaw_arrays)
	jaw.mesh = jaw_mesh
	jaw.transform = jaw_pose(data,"idle",0)
	var mouth_floor := Surface.profile(jaw,"MouthFloor",[Vector4(-0.60,0.075*head_width,0.004,-0.018),Vector4(-0.40,0.12*head_width,0.004,0.012),Vector4(-0.20,0.10*head_width,0.004,0.015),Vector4(-0.12,0.04,0.004,0.012)],s,Color("26352e"))
	mouth_floor.position = -hinge
	for side in [-1,1]:
		var nostril := V.piece(neck,Vector3(side*s*0.075*head_width,s*0.109,-s*0.64),Vector3(s*0.028,s*0.006,s*0.035),Color("26372b"),true)
		nostril.name = "Nostril"+str(side)
		nostril.material_override.albedo_color = Color("142118")
		nostril.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		V.piece(neck,Vector3(side*s*0.158*head_width,s*0.20,-s*0.43),Vector3(s*0.028,s*0.02,s*0.045),Color("dba75d"),true)
		V.piece(neck,Vector3(side*s*0.169*head_width,s*0.20,-s*0.436),Vector3(s*0.006,s*0.018,s*0.012),Color("1c2721"),true)
		var brow := Surface.profile(neck,"EyeRidge"+str(side),[Vector4(-0.51,0.001,0.001,0.225),Vector4(-0.46,0.018,0.012,0.245),Vector4(-0.41,0.028,0.014,0.255),Vector4(-0.35,0.020,0.012,0.245),Vector4(-0.30,0.001,0.001,0.22)],s,c.darkened(0.14))
		brow.position.x = side*s*0.15*head_width
		for tooth in 5:
			H.tapered(neck,Vector3(side*s*0.10*head_width,-s*0.005,s*(-0.56+tooth*0.045)),s*0.014,s*0.001,s*0.06,Color("c6c5aa"))
			H.tapered(jaw,Vector3(side*s*0.095*head_width,-s*0.015,s*(-0.5375+tooth*0.045))-hinge,s*0.001,s*0.010,s*0.035,Color("b6b79d"))
		for front in ([false,true] if quad else [false]):
			var leg := V.pivot(root,("Front" if front else "Hind")+str(side),Vector3(side*s*0.29,y*0.9,-s*0.31 if front else s*0.28))
			var bottom := -y*0.9/s+0.075
			Surface.vertical(leg,"LegSurface",[Vector4(bottom,0.055,0.06,0.025),Vector4(bottom*0.78,0.066,0.075,0.05),Vector4(bottom*0.56,0.092,0.09,-0.04),Vector4(bottom*0.28,0.13,0.12,-0.02),Vector4(0.025,0.13,0.14,0)],s,c)
			var foot_y := -y*0.9+s*0.05
			var foot := V.piece(leg,Vector3(0,foot_y,-s*0.10),Vector3(s*0.21,s*0.10,s*0.35),c.darkened(0.25),true)
			foot.name = "Foot"
			for toe in [-1,0,1]:
				var claw := H.tapered(leg,Vector3(toe*s*0.055,foot_y+s*0.015,-s*0.25),s*0.001,s*0.017,s*(0.20 if data.id=="reedclaw" else 0.14),Color("b6ba9b"))
				claw.rotation.x = -PI/2
				claw.name = "Claw"+str(toe)
		if not quad:
			var arm := Surface.profile(root,"Forelimb"+str(side),[Vector4(-0.24,0.02,0.03,-0.13),Vector4(-0.12,0.045,0.055,-0.10),Vector4(0.02,0.055,0.07,0)],s,c)
			arm.position = Vector3(side*s*0.28,y,-s*0.35)
	var tail := V.pivot(root,"Tail",Vector3(0,y*0.85,s*0.45))
	var length := 1.55 if data.id=="reedclaw" else (0.85 if data.id=="thornhorn" else 1.10)
	Surface.profile(tail,"TailSurface",[Vector4(-0.06,0.14,0.15,0),Vector4(0.14*length,0.125,0.125,-0.015),Vector4(0.40*length,0.085,0.085,-0.035),Vector4(0.70*length,0.045,0.04,-0.055),Vector4(0.96*length,0.008,0.008,-0.065)],s,c)
	if data.id=="mossback":
		for i in 5:
			var taper := 1.0-absf(i-2)*0.12
			var plate := Surface.profile(root,"ArmorPlate"+str(i),[Vector4(-0.13,0.28*taper,0.06*taper,0),Vector4(-0.07,0.37*taper,0.24*taper,0),Vector4(0.09,0.35*taper,0.21*taper,0),Vector4(0.14,0.27*taper,0.05*taper,0)],s,c.darkened(0.16),-PI/2,PI/2,false)
			plate.position = Vector3(0,y+s*0.045,(i-2)*s*0.18)
			plate.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif data.id=="thornhorn":
		for side in [-1,1]:
			var horn := Surface.profile(neck,"BrowHorn"+str(side),[Vector4(-0.70,0.003,0.003,0.69),Vector4(-0.61,0.018,0.025,0.58),Vector4(-0.49,0.045,0.05,0.43),Vector4(-0.34,0.067,0.065,0.29)],s,Color("c4b89a"))
			horn.position.x = side*s*0.15
	elif data.id=="mistfrill":
		Surface.frill(neck,s,c.lightened(0.08))
		for side in [-1,1]: V.piece(neck,Vector3(side*s*0.13,s*0.01,-s*0.24),Vector3(s*0.16,s*0.16,s*0.20),Color("8d9e65"),true)
	elif data.id=="stormcrest":
		for i in 5:
			var crest := Surface.profile(root,"Crest"+str(i),[Vector4(-0.12,0.008,0.01,0),Vector4(-0.05,0.035,0.24,0.22),Vector4(0.025,0.03,0.27,0.24),Vector4(0.13,0.008,0.01,0)],s,Color("78b9b5"))
			crest.position = Vector3(0,y+s*0.22,(i-2)*s*0.19)
	preload("res://scripts/creature_skin_material.gd").apply(root,data)
	TailSkin.bind(tail)
	for side in [-1,1]:
		for label in ["Front","Hind"]:
			var leg := root.get_node_or_null(label+str(side)) as Node3D
			if leg: LegSkin.bind(leg,s)
	return root

static func animate(root: Node3D, data: Dictionary, gait: float, phase: String, clock: float, speed: float, ground: Callable = Callable(), ground_normal: Callable = Callable(), physical_flight := false, pose_override: Dictionary = {}) -> void:
	var tail := root.get_node("Tail") as Node3D
	var tail_gait := gait*(1.7/GAIT_PER_METER)
	tail.rotation.y = sin(tail_gait*0.5)*0.12
	TailSkin.animate(tail,tail_gait,phase,clock)
	var neck := root.get_node("Neck") as Node3D
	neck.get_node("Jaw").transform = jaw_pose(data,phase,clock)
	charge_visuals(root,data,phase,clock)
	neck.rotation.x = 0
	neck.rotation.y = 0
	root.position.y = 0
	if phase=="windup":
		var fraction := clampf(clock/float(data.windup),0,1)
		neck.rotation.x = (0.35 if data.pattern=="charge" else -0.20)*fraction
		root.position.y = -0.45*smoothstep(0,0.4,clock) if data.pattern=="pulse" else 0.0
	elif phase=="active":
		if data.pattern=="pulse": root.position.y = -0.45*(1-smoothstep(0,0.3,clock))
	else: root.position.y = 0
	if data.pattern=="sweep":
		var load := smoothstep(0,float(data.windup),clock) if phase=="windup" else (1-smoothstep(0,0.08,clock) if phase=="active" else 0.0)
		root.position.y = -float(data.size)*0.045*load
		root.get_node("BodySurface").rotation.z = -0.08*load
		var angles := sweep_angles(phase,clock,float(data.windup),float(data.recovery))
		neck.rotation.x = angles.x
		neck.rotation.y = angles.y
	if data.pattern=="charge":
		var compression := float(data.size)*0.05
		if phase=="windup":
			var load := smoothstep(0,float(data.windup),clock)
			neck.rotation.x = 0.35*load
			root.position.y = -compression*load
		elif phase=="active":
			neck.rotation.x = 0.35
			root.position.y = -compression
		elif phase=="recover":
			var release := 1-smoothstep(0,0.55,clock)
			neck.rotation.x = 0.35*release
			root.position.y = -compression*release
	elif data.pattern=="leap":
		var compression := float(data.size)*0.10
		if phase=="windup":
			var load := smoothstep(0,float(data.windup),clock)
			neck.rotation.x = -0.20*load
			root.position.y = -compression*load
		elif phase=="active":
			var progress := clampf(clock/0.65,0,1)
			root.position.y = (0.0 if physical_flight else sin(progress*PI))-compression*(1-smoothstep(0,0.14,clock))
			neck.rotation.x = lerpf(-0.20,0.15,smoothstep(0,0.30,clock))
		elif phase=="recover":
			root.position.y = -float(data.size)*0.06*sin(clampf(clock/0.30,0,1)*PI)
			neck.rotation.x = 0.15*(1-smoothstep(0,0.40,clock))
	if data.pattern=="mist":
		if phase=="active": neck.rotation.x = -0.20+0.12*sin(clampf(clock/0.65,0,1)*PI)
		elif phase=="recover": neck.rotation.x = -0.20*(1-smoothstep(0,0.45,clock))
	elif data.pattern=="pulse" and phase=="active":
		neck.rotation.x = -0.20*(1-smoothstep(0,0.30,clock))
	if not pose_override.is_empty():
		root.position.y = float(pose_override.get("body_y",root.position.y))
		root.rotation = pose_override.get("body_rotation",root.rotation)
		neck.rotation = pose_override.get("neck_rotation",neck.rotation)
		neck.get_node("Jaw").rotation = pose_override.get("jaw_rotation",neck.get_node("Jaw").rotation)
		tail.rotation.y = float(pose_override.get("tail_y",tail.rotation.y))
	# Bend knees when the torso lowers; solve the planted foot back to actor ground.
	if phase=="idle": root.position.y -= float(data.size)*0.045*minf(speed/2,1)
	var limb_speed := speed
	if data.pattern in ["charge","leap"] and phase=="active":
		limb_speed *= smoothstep(0,0.12,clock)*(1-smoothstep(0.53,0.65,clock))
	var hip_height := float(data.size)*(0.50 if "quadruped" in data.body else 0.64)*0.9
	var targets := []
	var lowest := 0.0
	for side in [-1,1]:
		for label in ["Front","Hind"]:
			var leg := root.get_node_or_null(label+str(side)) as Node3D
			if leg:
				leg.position.y = hip_height
				leg.rotation.x = 0
				var offset := PI if label=="Front" else 0.0
				var step := gait+offset
				var foot: MeshInstance3D = leg.get_node("Foot")
				var target := Vector3(0,foot.position.y-minf(root.position.y,0),0)
				var lift := 0.0
				var foot_basis := Basis.IDENTITY
				if limb_speed>0.1:
					target.z = sin(step)*side*minf(float(data.size)*0.16,limb_speed*0.06)
					lift = maxf(0,cos(step)*side)*minf(float(data.size)*0.10,limb_speed*0.035)
					target.y += lift
				var planting := ground.is_valid() and phase=="idle" and limb_speed>0.1 and lift<0.001
				var sole_offset := Vector3(0,-float(data.size)*0.05,-float(data.size)*0.10)
				if leg.has_meta("plant_world"):
					var anchor: Vector3 = leg.to_local(leg.get_meta("plant_world"))-sole_offset
					var forward: Vector3 = leg.get_meta("plant_forward")
					if not planting or Vector2(anchor.x,anchor.z).length()>float(data.size)*0.32 or leg.global_basis.z.normalized().dot(forward)<0.8:
						leg.remove_meta("plant_world")
						leg.remove_meta("plant_forward")
					else:
						target.x = anchor.x
						target.z = anchor.z
				if ground.is_valid():
					var sample_point := leg.to_global(target+sole_offset)
					var height: float = clampf(ground.call(sample_point),-0.35,0.35)
					target.y += height
					lowest = minf(lowest,height)
					if ground_normal.is_valid():
						var normal: Vector3 = leg.global_basis.inverse()*ground_normal.call(sample_point)
						normal = Vector3.UP.lerp(normal.normalized(),1-smoothstep(0.01,float(data.size)*0.06,lift)).normalized()
						foot_basis = Basis(Quaternion(Vector3.UP,normal))
						target += sole_offset-foot_basis*sole_offset
					if planting and not leg.has_meta("plant_world"):
						leg.set_meta("plant_world",leg.to_global(target+foot_basis*sole_offset))
						leg.set_meta("plant_forward",leg.global_basis.z.normalized())
				targets.append({"leg":leg,"target":target,"foot_basis":foot_basis})
	root.position.y += lowest
	root.set_meta("ground_offset",lowest)
	for entry in targets:
		var target: Vector3 = entry.target
		target.y -= lowest
		var foot_basis: Basis = entry.foot_basis
		var feet: Dictionary = pose_override.get("feet",{})
		if feet.has(str(entry.leg.name)):
			var saved: Dictionary = feet[str(entry.leg.name)]
			var blend: float = pose_override.get("blend",1.0)
			var actor: Node3D = root.get_parent()
			var from: Vector3 = entry.leg.to_local(actor.to_global(saved.point))
			target = from.lerp(target,blend)
			var from_basis: Basis = entry.leg.global_basis.inverse()*actor.global_basis*saved.basis
			foot_basis = Basis(from_basis.get_rotation_quaternion().slerp(foot_basis.get_rotation_quaternion(),blend))
			if ground.is_valid():
				var sole_offset := Vector3(0,-float(data.size)*0.05,-float(data.size)*0.10)
				var point: Vector3 = entry.leg.to_global(target+foot_basis*sole_offset)
				var floor_y: float = actor.global_position.y+ground.call(point)
				if point.y<floor_y:
					target += entry.leg.global_basis.inverse()*Vector3.UP*(floor_y-point.y)
		LegSkin.pose(entry.leg,target,foot_basis)

static func charge_visuals(root: Node3D, data: Dictionary, phase: String, clock: float) -> void:
	var load := smoothstep(0,float(data.windup),clock) if phase=="windup" else 0.0
	if phase=="active": load = 1-smoothstep(0.08,0.45,clock)
	var frill := root.get_node("Neck").get_node_or_null("Frill") as MeshInstance3D
	if frill: frill.scale = Vector3(1+load*0.12,1+load*0.12,1)
	if data.pattern=="pulse":
		for index in 5:
			var crest := root.get_node_or_null("Crest"+str(index)) as MeshInstance3D
			if crest==null: continue
			var material := crest.material_override as StandardMaterial3D
			if material==null: continue
			material.emission_enabled = true
			material.emission = Color("78b9b5")
			material.emission_energy_multiplier = load*0.75
