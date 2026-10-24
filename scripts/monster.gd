extends CharacterBody3D
const CombatAudio = preload("res://scripts/combat_audio.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Hazard = preload("res://scripts/hazard.gd")
const CreatureModel = preload("res://scripts/creature_model.gd")
const Parts = preload("res://scripts/monster_parts.gd")
const StaggerPose = preload("res://scripts/creature_stagger_pose.gd")
const Defeat = preload("res://scripts/creature_defeat.gd")
var defeat = Defeat.new()
var stagger_pose = StaggerPose.new()
var was_staggering := false
var stagger_recovery := false
const TailContact = preload("res://scripts/tail_contact.gd")
const LungeWarning = preload("res://scripts/lunge_warning.gd")
const HeadWarning = preload("res://scripts/head_sweep_warning.gd")
var head_warning_hull := PackedVector2Array()
var head_warning_transform := Transform3D.IDENTITY
const LEAP_DURATION := 0.65
const LEAP_HEIGHT := 1.0
const LEAP_GRAVITY := 8.0*LEAP_HEIGHT/(LEAP_DURATION*LEAP_DURATION)
const LEAP_SPEED := 4.0*LEAP_HEIGHT/LEAP_DURATION
var airborne_leap := false
var lunge_tell: MeshInstance3D
var lunge_origin := Vector3.ZERO
var wall_stun := 0.0
var tail_rings: Array[Vector4] = []
var previous_tail_rings: Array[Vector4] = []
var head_rings: Array = []
var previous_head := Transform3D.IDENTITY
var previous_head_target := Vector3.ZERO
var previous_head_epoch := -1
var previous_tail := Transform3D.IDENTITY
var previous_target_feet := Vector3.ZERO
var previous_motion_epoch := -1
var armor_integrity := 200.0
var route := PackedVector3Array()
var route_time := 0.0
var gait := 0.0
var weak_marker: MeshInstance3D
var weak_markers: Array[MeshInstance3D] = []
var data: Dictionary
var target: CharacterBody3D
var health := 0.0
var phase := "idle"
var clock := 0.0
var stagger := 0.0
var target_point := Vector3.ZERO
var lunge_direction := Vector3.FORWARD
var mesh: Node3D
var tell: MeshInstance3D
var area_warning_center := Vector3.INF
var label: Label3D
var attack_done := false
var rear_attack := false
var rear_cooldown := 0.0
var rear_tell: MeshInstance3D
var disrupted := 0.0
var exposed := 0.0
var impact_time := 0.0
var impact_material: StandardMaterial3D
var impact_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	collision_mask = 3
	health = float(data.health)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = float(data.size)*0.34
	shape.height = float(data.size)*1.1
	collider.shape = shape
	collider.position.y = shape.height/2
	add_child(collider)
	mesh = CreatureModel.create(self,data)
	tail_rings = TailContact.profile(mesh.get_node("Tail/TailSurface").mesh)
	for part in ["HeadSurface","Jaw"]: head_rings.append(TailContact.profile(mesh.get_node("Neck/"+part).mesh))
	if data.pattern=="sweep": head_warning_hull = HeadWarning.profile(self)
	previous_head = mesh.get_node("Neck").global_transform
	previous_tail = mesh.get_node("Tail").global_transform
	previous_tail_rings = tail_rings.duplicate()
	impact_material = Visuals.mat(Color.WHITE,true)
	impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for part in mesh.find_children("*","MeshInstance3D",true,false): impact_meshes.append(part)
	var s: float = data.size
	var marker_pos := Vector3(0,s*0.58,s*0.48)
	if data.id=="stormcrest": marker_pos = Vector3(0,s*1.12,s*0.15)
	if data.weak_side=="front": marker_pos = Vector3(0,s*0.78,-s*0.70)
	elif data.weak_side=="flank": marker_pos = Vector3(s*0.37,s*0.58,0)
	weak_marker = Visuals.piece(mesh,marker_pos,Vector3(0.22,0.22,0.22),Color("e6c57c"),true)
	weak_marker.material_override = Visuals.mat(Color("e6c57c"),true)
	weak_markers.append(weak_marker)
	if data.weak_side=="flank":
		var second := Visuals.piece(mesh,Vector3.ZERO,Vector3(0.22,0.22,0.22),Color("e6c57c"),true)
		weak_markers.append(second)
	update_weak_markers()
	tell = Visuals.piece(self,Vector3(0,0.05,0),Vector3(float(data.reach)*2,0.025,float(data.reach)*2),Color("b48848"),true)
	tell.visible = false
	rear_tell = MeshInstance3D.new()
	var sector := SurfaceTool.new()
	sector.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a := lerpf(-1.3,1.3,float(i)/32)
		var b := lerpf(-1.3,1.3,float(i+1)/32)
		for point in [Vector3.ZERO,Vector3(sin(a),0,cos(a)),Vector3(sin(b),0,cos(b))]: sector.add_vertex(point)
	sector.generate_normals()
	rear_tell.mesh = sector.commit()
	rear_tell.material_override = Visuals.mat(Color("d3a45a"),true)
	rear_tell.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	rear_tell.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rear_tell.material_override.albedo_color.a = 0.38
	rear_tell.position.y = 0.08
	rear_tell.visible = false
	add_child(rear_tell)
	lunge_tell = LungeWarning.new()
	add_child(lunge_tell)
	label = Label3D.new()
	label.position.y = float(data.size)*1.5
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	add_to_group("monsters")

func weak_part_active(part: String) -> bool:
	if health<=0: return false
	if data.id=="stormcrest": return part=="spine" and (phase=="windup" or stagger>0)
	return (data.weak_side=="rear" and part=="tail") or (data.weak_side=="flank" and part=="flank" and exposed>0) or (data.weak_side=="front" and part=="head" and phase=="windup")

func update_weak_markers() -> void:
	for marker in weak_markers: marker.hide()
	var index := 0
	for part in Parts.volumes(self):
		if not weak_part_active(part.id) or index>=weak_markers.size(): continue
		var marker := weak_markers[index]
		marker.show()
		var outward: Vector3 = part.center-global_position
		outward.y = 0
		if outward.length_squared()<0.001: outward = Vector3.UP
		marker.global_position = part.center+outward.normalized()*float(part.radius)*0.75
		index += 1

func combat_hint() -> String:
	if health<=0: return "已击退"
	if wall_stun>0: return "撞击失衡 · 侧腹暴露"
	if stagger>0: return "失衡 · 可追击"
	if rear_attack and phase=="windup": return "摆尾蓄势 · 离开后方扇区"
	if rear_attack and phase=="active": return "摆尾中 · 避开尾部"
	if phase=="windup":
		if data.pattern in ["charge","leap"]:
			return "方向已锁定 · 横向避开" if clock>=float(data.windup)*0.7 else "蓄势跟踪 · 留意直线通道"
		if data.pattern=="mist": return "喷雾蓄势 · 头颈雾囊暴露"
		if data.pattern=="pulse": return "蓄能中 · 攻击背棘可打断"
		return "横扫蓄势 · 留意头部运动"
	if phase=="active":
		if data.pattern=="mist": return "毒雾生效 · 离开毒雾范围"
		if data.pattern=="pulse": return "放电中 · 离开近身范围"
		if data.pattern=="charge": return "冲锋中 · 横向避开"
		if data.pattern=="leap": return "扑跃中 · 横向避开"
		return "横扫中 · 躲避或正面格挡"
	if phase=="recover": return "收势 · 寻找弱点追击"
	return ""

func update_nameplate() -> void:
	label.visible = health>0 and is_instance_valid(target) and target.combat.health>0 and target.lock_target!=self and global_position.distance_to(target.global_position)<=18
	if not label.visible: return
	label.text = "%s  %d/%d" % [data.name,ceili(health),int(data.health)]
	var hint := combat_hint()
	if hint!="": label.text += "\n"+hint

func show_impact(weak: bool) -> void:
	impact_time = 0.12
	impact_material.albedo_color = Color(1.0,0.77,0.30,0.32) if weak else Color(0.58,0.95,0.88,0.24)
	impact_material.emission = impact_material.albedo_color
	for part in impact_meshes: part.material_overlay = impact_material

func _process(delta: float) -> void:
	update_nameplate()
	update_weak_markers()
	if impact_time<=0: return
	impact_time = maxf(0,impact_time-delta)
	impact_material.albedo_color.a = minf(impact_material.albedo_color.a,impact_time*2.7)
	if impact_time==0:
		for part in impact_meshes: part.material_overlay = null

func _physics_process(delta: float) -> void:
	wall_stun = maxf(0,wall_stun-delta)
	rear_cooldown = maxf(0,rear_cooldown-delta)
	rear_tell.visible = false
	lunge_tell.visible = false
	if health <= 0:
		CreatureModel.charge_visuals(mesh,data,"idle",0)
		collision_layer = 0
		# A defeated airborne body still falls onto world geometry without blocking actors.
		collision_mask = 2 if not is_on_floor() else 0
		if not is_on_floor():
			velocity.y -= (LEAP_GRAVITY if airborne_leap else 25.0)*delta
			velocity.x = move_toward(velocity.x,0,8*delta)
			velocity.z = move_toward(velocity.z,0,8*delta)
			move_actor()
			if is_on_floor(): collision_mask = 0
		for marker in weak_markers: marker.hide()
		defeat.update(self,delta)
		tell.visible = false
		label.text = str(data.name)+" 已击退"
		return
	update_nameplate()
	update_weak_markers()
	stagger = maxf(0,stagger-delta)
	exposed = maxf(0,exposed-delta)
	if not is_on_floor(): velocity.y -= (LEAP_GRAVITY if airborne_leap else 25.0)*delta
	if stagger > 0:
		if not was_staggering: stagger_pose.begin(self)
		was_staggering = true
		stagger_recovery = true
		rear_attack = false
		CreatureModel.charge_visuals(mesh,data,"recover",0)
		phase = "recover"
		clock = 0
		tell.visible = false
		velocity.x = move_toward(velocity.x,0,8*delta)
		velocity.z = move_toward(velocity.z,0,8*delta)
		move_actor()
		stagger_pose.apply(self,delta)
		return
	was_staggering = false
	if not is_instance_valid(target):
		CreatureModel.charge_visuals(mesh,data,"idle",0)
		phase = "idle"
		tell.visible = false
		velocity.x = 0
		velocity.z = 0
		move_actor()
		return
	if target.combat.health<=0:
		CreatureModel.charge_visuals(mesh,data,"idle",0)
		phase = "idle"
		tell.visible = false
		velocity.x = 0
		velocity.z = 0
		move_actor()
		return
	var offset := target.global_position-global_position
	offset.y = 0
	var distance := offset.length()
	clock += delta
	route_time -= delta
	velocity.x = 0
	velocity.z = 0
	if rear_attack and phase!="idle":
		advance_rear_attack(delta)
		return
	if phase == "idle":
		if distance < 20 and target.combat.health > 0:
			if distance > float(data.reach)*0.82 or not clear_line_to(target.global_position):
				if route_time<=0:
					route = get_parent().navigation.path(global_position,target.global_position,float(data.size)*0.34)
					route_time = 0.6
				while not route.is_empty() and Vector2(route[0].x-global_position.x,route[0].z-global_position.z).length()<0.75: route.remove_at(0)
				var chase := Vector3.ZERO
				if not route.is_empty():
					chase = route[0]-global_position
					chase.y = 0
					chase = chase.normalized()
				rotation.y = lerp_angle(rotation.y,atan2(-chase.x,-chase.z),delta*2.5)
				velocity += chase*float(data.speed)
			else:
				rear_attack = data.has("rear_attack") and rear_cooldown<=0 and offset.normalized().dot(-global_basis.z)< -0.35
				if rear_attack: rear_cooldown = 5.0
				CombatAudio.emit_at(get_parent(),"warning",global_position+Vector3.UP*float(data.size)*0.7)
				phase = "windup"
				clock = 0
				target_point = target.global_position
				lunge_origin = global_position
				attack_done = false
				disrupted = 0
	elif phase == "windup":
		tell.visible = true
		tell.material_override.albedo_color = Color("71cce4") if data.pattern=="pulse" else (Color("93ae55") if data.pattern=="mist" else Color("c39a55"))
		if clock < float(data.windup)*0.7:
			target_point = target.global_position
			if data.pattern!="pulse": rotation.y = lerp_angle(rotation.y,atan2(-offset.x,-offset.z),delta*2)
		if data.pattern in ["mist","pulse"]:
			update_area_warning(target_point if data.pattern=="mist" else global_position,4.0 if data.pattern=="mist" else float(data.reach))
		if data.pattern=="sweep":
			tell.top_level = true
			tell.global_transform = Transform3D.IDENTITY
			if head_warning_transform!=global_transform or not tell.mesh is ArrayMesh:
				head_warning_transform = global_transform
				tell.mesh = HeadWarning.build(self,head_warning_hull)
			tell.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tell.material_override.albedo_color.a = 0.28
			tell.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
			tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if data.pattern in ["charge","leap"]:
			var heading := target_point-lunge_origin
			heading.y = 0
			heading = heading.normalized()
			if heading.is_zero_approx(): heading = -global_basis.z
			lunge_tell.configure(lunge_origin,heading,float(data.size)*0.34+0.32,(13.0 if data.pattern=="charge" else 10.0)*0.65+3.8)
			lunge_tell.visible = true
			tell.visible = false
		mesh.rotation.x = sin(clock*12)*0.05
		if clock >= float(data.windup):
			if data.pattern in ["charge","leap"]:
				lunge_direction = target_point-global_position
				lunge_direction.y = 0
				lunge_direction = lunge_direction.normalized()
				if lunge_direction.is_zero_approx(): lunge_direction = -global_basis.z
			if data.pattern=="leap" and is_on_floor():
				airborne_leap = true
				velocity.y = LEAP_SPEED
			phase = "active"
			clock = 0
	elif phase == "active":
		if data.pattern in ["charge","leap"]: lunge_tell.visible = true
		if data.pattern=="mist" and not attack_done:
			attack_done = true
			if clear_line_to(target_point): spawn_hazard(target_point,4.0,6.0,9.0,"mist")
		elif data.pattern=="pulse" and not attack_done:
			attack_done = true
			spawn_hazard(global_position,float(data.reach),0.7,float(data.damage),"pulse")
		if data.pattern in ["charge","leap"]:
			velocity += lunge_direction*(13 if data.pattern == "charge" else 10)
		if not attack_done and data.pattern!="sweep":
			var forward := offset.normalized().dot(-global_basis.z)>-0.15
			var in_range: bool = lunge_contains(target.global_position) if data.pattern in ["charge","leap"] else distance<float(data.reach) and forward
			if in_range and clear_line_to(target.global_position):
				attack_done = true
				target.take_damage(float(data.damage),global_position,data.pattern not in ["mist","pulse"])
		if clock > 0.65:
			phase = "recover"
			clock = 0
			tell.visible = false
			lunge_tell.visible = false
			exposed = float(data.recovery)
	elif phase == "recover":
		mesh.rotation.x = lerpf(mesh.rotation.x,0,delta*6)
		if clock >= float(data.recovery):
			phase = "idle"
			clock = 0
	move_actor()
	if phase=="active" and not rear_attack and data.pattern in ["charge","leap"]:
		for index in get_slide_collision_count():
			var collision := get_slide_collision(index)
			var normal := collision.get_normal()
			if collision.get_collider() is StaticBody3D and absf(normal.y)<0.45 and normal.dot(lunge_direction)< -0.55:
				phase = "recover"
				clock = 0
				wall_stun = 0.6
				stagger = maxf(stagger,wall_stun)
				exposed = float(data.recovery)+wall_stun
				velocity.x = 0
				velocity.z = 0
				lunge_tell.hide()
				tell.hide()
				show_impact(true)
				break
	# Presentation cadence follows travel without turning a lunge into rapid foot flutter.
	gait += delta*minf(Vector2(velocity.x,velocity.z).length(),float(data.speed)*1.2)*CreatureModel.GAIT_PER_METER
	var grounded_pose: bool = is_on_floor() and not (phase=="active" and data.pattern=="leap")
	if phase!="recover": stagger_recovery = false
	CreatureModel.animate(mesh,data,gait,phase,clock,Vector2(velocity.x,velocity.z).length(),foot_ground_height if grounded_pose else Callable(),foot_ground_normal if grounded_pose else Callable(),data.pattern=="leap",StaggerPose.neutral() if stagger_recovery else {})
	var head: Transform3D = mesh.get_node("Neck").global_transform
	if data.pattern=="sweep" and phase=="active" and clock>=0.08 and clock<=0.45 and not attack_done:
		var start: Vector3 = previous_head_target if target.motion_epoch==previous_head_epoch else target.global_position
		for rings in head_rings:
			var contact := TailContact.contact(rings,previous_head,head,target.global_position,start)
			if not contact.is_empty() and clear_line_to(contact.feet):
				attack_done = true
				target.take_damage(float(data.damage),global_position,true)
				break
	previous_head = head
	previous_head_target = target.global_position
	previous_head_epoch = target.motion_epoch


func update_area_warning(center: Vector3, radius: float) -> void:
	# Cache only a stationary world-space disc; actor turning must not rotate its terrain fit.
	tell.top_level = true
	tell.global_transform = Transform3D(Basis.IDENTITY,center)
	if center!=area_warning_center:
		area_warning_center = center
		tell.mesh = Hazard.ground_disc(tell,radius)
	tell.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tell.material_override.albedo_color.a = 0.28
	tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func move_actor() -> void:
	move_and_slide()
	if airborne_leap and is_on_floor(): airborne_leap = false

func foot_ground_height(point: Vector3) -> float:
	var hit := foot_ground_sample(point)
	return 0.0 if hit.is_empty() else hit.position.y-global_position.y

func foot_ground_normal(point: Vector3) -> Vector3:
	var hit := foot_ground_sample(point)
	return Vector3.UP if hit.is_empty() else hit.normal

func foot_ground_sample(point: Vector3) -> Dictionary:
	point.y = global_position.y
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.8,point-Vector3.UP,2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y<0.72: return {}
	return hit

func lunge_contains(point: Vector3) -> bool:
	var offset := point-global_position
	var side := Vector3(lunge_direction.z,0,-lunge_direction.x)
	var along := offset.dot(lunge_direction)
	return absf(offset.y)<2.5 and along>= -0.32 and along<3.8 and absf(offset.dot(side))<float(data.size)*0.34+0.32

func rear_contains(point: Vector3) -> bool:
	var local := to_local(point)
	var horizontal := Vector2(local.x,local.z)
	return absf(local.y)<2.5 and horizontal.length()<float(data.rear_attack.reach) and horizontal.normalized().dot(Vector2(0,1))>cos(1.3)

func advance_rear_attack(delta: float) -> void:
	var move: Dictionary = data.rear_attack
	tell.visible = false
	rear_tell.visible = phase in ["windup","active"]
	rear_tell.scale = Vector3(float(move.reach),1,float(move.reach))
	var tail_yaw := 0.0
	if phase=="windup":
		tail_yaw = -0.9*smoothstep(0,float(move.windup),clock)
		if clock>=float(move.windup):
			phase = "active"
			clock = 0
	elif phase=="active":
		tail_yaw = lerpf(-0.9,0.9,smoothstep(0,0.50,clock))
		if clock>=0.65:
			phase = "recover"
			clock = 0
			exposed = float(move.recovery)
			rear_tell.visible = false
	elif phase=="recover":
		tail_yaw = 0.9*(1-smoothstep(0,float(move.recovery),clock))
		if clock>=float(move.recovery):
			phase = "idle"
			clock = 0
			rear_attack = false
	move_actor()
	CreatureModel.animate(mesh,data,gait,"idle",0,0,foot_ground_height if is_on_floor() else Callable(),foot_ground_normal if is_on_floor() else Callable())
	mesh.rotation.x = lerpf(mesh.rotation.x,0,delta*6)
	mesh.get_node("Tail").rotation.y = tail_yaw
	var current_tail: Transform3D = mesh.get_node("Tail").global_transform
	var current_rings := CreatureModel.TailSkin.contact_profile(mesh.get_node("Tail"),tail_rings)
	if phase=="active" and clock<=0.55 and not attack_done:
		var start: Vector3 = previous_target_feet if target.motion_epoch==previous_motion_epoch else target.global_position
		var contact := TailContact.contact(current_rings,previous_tail,current_tail,target.global_position,start,previous_tail_rings)
		if not contact.is_empty() and rear_contains(contact.feet) and clear_line_to(contact.feet):
			attack_done = true
			target.take_damage(float(move.damage),global_position,true)
	previous_tail = current_tail
	previous_tail_rings = current_rings
	previous_target_feet = target.global_position
	previous_motion_epoch = target.motion_epoch

func spawn_hazard(point: Vector3, radius: float, duration: float, amount: float, kind: String) -> void:
	var hazard := Hazard.new()
	hazard.target = target
	hazard.source_actor = self
	hazard.radius = radius
	hazard.lifetime = duration
	hazard.damage = amount
	hazard.kind = kind
	hazard.interval = 0.8 if kind=="mist" else 2.0
	get_parent().add_child(hazard)
	hazard.global_position = Vector3(point.x,preload("res://scripts/forest_terrain.gd").height_at(point.x,point.z)+0.05,point.z)

func clear_line_to(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,point+Vector3.UP)
	query.exclude = [get_rid(),target.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func receive_strike(amount: float, origin: Vector3, action: String, part := "") -> Dictionary:
	if health <= 0: return {"hit":false}
	var toward := (origin-global_position).normalized()
	var dot_front := toward.dot(-global_basis.z)
	var weak: bool = (data.weak_side == "rear" and dot_front < -0.3) or (data.weak_side == "flank" and absf(dot_front)<0.65 and exposed>0) or (data.weak_side == "front" and dot_front>0.2 and phase=="windup")
	if part!="":
		weak = weak_part_active(part)
	var factor := float(data.weak_multiplier) if weak else (float(data.front_armor) if dot_front > 0.4 and armor_integrity>0 else 1.0)
	if data.id=="mossback" and part=="body": armor_integrity = maxf(0,armor_integrity-amount)
	if data.id=="mossback" and armor_integrity<=0:
		for i in 5:
			var plate := mesh.get_node_or_null("ArmorPlate"+str(i)) as MeshInstance3D
			if plate: plate.visible = false
	health = maxf(0,health-amount*factor)
	show_impact(weak)
	if weak and data.id == "mistfrill" and phase == "windup": stagger = 1.8
	if weak and data.id == "stormcrest" and phase == "windup":
		disrupted += amount
		if disrupted >= 90:
			stagger = 2.5
			disrupted = 0
	if action in ["spin","finisher"]:
		stagger = 1.3 if action=="spin" else 2.2
		velocity.y = 4.0
		velocity += -toward*4
	elif action == "pull":
		velocity += toward*4
		stagger = maxf(stagger,0.30)
	elif action == "reply":
		velocity += -toward*5
		stagger = maxf(stagger,0.45)
	return {"hit":true,"weak":weak,"damage":amount*factor,"part":part if part!="" else "legacy-direction","armor_broken":armor_integrity<=0}
