extends RefCounted
const V = preload("res://scripts/visuals.gd")
const H = preload("res://scripts/hunter_model.gd")
const Surface = preload("res://scripts/creature_surface.gd")
const TailSkin = preload("res://scripts/creature_tail_skin.gd")
const LegSkin = preload("res://scripts/creature_leg_skin.gd")
const GAIT_PER_METER := 4.2
const CHARGE_NECK_PITCH := -0.35

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
	var body_profile := [Vector4(-0.56,0.08,0.12,0.03),Vector4(-0.42,0.28,0.23,0.025),Vector4(-0.15,0.37,0.285,0),Vector4(0.20,0.34,0.26,0),Vector4(0.43,0.22,0.20,-0.025),Vector4(0.56,0.08,0.12,-0.025)]
	if data.id=="thornhorn":
		body_profile = [Vector4(-0.56,0.10,0.14,0.03),Vector4(-0.42,0.32,0.27,0.035),Vector4(-0.15,0.37,0.29,0.015),Vector4(0.20,0.28,0.22,0),Vector4(0.43,0.19,0.17,-0.025),Vector4(0.56,0.08,0.11,-0.025)]
	elif data.id=="stormcrest":
		body_profile = [Vector4(-0.56,0.10,0.15,0.04),Vector4(-0.42,0.30,0.30,0.035),Vector4(-0.15,0.37,0.32,0.025),Vector4(0.20,0.32,0.25,0),Vector4(0.43,0.23,0.18,-0.025),Vector4(0.56,0.08,0.11,-0.025)]
	elif data.id=="reedclaw":
		# Keep the shoulder and hip attachments, but tuck the abdomen between
		# them: this fast leaper carries its mass in the hindquarters.
		body_profile = [Vector4(-0.56,0.08,0.12,0.03),Vector4(-0.42,0.28,0.23,0.025),Vector4(-0.15,0.35,0.27,0),Vector4(0.20,0.24,0.19,0.055),Vector4(0.43,0.22,0.20,-0.025),Vector4(0.56,0.08,0.12,-0.025)]
	var body := Surface.profile(root,"BodySurface",body_profile,s,c)
	body.position.y = y
	if data.id=="reedclaw":
		body.scale = Vector3(0.80,0.85,1)
		# Soft lateral scales belong to the continuous body, without extra hit geometry.
		var arrays: Array = body.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for vertex in vertices.size():
			var point := vertices[vertex]/s
			var oval := pow(point.y/0.19,2)+pow((point.z-0.015)/0.34,2)
			var flank := (1-smoothstep(0.50,1.0,oval))*smoothstep(0.18,0.27,absf(point.x))
			colors[vertex] = colors[vertex].lerp(Color("b2ac82"),flank*0.85)
		arrays[Mesh.ARRAY_COLOR] = colors
		var colored := ArrayMesh.new()
		colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		body.mesh = colored
	elif data.id=="mistfrill": body.scale = Vector3(0.85,0.90,1)
	var neck := V.pivot(root,"Neck",Vector3(0,y,-s*0.40))
	if data.id=="reedclaw": neck.scale = Vector3.ONE*0.88
	var head_width := 0.78 if data.id in ["reedclaw","mistfrill"] else 1.0
	var head_profile := [Vector4(-0.715,0.012*head_width,0.008,0.06),Vector4(-0.707,0.025*head_width,0.016,0.06),Vector4(-0.69,0.035*head_width,0.02,0.06),Vector4(-0.61,0.14*head_width,0.065,0.085),Vector4(-0.42,0.19*head_width,0.14,0.14),Vector4(-0.28,0.16*head_width,0.145,0.12),Vector4(-0.09,0.135,0.17,0.08),Vector4(0.12,0.10,0.15,0)]
	if data.id=="thornhorn":
		head_profile = [Vector4(-0.715,0.006,0.004,0.10),Vector4(-0.71,0.065,0.035,0.10),Vector4(-0.69,0.12,0.065,0.10),Vector4(-0.61,0.155,0.09,0.11),Vector4(-0.42,0.22,0.17,0.17),Vector4(-0.28,0.19,0.18,0.14),Vector4(-0.09,0.135,0.17,0.08),Vector4(0.12,0.10,0.15,0)]
	var head_surface := Surface.profile(neck,"HeadSurface",head_profile,s,c.lightened(0.03))
	if data.id=="mossback":
		head_surface.set_meta("unarmored_mesh",head_surface.mesh)
		var arrays: Array = head_surface.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for index in vertices.size():
			var point := vertices[index]/s
			var crown := smoothstep(0.14,0.17,point.y)
			var seam := smoothstep(0.04,0.18,absf(sin((point.z+0.02)*18)))
			colors[index] = colors[index].lerp(Color("78816b"),crown*seam*0.92)
		arrays[Mesh.ARRAY_COLOR] = colors
		var armored := ArrayMesh.new()
		armored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		head_surface.mesh = armored
	var facial_surface: TriangleMesh = head_surface.mesh.generate_triangle_mesh() if data.id=="thornhorn" else null
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
		var nose_x := 0.075*head_width
		var eye_x := 0.158*head_width
		if facial_surface!=null:
			var nose_contact := facial_surface.intersect_segment(Vector3(side*2,0.109,-0.64)*s,Vector3(0,0.109,-0.64)*s)
			var eye_contact := facial_surface.intersect_segment(Vector3(side*2,0.20,-0.43)*s,Vector3(0,0.20,-0.43)*s)
			if not nose_contact.is_empty(): nose_x = absf(nose_contact.position.x)/s+0.006
			if not eye_contact.is_empty(): eye_x = absf(eye_contact.position.x)/s+0.006
		var nostril := V.piece(neck,Vector3(side*s*nose_x,s*0.109,-s*0.64),Vector3(s*0.028,s*0.006,s*0.035),Color("26372b"),true)
		nostril.name = "Nostril"+str(side)
		nostril.material_override.albedo_color = Color("142118")
		nostril.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var eye := V.piece(neck,Vector3(side*s*eye_x,s*0.20,-s*0.43),Vector3(s*0.028,s*0.02,s*0.045),Color("dba75d"),true)
		if data.id=="thornhorn": eye.name = "Eye"+str(side)
		var pupil := V.piece(neck,Vector3(side*s*(eye_x+0.011*head_width),s*0.20,-s*0.436),Vector3(s*0.006,s*0.018,s*0.012),Color("1c2721"),true)
		if data.id=="thornhorn": pupil.name = "Pupil"+str(side)
		var brow := Surface.profile(neck,"EyeRidge"+str(side),[Vector4(-0.51,0.001,0.001,0.225),Vector4(-0.46,0.018,0.012,0.245),Vector4(-0.41,0.028,0.014,0.255),Vector4(-0.35,0.020,0.012,0.245),Vector4(-0.30,0.001,0.001,0.22)],s,c.darkened(0.14))
		brow.position.x = side*s*0.15*head_width
		if data.id=="thornhorn": brow.position.x = side*s*(eye_x-0.008)
		if data.id=="reedclaw":
			# Seat the ridge against the orbital roof instead of floating above it.
			brow.position.y = -s*0.025
		for tooth in 5:
			H.tapered(neck,Vector3(side*s*0.10*head_width,-s*0.005,s*(-0.56+tooth*0.045)),s*0.014,s*0.001,s*0.06,Color("c6c5aa"))
			H.tapered(jaw,Vector3(side*s*0.095*head_width,-s*0.015,s*(-0.5375+tooth*0.045))-hinge,s*0.001,s*0.010,s*0.035,Color("b6b79d"))
		for front in ([false,true] if quad else [false]):
			var leg := V.pivot(root,("Front" if front else "Hind")+str(side),Vector3(side*s*0.29,y*0.9,-s*0.31 if front else s*0.28))
			var bottom := -y*0.9/s+0.075
			var leg_surface := Surface.vertical(leg,"LegSurface",[Vector4(bottom,0.055,0.06,0.025),Vector4(bottom*0.78,0.066,0.075,0.05),Vector4(bottom*0.56,0.092,0.09,-0.04),Vector4(bottom*0.28,0.13,0.12,-0.02),Vector4(0.025,0.16,0.16,0),Vector4(0.11,0.14,0.14,0),Vector4(0.19,0.055,0.065,0),Vector4(0.205,0.005,0.005,0)],s,c)
			LegSkin.shape_attachment(leg_surface,s,side)
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
			if data.id=="reedclaw":
				var wrist := V.pivot(arm,"Wrist",Vector3(0,-s*0.13,-s*0.22))
				Surface.profile(wrist,"Palm",[Vector4(-0.075,0.036,0.025,-0.01),Vector4(-0.035,0.054,0.035,0),Vector4(0.025,0.024,0.030,0.015)],s,c)
				for digit in [-1,0,1]:
					var finger := V.pivot(wrist,"Digit"+str(digit),Vector3(digit*s*0.034,0,-s*0.04))
					finger.rotation.y = -digit*0.20
					Surface.profile(finger,"Finger",[Vector4(-0.075,0.012,0.016,-0.012),Vector4(-0.035,0.018,0.021,0),Vector4(0.01,0.016,0.020,0)],s,c)
					Surface.profile(finger,"Talon",[Vector4(-0.17,0.0015,0.002,-0.082),Vector4(-0.15,0.005,0.009,-0.040),Vector4(-0.12,0.010,0.016,-0.014),Vector4(-0.07,0.013,0.018,-0.012)],s,Color("c1b99a"))
	var tail := V.pivot(root,"Tail",Vector3(0,y*0.85,s*0.45))
	var length := 1.55 if data.id=="reedclaw" else (0.85 if data.id=="thornhorn" else 1.10)
	var tail_profile := [Vector4(-0.06,0.14,0.15,0),Vector4(0.14*length,0.125,0.125,-0.015),Vector4(0.40*length,0.085,0.085,-0.035),Vector4(0.70*length,0.045,0.04,-0.055),Vector4(0.96*length,0.008,0.008,-0.065)]
	if data.id=="mossback":
		tail_profile = [Vector4(-0.06,0.14,0.15,0),Vector4(0.40*length,0.05,0.055,-0.035),Vector4(0.73*length,0.165,0.13,-0.055),Vector4(0.86*length,0.155,0.13,-0.055),Vector4(0.96*length,0.025,0.025,-0.065)]
	var tail_surface := Surface.profile(tail,"TailSurface",tail_profile,s,c)
	if data.id=="mossback":
		var arrays: Array = tail_surface.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for vertex in vertices.size():
			colors[vertex] = colors[vertex].lerp(Color("a29d81"),0.75*smoothstep(0.50*length,0.69*length,vertices[vertex].z/s))
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		tail_surface.mesh = mesh
	if data.id=="mossback":
		for i in 5:
			var taper := 1.0-absf(i-2)*0.12
			var plate := Surface.profile(root,"ArmorPlate"+str(i),[Vector4(-0.13,0.28*taper,0.06*taper,0),Vector4(-0.07,0.37*taper,0.24*taper,0),Vector4(0.09,0.35*taper,0.21*taper,0),Vector4(0.14,0.27*taper,0.05*taper,0)],s,c.darkened(0.16),-PI/2,PI/2,false)
			plate.position = Vector3(0,y+s*0.045,(i-2)*s*0.18)
			plate.set_meta("body_bind",body.transform.affine_inverse()*plate.transform)
			plate.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif data.id=="thornhorn":
		for side in [-1,1]:
			var horn := Surface.profile(neck,"BrowHorn"+str(side),[Vector4(-0.70,0.003,0.003,0.69),Vector4(-0.61,0.018,0.025,0.58),Vector4(-0.49,0.045,0.05,0.43),Vector4(-0.34,0.067,0.065,0.29)],s,Color("c4b89a"))
			horn.position.x = side*s*0.15
	elif data.id=="mistfrill":
		Surface.frill(neck,s,c.lightened(0.08))
		for side in [-1,1]:
			var sac := V.piece(neck,Vector3(side*s*0.13,-s*0.015,-s*0.24),Vector3(s*0.14,s*0.20,s*0.25),Color("8d9e79"),true)
			sac.name = "MistSac"+str(side)
			sac.set_meta("rest_scale",sac.scale)
	elif data.id=="stormcrest":
		for i in 5:
			var height: float = [0.42,0.80,1.0,0.76,0.38][i]
			var crest := Surface.profile(root,"Crest"+str(i),[Vector4(-0.125,0.012,0.015,0),Vector4(-0.075,0.026,0.09*height,0.08*height),Vector4(-0.025,0.030,0.22*height,0.21*height),Vector4(0.015,0.020,0.24*height,0.23*height),Vector4(0.055,0.010,0.20*height,0.20*height),Vector4(0.115,0.008,0.015,0)],s,c)
			crest.position = Vector3(0,y+s*0.22,(i-2)*s*0.19)
			var arrays: Array = crest.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors := PackedColorArray()
			for vertex in vertices:
				colors.append(c.darkened(0.12).lerp(Color("6b8e8c"),smoothstep(0.02,0.40*height,vertex.y/s)))
			arrays[Mesh.ARRAY_COLOR] = colors
			var crest_mesh := ArrayMesh.new()
			crest_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			crest.mesh = crest_mesh
	preload("res://scripts/creature_skin_material.gd").apply(root,data)
	TailSkin.bind(tail)
	for side in [-1,1]:
		for label in ["Front","Hind"]:
			var leg := root.get_node_or_null(label+str(side)) as Node3D
			if leg: LegSkin.bind(leg,s)
	return root

static func animate(root: Node3D, data: Dictionary, gait: float, phase: String, clock: float, speed: float, ground: Callable = Callable(), ground_normal: Callable = Callable(), physical_flight := false, pose_override: Dictionary = {}) -> void:
	root.get_node("BodySurface").rotation.z = 0.0
	# Front limbs articulate at their shoulder attachment, independently of gait.
	# Carry the loaded silhouette into takeoff, then reach before landing.
	for side in [-1,1]:
		var arm := root.get_node_or_null("Forelimb"+str(side)) as Node3D
		if arm==null: continue
		var spread := 0.0
		var reach := 0.0
		if data.pattern=="leap":
			if phase=="windup":
				var load := smoothstep(0,float(data.windup),clock)
				spread = 0.55*load
				reach = -0.30*load
			elif phase=="active":
				var release := smoothstep(0.04,0.22,clock)
				var land := smoothstep(0.43,0.65,clock)
				spread = lerpf(0.55,0.18,release)*(1-land)
				reach = lerpf(-0.30,0.65,release)*(1-land)
			elif phase=="recover":
				var brace := smoothstep(0,0.12,clock)*(1-smoothstep(float(data.recovery)*0.6,float(data.recovery),clock))
				spread = 0.30*brace
				reach = -0.18*brace
		arm.rotation = Vector3(reach,0,-side*spread)
		var wrist := arm.get_node_or_null("Wrist") as Node3D
		if wrist!=null:
			var opened := smoothstep(0,float(data.windup),clock) if phase=="windup" else 0.0
			var grasp := 0.0
			if phase=="active":
				var release := smoothstep(0.04,0.22,clock)
				var settle := 1-smoothstep(0.43,0.65,clock)
				opened = (1-release)*settle
				grasp = release*settle
			wrist.rotation.x = 0.25*opened-0.35*grasp
			for digit in [-1,0,1]:
				var finger: Node3D = wrist.get_node("Digit"+str(digit))
				finger.rotation = Vector3(-0.30*grasp,-digit*(0.20+0.16*opened+0.08*grasp),0)
	var tail := root.get_node("Tail") as Node3D
	var tail_gait := gait*(1.7/GAIT_PER_METER)
	tail.rotation.y = sin(tail_gait*0.5)*0.12
	tail.rotation.x = 0
	TailSkin.animate(tail,tail_gait,phase,clock)
	var neck := root.get_node("Neck") as Node3D
	neck.get_node("Jaw").transform = jaw_pose(data,phase,clock)
	charge_visuals(root,data,phase,clock,phase=="stagger")
	neck.rotation.x = 0
	neck.rotation.y = 0
	root.position.y = 0
	if phase=="windup":
		var fraction := clampf(clock/float(data.windup),0,1)
		neck.rotation.x = (CHARGE_NECK_PITCH if data.pattern=="charge" else -0.20)*fraction
		root.position.y = -float(data.size)*0.30*smoothstep(0,0.4,clock) if data.pattern=="pulse" else 0.0
	elif phase=="active":
		if data.pattern=="pulse": root.position.y = -float(data.size)*0.30*(1-smoothstep(0,0.3,clock))
	else: root.position.y = 0
	if data.pattern=="sweep":
		var load := smoothstep(0,float(data.windup),clock) if phase=="windup" else (1-smoothstep(0,0.08,clock) if phase=="active" else 0.0)
		root.position.y = -float(data.size)*0.045*load
		root.get_node("BodySurface").rotation.z = -0.08*load
		var angles := sweep_angles(phase,clock,float(data.windup),float(data.recovery))
		neck.rotation.x = angles.x
		neck.rotation.y = angles.y
	if data.pattern=="charge":
		var charge_pitch := CHARGE_NECK_PITCH
		if ground_normal.is_valid() and phase in ["windup","active","recover"]:
			var up: Vector3 = root.global_basis.inverse()*ground_normal.call(root.global_position)
			var incline := atan2(up.z,up.y)
			# The level torso lowers to the downhill support foot. Allow extra
			# clearance uphill so the long jaw does not enter the rising bank.
			charge_pitch += clampf(incline*(1.5 if incline>0 else 1.0),-0.30,0.50)
		var compression := float(data.size)*0.05
		if phase=="windup":
			var load := smoothstep(0,float(data.windup),clock)
			neck.rotation.x = charge_pitch*load
			root.position.y = -compression*load
		elif phase=="active":
			neck.rotation.x = charge_pitch
			root.position.y = -compression
		elif phase=="recover":
			var release := 1-smoothstep(0,0.55,clock)
			neck.rotation.x = charge_pitch*release
			root.position.y = -compression*release
	elif data.pattern=="leap":
		var compression := float(data.size)*0.16
		if phase=="windup":
			var load := smoothstep(0,float(data.windup),clock)
			neck.rotation.x = -0.20*load
			root.position.y = -compression*load
			tail.rotation.x = -0.22*load
		elif phase=="active":
			var progress := clampf(clock/0.65,0,1)
			root.position.y = (0.0 if physical_flight else sin(progress*PI))-compression*(1-smoothstep(0,0.14,clock))
			neck.rotation.x = lerpf(-0.20,0.15,smoothstep(0,0.30,clock))
			tail.rotation.x = -0.22*(1-smoothstep(0,0.30,clock))
		elif phase=="recover":
			var brace := smoothstep(0,0.12,clock)*(1-smoothstep(float(data.recovery)*0.6,float(data.recovery),clock))
			root.position.y = -float(data.size)*(0.06*sin(clampf(clock/0.30,0,1)*PI)+0.025*brace)
			neck.rotation.x = 0.15*(1-smoothstep(0,0.40,clock))
			# Short forelimbs balance the landing; hind legs carry its weight.
			# Keep the tail extended here to distinguish recovery from coiling.
			tail.rotation.x = -0.06*brace
	if data.pattern=="mist":
		if phase=="active": neck.rotation.x = -0.20+0.12*sin(clampf(clock/0.65,0,1)*PI)
		elif phase=="recover": neck.rotation.x = -0.20*(1-smoothstep(0,0.45,clock))
	elif data.pattern=="pulse" and phase=="active":
		neck.rotation.x = -0.20*(1-smoothstep(0,0.30,clock))
	if not pose_override.is_empty():
		root.position.y = float(pose_override.get("body_y",root.position.y))
		root.rotation = pose_override.get("body_rotation",root.rotation)
		root.get_node("BodySurface").rotation = pose_override.get("body_surface_rotation",root.get_node("BodySurface").rotation)
		neck.rotation = pose_override.get("neck_rotation",neck.rotation)
		neck.get_node("Jaw").rotation = pose_override.get("jaw_rotation",neck.get_node("Jaw").rotation)
		tail.rotation.y = float(pose_override.get("tail_y",tail.rotation.y))
		tail.rotation = pose_override.get("tail_rotation",tail.rotation)
		# Start an interrupted grasp from the actual shoulder, wrist and claw pose.
		var forelimbs: Dictionary = pose_override.get("forelimbs",{})
		for path in forelimbs:
			var part: Node3D = root.get_node(path)
			var captured: Vector3 = forelimbs[path]
			part.rotation = captured.lerp(part.rotation,float(pose_override.get("blend",1.0)))
	# Additive recoil never pauses AI. Stagger owns its captured-pose transition.
	var impact_age: float = root.get_meta("impact_age",0.26)
	if impact_age<0.26 and phase!="stagger":
		var weight := smoothstep(0,0.045,impact_age)*(1-smoothstep(0.045,0.26,impact_age))
		var impulse: Vector3 = root.get_meta("impact_rotation",Vector3.ZERO)
		neck.rotation += Vector3(impulse.x,impulse.y,0)*weight
		root.get_node("BodySurface").rotation.z += impulse.z*weight
		# A delayed counter-swing balances the head without moving planted feet.
		var balance := smoothstep(0.025,0.09,impact_age)*(1-smoothstep(0.09,0.26,impact_age))
		tail.rotation.y -= impulse.y*0.65*balance
	if data.id=="mossback":
		var trunk: MeshInstance3D = root.get_node("BodySurface")
		for index in 5:
			var plate: MeshInstance3D = root.get_node("ArmorPlate"+str(index))
			var bind: Transform3D = plate.get_meta("body_bind")
			var attached := trunk.transform*bind
			if not plate.transform.is_equal_approx(attached): plate.transform = attached
	# Bend knees when the torso lowers; solve the planted foot back to actor ground.
	if phase=="idle": root.position.y -= float(data.size)*0.045*minf(speed/2,1)
	var limb_speed := speed
	if data.pattern in ["charge","leap"] and phase=="active":
		limb_speed *= smoothstep(0,0.12,clock)*(1-smoothstep(0.53,0.65,clock))
	# A leap has one takeoff and landing, rather than a running cycle in the air.
	if data.pattern=="leap" and phase=="active": limb_speed = 0.0
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
				if data.pattern=="leap" and phase=="active":
					var tuck := smoothstep(0.04,0.24,clock)*(1-smoothstep(0.40,0.63,clock))
					# Slight asymmetry keeps both feet readable in the silhouette.
					lift = float(data.size)*0.17*tuck
					target.y += lift
					target.z = float(data.size)*(0.14 if side==1 else 0.10)*tuck
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

static func charge_visuals(root: Node3D, data: Dictionary, phase: String, clock: float, weak_brace := false) -> void:
	var load := smoothstep(0,float(data.windup),clock) if phase=="windup" else 0.0
	if phase=="active": load = 1-smoothstep(0.08,0.45,clock)
	var frill := root.get_node("Neck").get_node_or_null("Frill") as MeshInstance3D
	if frill: frill.scale = Vector3(1+load*0.12,1+load*0.12,1)
	if data.pattern=="mist":
		for side in [-1,1]:
			var sac: MeshInstance3D = root.get_node("Neck/MistSac"+str(side))
			var rest: Vector3 = sac.get_meta("rest_scale")
			var swelling := rest*Vector3(1+load*0.45,1+load*0.30,1+load*0.20)
			if not sac.scale.is_equal_approx(swelling): sac.scale = swelling
			var material := sac.material_override as StandardMaterial3D
			var color := Color("8d9e79").lerp(Color("c3bd83"),load*0.65)
			if not material.albedo_color.is_equal_approx(color): material.albedo_color = color
	if data.pattern=="pulse":
		for index in 5:
			var crest := root.get_node_or_null("Crest"+str(index)) as MeshInstance3D
			if crest==null: continue
			var material := crest.material_override as StandardMaterial3D
			if material==null: continue
			# Charge travels from the tail end toward the head. Amber means the
			# attack was interrupted but the spine is still open for punishment.
			var delay := float(4-index)*0.10
			var charge := smoothstep(delay,delay+0.55,load)
			var emission := Color("e2b968") if weak_brace else Color("78b9b5")
			var energy := 0.65 if weak_brace else charge*1.10
			if not material.emission_enabled: material.emission_enabled = true
			if not material.emission.is_equal_approx(emission): material.emission = emission
			if not is_equal_approx(material.emission_energy_multiplier,energy): material.emission_energy_multiplier = energy
