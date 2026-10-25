extends CharacterBody3D
signal hit_confirmed(action: String, beat: int, target: Node3D, result: Dictionary)
const CombatAudio = preload("res://scripts/combat_audio.gd")
const Defeat = preload("res://scripts/hunter_defeat.gd")
var defeat = Defeat.new()
const InputKeys = preload("res://scripts/input_keys.gd")
var virtual_keys = InputKeys.new()
const Combat = preload("res://scripts/combat/trident_combat.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Projectile = preload("res://scripts/trident_projectile.gd")
const HunterModel = preload("res://scripts/hunter_model.gd")
const Parts = preload("res://scripts/monster_parts.gd")
const HitFeedback = preload("res://scripts/hit_feedback.gd")
const WeaponTrail = preload("res://scripts/weapon_trail.gd")
var weapon_trail: MeshInstance3D
var trail_epoch := 0
var action_audio_beats := {}
const TeleportFeedback = preload("res://scripts/teleport_feedback.gd")
const HunterVisibility = preload("res://scripts/hunter_visibility.gd")
var combat = Combat.new()
var feedback = preload("res://scripts/combat_feedback.gd").new()
var rig: Dictionary
var mount: Node3D
var yaw := 0.0
var pitch := -0.25
var camera_manual_time := 0.0
var motion_epoch := 0
var body_turn_applied := 0.0
var body_turn_pose := 0.0
var walk_clock := 0.0
var locomotion_motion := Vector3.ZERO
var heavy_held := -1.0
var lock_target: Node3D
var message := "观察金色预警后躲避或格挡。"
var ghosts: Array[Node3D] = []
var projectile: Projectile
var pose_action := ""
var pose_from := Transform3D.IDENTITY
var pose_blend := 1.0
var pose_drawn := false
var pose_duration := 0.10
var equipment_grip := 0.0
var equipment_from := 0.0
var equipment_main := 0.0
var equipment_main_from := 0.0
var equipment_route := false
var strike_windows: Array[Dictionary] = []
var camera: Camera3D
var shake_time := 0.0
var shake_strength := 0.0

func _ready() -> void:
	CombatAudio.warmup_actions()
	var keys := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"sprint":KEY_SHIFT}
	for label in keys:
		if not InputMap.has_action(label):
			InputMap.add_action(label)
			var binding := InputEventKey.new()
			binding.physical_keycode = keys[label]
			InputMap.action_add_event(label,binding)
	collision_mask = 3
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	rig = HunterModel.create(self)
	weapon_trail = WeaponTrail.new()
	weapon_trail.name = "WeaponTrail"
	add_child(weapon_trail)
	var visibility := HunterVisibility.new()
	visibility.name = "OcclusionVisibility"
	add_child(visibility)
	mount = Node3D.new()
	get_parent().add_child.call_deferred(mount)
	var arm := SpringArm3D.new()
	arm.spring_length = 5.8
	arm.margin = 0.2
	arm.collision_mask = 3
	arm.add_excluded_object(get_rid())
	mount.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68
	camera.current = true
	arm.add_child(camera)
	combat.strike.connect(on_strike)
	combat.action_changed.connect(on_action_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 5:
		var ghost := Visuals.trident(rig.root,true)
		ghost.position = Vector3((i-2)*0.23,1.35,0.38)
		ghost.rotation.z = (i-2)*-0.17
		ghost.scale = Vector3.ONE*0.65
		ghost.get_meta("spectral_material").set_shader_parameter("phase_offset",i*0.9)
		ghost.hide()
		ghosts.append(ghost)
	# Establish the actual starting pose before the first rendered/physics frame.
	animate(0,0)
	pose_from = rig.weapon.transform
	pose_blend = 1.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey: virtual_keys.movement(event)

func _exit_tree() -> void:
	virtual_keys.release()

func _unhandled_input(event: InputEvent) -> void:
	if combat.health<=0 and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
	if is_instance_valid(projectile):
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.pressed: feedback.show_event("投枪飞行中 · 等待武器回收",Color("e7c88b"),0.8,1)
			return
		if event is InputEventKey and (InputKeys.code(event) in [KEY_Q,KEY_E,KEY_R] or (InputKeys.code(event)==KEY_SPACE and event.ctrl_pressed)): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		match InputKeys.code(event):
			KEY_ESCAPE:
				heavy_held = -1
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_Q: request_action("guard")
			KEY_E: request_action("pull")
			KEY_R:
				if request_action("sheathe"): heavy_held = -1
			KEY_TAB: cycle_lock(event.shift_pressed)
			KEY_SPACE: request_action("plant" if event.ctrl_pressed else "dodge")
			KEY_CTRL:
				if combat.action=="wait": request_action("counter_window")
			KEY_F5: get_tree().reload_current_scene()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index==MOUSE_BUTTON_MIDDLE:
			lock_target = nearest_monster() if not is_instance_valid(lock_target) else null
			camera_manual_time = 0
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			var next := "light"
			if event.alt_pressed: next = "turn"
			elif event.ctrl_pressed: next = "flash" if combat.flash_window>0 else "fourfold"
			elif combat.guard_reward>0: next = "reply"
			request_action(next)
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if event.ctrl_pressed: request_action("spin")
				else: heavy_held = 0
			elif heavy_held>=0:
				request_action("throw" if heavy_held>=Combat.THROW_HOLD_TIME else "heavy")
				heavy_held = -1

func request_action(next: String) -> bool:
	var accepted: bool = combat.request(next)
	if accepted and next=="sheathe": feedback.show_event("收枪")
	elif not accepted and combat.health>0: feedback.rejected(combat,next)
	return accepted

func apply_look(relative: Vector2) -> void:
	if absf(relative.x)>0.01: camera_manual_time = 0.75
	yaw -= relative.x*0.003
	pitch = clampf(pitch-relative.y*0.0025,-0.9,0.65)

func update_lock_camera(delta: float) -> void:
	camera_manual_time = maxf(0,camera_manual_time-delta)
	if camera_manual_time>0 or combat.health<=0 or not is_instance_valid(lock_target) or lock_target.health<=0: return
	var offset := lock_target.global_position-global_position
	offset.y = 0
	if offset.length_squared()<0.01 or offset.length()>30: return
	var heading := atan2(-offset.x,-offset.z)
	yaw = lerp_angle(yaw,heading,1-exp(-5.0*delta))

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		heavy_held = -1
		virtual_keys.release()

func clear_body_turn() -> void:
	if body_turn_applied!=0:
		rig.root.rotation.y -= body_turn_applied
		rig.weapon.transform = Transform3D(Basis(Vector3.UP,body_turn_applied),Vector3.ZERO)*rig.weapon.transform
	body_turn_applied = 0

func combat_forward() -> Vector3:
	return global_basis*Vector3.FORWARD.rotated(Vector3.UP,rig.root.rotation.y-body_turn_applied)

func on_action_changed(next: String) -> void:
	feedback.action_changed(next)
	clear_body_turn()
	if next!="idle": heavy_held = -1
	strike_windows.clear()
	action_audio_beats.clear()
	if next=="hurt" and is_instance_valid(weapon_trail): weapon_trail.clear_trail()
	if next=="hurt" and is_instance_valid(projectile): projectile.cancel_arrival()
	if not is_instance_valid(lock_target) and next not in ["idle","hurt","dodge","wait","counter_window"]:
		rig.root.rotation.y = yaw

func lock_candidates() -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	var view := get_viewport().get_camera_3d()
	if not is_instance_valid(view) or combat.health<=0: return candidates
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.health<=0 or not monster.is_visible_in_tree() or global_position.distance_to(monster.global_position)>=24: continue
		for height in [0.6,0.95]:
			var point: Vector3 = monster.global_position+Vector3.UP*float(monster.data.size)*height
			if not view.is_position_in_frustum(point): continue
			var query := PhysicsRayQueryParameters3D.create(view.global_position,point,3,[get_rid(),monster.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				candidates.append(monster)
				break
	candidates.sort_custom(func(a: Node3D,b: Node3D) -> bool:
		var left: Vector3 = view.to_local(a.global_position)
		var right: Vector3 = view.to_local(b.global_position)
		var angle_a := atan2(left.x,-left.z)
		var angle_b := atan2(right.x,-right.z)
		if is_equal_approx(angle_a,angle_b): return a.get_instance_id()<b.get_instance_id()
		return angle_a<angle_b
	)
	return candidates

func nearest_monster() -> Node3D:
	var result: Node3D
	var distance := 24.0
	for monster in lock_candidates():
		var current := global_position.distance_to(monster.global_position)
		if current<distance:
			distance = current
			result = monster
	return result

func cycle_lock(reverse := false) -> void:
	var candidates := lock_candidates()
	if candidates.is_empty():
		lock_target = null
		return
	var index := candidates.find(lock_target)
	if index<0:
		lock_target = nearest_monster()
	else:
		lock_target = candidates[posmod(index+(-1 if reverse else 1),candidates.size())]
	camera_manual_time = 0

func _physics_process(delta: float) -> void:
	feedback.advance(delta)
	clear_body_turn()
	if combat.health<=0: heavy_held = -1
	elif heavy_held>=0: heavy_held += delta
	combat.advance(delta)
	update_action_audio()
	if is_instance_valid(lock_target) and (lock_target.health<=0 or global_position.distance_to(lock_target.global_position)>30): lock_target = null
	var axis := Input.get_vector("move_left","move_right","move_forward","move_back")
	var input := Vector3(axis.x,0,axis.y)
	var direction := input.normalized().rotated(Vector3.UP,yaw)
	var speed := 6.3 if Input.is_action_pressed("sprint") else 4.5
	if combat.action!="idle": speed *= 0.22
	if combat.action in ["plant","wait","counter_window","hurt"] or combat.health<=0: speed = 0
	velocity.x = direction.x*speed
	velocity.z = direction.z*speed
	if combat.health>0 and combat.action=="dodge":
		var dash: Vector3 = direction if direction.length()>0 else combat_forward()
		velocity.x = dash.x*9
		velocity.z = dash.z*9
	if combat.health>0 and combat.action=="flash" and combat.elapsed<0.23:
		velocity.x = combat_forward().x*13
		velocity.z = combat_forward().z*13
	if not is_on_floor(): velocity.y -= 24*delta
	var movement_start := global_position
	move_and_slide()
	locomotion_motion = global_position-movement_start
	locomotion_motion.y = 0
	var travelled := Vector2(global_position.x-movement_start.x,global_position.z-movement_start.z).length()
	var animation_speed := minf(direction.length()*speed,travelled/maxf(delta,0.000001))
	# Authored evasions/lunges retain their dedicated leg poses rather than becoming a fast walk.
	if combat.action in ["dodge","flash"]: animation_speed = direction.length()*speed
	update_lock_camera(delta)
	if combat.health>0 and is_instance_valid(lock_target):
		var offset := lock_target.global_position-global_position
		rig.root.rotation.y = lerp_angle(rig.root.rotation.y,atan2(-offset.x,-offset.z),delta*10)
	elif combat.health>0 and direction.length()>0.1 and combat.action=="idle":
		rig.root.rotation.y = lerp_angle(rig.root.rotation.y,atan2(-direction.x,-direction.z),delta*12)
	mount.position = global_position+Vector3(0,1.5,0)
	# Keep the orbit above the floor while the nearby weapon aims at elevated parts.
	var orbit_pitch := pitch*0.2 if pitch>0 else pitch
	mount.rotation = Vector3(orbit_pitch,yaw,0)
	animate(delta,animation_speed)
	update_weapon_contacts()
	if global_position.y < -15:
		global_position = Vector3(0,2,8)
		motion_epoch += 1

func update_action_audio() -> void:
	if combat.health<=0 or not Combat.MOVES.has(combat.action): return
	var hits: Array = Combat.MOVES[combat.action].hits
	for beat in hits.size():
		var time: float = hits[beat]
		if action_audio_beats.has(beat) or combat.elapsed<time-0.07: continue
		action_audio_beats[beat] = true
		if combat.elapsed>time+0.10: continue
		var kind := "thrust" if combat.action in ["light","flash","fourfold","reply"] else "sweep"
		if combat.action=="throw": kind = "throw"
		elif combat.action=="finisher" and beat==1: kind = "kick"
		CombatAudio.emit_at(get_parent(),kind,global_position+Vector3.UP*1.1)

func animate(delta: float, speed: float) -> void:
	clear_body_turn()
	if combat.health<=0:
		body_turn_pose = 0
		defeat.update(self,delta)
		return
	if defeat.started:
		defeat = Defeat.new()
		rig.root.rotation.z = 0
	if combat.action!=pose_action or combat.drawn!=pose_drawn:
		equipment_route = combat.drawn!=pose_drawn
		pose_duration = 0.30 if pose_drawn and not combat.drawn else 0.10
		equipment_from = equipment_grip
		equipment_main_from = equipment_main
		pose_from = rig.weapon.transform
		pose_action = combat.action
		pose_drawn = combat.drawn
		pose_blend = 0.0
	walk_clock += delta*speed*2.6
	if combat.action in ["turn","spin"]: body_turn_pose = wrapf(TAU*HunterModel.Motion.turn_progress(combat.action,combat.elapsed),-PI,PI)
	else: body_turn_pose = lerp_angle(body_turn_pose,0,1-exp(-18*delta)) if delta>0 else 0.0
	if absf(body_turn_pose)<0.00001: body_turn_pose = 0
	body_turn_applied = body_turn_pose
	rig.root.rotation.y += body_turn_applied
	for side in [-1,1]:
		rig.joints["arm"+str(side)].rotation.x = -0.85 if combat.drawn else -sin(walk_clock)*side*minf(speed*0.08,0.3)
	var leg_travel: Vector3 = rig.root.global_basis.inverse()*locomotion_motion
	HunterModel.pose_legs(rig,combat.action,combat.elapsed,combat.drawn,walk_clock,speed,delta,foot_ground_height if is_on_floor() else Callable(),foot_ground_normal if is_on_floor() else Callable(),leg_travel)
	var w: Node3D = rig.weapon
	w.visible = not is_instance_valid(projectile)
	w.position = Vector3(0,1.20,-0.32) if combat.drawn else Vector3(0,1.05,0.26)
	w.rotation = Vector3(-PI/2,0,-0.15) if combat.drawn else Vector3(0,0,0.35)
	if combat.action!="idle":
		var t: float = combat.elapsed
		var p := clampf(t/float(Combat.MOVES[combat.action].duration),0,1)
		match combat.action:
			"hurt":
				var recoil := smoothstep(0,0.08,t)*(1-smoothstep(0.16,0.55,t))
				w.position.y -= 0.18*recoil
				w.position.z += 0.12*recoil
				w.rotation.x -= 0.20*recoil
				w.rotation.z -= 0.25*recoil
			"light":
				var path := HunterModel.Motion.interpolate(HunterModel.Motion.LIGHT_WEAPON,t)
				w.position.y += path.y
				w.position.z += path.z
				w.rotation.x += path.w+clampf(pitch+0.25,-0.4,0.85)
			"fourfold":
				var path := HunterModel.Motion.interpolate(HunterModel.Motion.FOURFOLD_WEAPON,t)
				w.position.z += path.z
				w.rotation.x += path.w+clampf(pitch+0.25,-0.4,0.85)
			"flash":
				var pulse := 0.0
				for hit_time in Combat.MOVES[combat.action].hits:
					pulse = maxf(pulse,exp(-pow((t-float(hit_time))/0.09,2)))
				w.position.z -= pulse*0.15
				w.rotation.x += 0.18+clampf(pitch+0.25,-0.4,0.85)
			"pull":
				# Catch with the backward-facing side teeth, then draw the head toward the hip.
				var path := HunterModel.Motion.interpolate(HunterModel.Motion.PULL_WEAPON,t)
				w.position.z += path.z
				w.rotation.x += path.w
			"heavy":
				var path := HunterModel.Motion.interpolate(HunterModel.Motion.HEAVY_WEAPON,t)
				w.position.y += 0.22*smoothstep(0,0.18,t)*(1-smoothstep(0.30,0.43,t))
				w.rotation.y = path.y
				w.position.z += path.z
				w.rotation.x += clampf(pitch+0.25,-0.4,0.85)*1.22
			"turn","spin","finisher":
				w.rotation.y = -1.5+p*TAU
				if combat.action=="spin":
					w.position.z += 0.06*sin(HunterModel.Motion.turn_progress("spin",t)*PI)
					# Carry the grip center around with the chest instead of leaving
					# the shaft behind the back halfway through the body turn.
					w.position = w.position.rotated(Vector3.UP,body_turn_applied)
				if combat.action=="turn":
					w.rotation.x += clampf(pitch+0.25,-0.4,0.85)*1.22
					w.position.z += 0.07*sin(smoothstep(0.10,0.58,t)*PI)
			"guard","reply":
				var brace := 1.0 if combat.action=="reply" else smoothstep(0,0.18,t)
				w.rotation.y = PI if combat.action=="reply" else PI*clampf(t/0.18,0,1)
				w.position.z += 0.55*brace
				if combat.action=="reply": w.position.z += HunterModel.Motion.interpolate(HunterModel.Motion.REPLY_WEAPON,t).z
			"plant","wait","counter_window":
				var seated := planted_weapon_height()
				w.position = Vector3(0,seated,-0.35)
				w.rotation = Vector3(0,0,PI)
				if combat.action=="plant":
					var raised := smoothstep(0,0.18,t)
					var drive := smoothstep(0.18,0.48,t)
					w.position.y = lerpf(1.20,seated,raised)+0.30*raised*(1-drive)
					var ready := Basis.from_euler(Vector3(-PI/2,0,-0.15)).get_rotation_quaternion()
					w.quaternion = ready.slerp(Basis.from_euler(Vector3(0,0,PI)).get_rotation_quaternion(),smoothstep(0,0.18,t))
			"throw":
				var path := HunterModel.Motion.interpolate(HunterModel.Motion.THROW_WEAPON,t)
				w.position.y += path.y
				w.position.z += path.z
				w.rotation.y = path.w
				w.rotation.z *= 1-smoothstep(0.20,0.38,t)
				w.visible = t<0.38
	if delta>0:
		pose_blend = minf(1,pose_blend+delta/pose_duration)
		var goal := w.transform
		w.transform = pose_from.interpolate_with(w.transform,smoothstep(0,1,pose_blend))
		if equipment_route:
			var arc := Vector3(maxf(0,0.40-absf(pose_from.origin.x)),maxf(0,1.65-maxf(pose_from.origin.y,goal.origin.y)),0)
			w.position += arc*sin(smoothstep(0,1,pose_blend)*PI)
		equipment_grip = lerpf(equipment_from,1.0 if combat.drawn else 0.0,smoothstep(0,0.7,pose_blend))
		equipment_main = lerpf(equipment_main_from,1.0,smoothstep(0,0.7,pose_blend)) if combat.drawn else lerpf(equipment_main_from,0.0,smoothstep(0.82,1,pose_blend))
	else:
		equipment_grip = 1.0 if combat.drawn else 0.0
		equipment_main = equipment_grip
	w.transform = Transform3D(Basis(Vector3.UP,-body_turn_applied),Vector3.ZERO)*w.transform
	for i in ghosts.size():
		ghosts[i].visible = combat.health>0 and i<combat.shadow_lifetimes.size()
		if ghosts[i].visible:
			ghosts[i].get_meta("spectral_material").set_shader_parameter("life_fade",0.2+0.8*smoothstep(0,6,combat.shadow_lifetimes[i]))
	HunterModel.pose_torso(rig,combat.action,combat.elapsed,walk_clock,speed,delta)
	var release := smoothstep(0.28,0.38,combat.elapsed) if combat.action=="throw" else 0.0
	if is_instance_valid(projectile): release = 1.0
	var arm_release := smoothstep(0.38,0.60,combat.elapsed) if combat.action=="throw" else (1.0 if is_instance_valid(projectile) else 0.0)
	HunterModel.pose_arms(rig,combat.drawn or equipment_grip>0 or equipment_main>0,walk_clock,equipment_grip*(1-arm_release),equipment_main*(1-arm_release),release)

func planted_weapon_height() -> float:
	var point: Vector3 = rig.root.to_global(Vector3(0,0,-0.35))
	point.y = global_position.y
	var excluded: Array[RID] = [get_rid()]
	for creature in get_tree().get_nodes_in_group("monsters"): excluded.append(creature.get_rid())
	var probe := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.9,point-Vector3.UP*2,3,excluded)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(probe)
	if floor_hit.is_empty() or floor_hit.normal.y<0.72 or absf(floor_hit.position.y-global_position.y)>0.4: return 1.15
	return rig.root.to_local(floor_hit.position).y+1.20-0.025

func foot_ground_height(local_point: Vector3) -> float:
	var hit := foot_ground_sample(local_point)
	return 0.0 if hit.is_empty() else hit.position.y-global_position.y

func foot_ground_normal(local_point: Vector3) -> Vector3:
	var hit := foot_ground_sample(local_point)
	return Vector3.UP if hit.is_empty() else rig.root.global_basis.inverse()*hit.normal

func foot_ground_sample(local_point: Vector3) -> Dictionary:
	var point: Vector3 = rig.root.to_global(local_point)
	point.y = global_position.y
	var probe := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.5,point-Vector3.UP*0.5,2)
	var hit := get_world_3d().direct_space_state.intersect_ray(probe)
	if hit.is_empty() or hit.normal.y<0.72: return {}
	return hit

func take_damage(amount: float, origin: Vector3, blockable: bool, interrupt := true) -> void:
	var direction := (origin-global_position).normalized()
	var front := direction.dot(combat_forward())>0.15
	var exhausted_guard: bool = combat.action=="guard" and combat.elapsed>=0.12 and blockable and front and combat.stamina<15
	var previous_health: float = combat.health
	var result: String = combat.receive_damage(amount,blockable,front,interrupt)
	if result=="guarded": feedback.show_event("格挡成功 · 左键反击",Color("f3d58b"),0.85,2)
	elif result=="counter": feedback.show_event("迎击成功 · 旋枪踢击",Color("f3d58b"),0.85,2)
	elif result=="armored": feedback.show_event("霸体承伤 · 动作继续",Color("e7c88b"),0.8,2)
	elif result=="immune": feedback.show_event("闪避免伤" if combat.action=="dodge" else "反击免伤",Color("bde4d4"),0.55,1)
	elif result=="hurt" and exhausted_guard: feedback.show_event("耐力耗尽 · 格挡被击破",Color("f0947d"),1.15,3)
	if result=="guarded": CombatAudio.emit_at(get_parent(),"guard",global_position+Vector3.UP)
	elif combat.health<previous_health: CombatAudio.emit_at(get_parent(),"hurt",global_position+Vector3.UP)
	message = {"counter":"反击成功！旋转踢击，不消耗枪影。","guarded":"格挡成功：左键反击，再 Ctrl+左键闪刺。","immune":"免伤","armored":"霸体承伤：动作继续","hurt":"受击！注意预警与站位。"}.get(result,result)
	if result=="ongoing": message = "毒雾持续伤害：离开绿色区域！"
	if result=="hurt" and exhausted_guard: message = "耐力不足，架势被击破！先走位恢复。"
	if result in ["hurt","armored"]: trigger_camera_impact(0.04)
	elif result in ["guarded","counter"]: trigger_camera_impact(0.02)

func trigger_camera_impact(strength: float) -> void:
	shake_time = 0.16
	shake_strength = maxf(shake_strength,strength)

func _process(delta: float) -> void:
	shake_time = maxf(0,shake_time-delta)
	var envelope := shake_time/0.16
	camera.h_offset = sin(shake_time*170)*shake_strength*envelope
	camera.v_offset = cos(shake_time*145)*shake_strength*envelope*0.65
	if shake_time==0: shake_strength = 0

func show_hit_feedback(point: Vector3, result: Dictionary, action: String = "") -> void:
	if not result.get("hit",false): return
	var effect := HitFeedback.new()
	effect.damage = result.damage
	effect.weak = result.weak
	effect.action = combat.action if action.is_empty() else action
	get_parent().add_child(effect)
	effect.global_position = point
	trigger_camera_impact(minf(0.04,(0.023 if result.weak else 0.014)*effect.force))

func on_strike(_beat: int) -> void:
	var action: String = combat.action
	if action=="throw":
		if is_instance_valid(projectile): return
		heavy_held = -1
		var shot := Projectile.new()
		shot.shooter = self
		shot.direction = combat_forward()
		shot.amount = combat.damage()
		projectile = shot
		get_parent().add_child(shot)
		var launch: Vector3 = rig.weapon.global_position
		var chest := global_position+Vector3(0,1.1,0)
		var launch_probe := PhysicsRayQueryParameters3D.create(chest,launch,3,[get_rid()])
		var obstruction := get_world_3d().direct_space_state.intersect_ray(launch_probe)
		if not obstruction.is_empty(): launch = obstruction.position+(chest-launch).normalized()*0.05
		shot.global_position = launch
		shot.look_at(shot.global_position+shot.direction)
		return
	strike_windows.append({"action":action,"beat":_beat,"ends":combat.elapsed+0.12,"previous":weapon_contact_points(action,_beat),"victims":{}})

func weapon_contact_points(action: String, beat: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	if action=="finisher" and beat==1:
		# Use the kicking foot rather than granting another full circular weapon hit.
		points.append(rig.legs[1].boot.to_global(Vector3(0,-0.5,-0.45)))
	elif action=="reply":
		for label in ["ButtContact","ButtNeckContact"]: points.append(rig.weapon.get_node(label).global_position)
	elif action=="pull":
		for label in ["LeftHookContact","RightHookContact"]: points.append(rig.weapon.get_node(label).global_position)
	else:
		for label in ["TipContact","BladeContact","HeadBaseContact","LeftProngContact","RightProngContact","LeftHookContact","RightHookContact"]: points.append(rig.weapon.get_node(label).global_position)
	return points

func update_weapon_contacts() -> void:
	if motion_epoch!=trail_epoch or combat.health<=0:
		weapon_trail.clear_trail()
		trail_epoch = motion_epoch
	for window in strike_windows.duplicate():
		if window.action!=combat.action or combat.elapsed>float(window.ends) or combat.health<=0:
			strike_windows.erase(window)
			continue
		var points := weapon_contact_points(window.action,window.beat)
		if not (window.action=="finisher" and window.beat==1):
			var labels: Array = ["ButtContact","ButtNeckContact"] if window.action=="reply" else (["LeftHookContact","RightHookContact"] if window.action=="pull" else ["TipContact","HeadBaseContact"])
			weapon_trail.add_sample(rig.weapon.get_node(labels[0]).global_position,rig.weapon.get_node(labels[1]).global_position,window.action+str(window.beat),window.action in ["flash","fourfold","spin","finisher"])
		var previous: PackedVector3Array = window.previous
		if previous.is_empty(): previous = points
		var radius := 0.16 if window.action=="finisher" and window.beat==1 else 0.075
		for m in get_tree().get_nodes_in_group("monsters"):
			if m.health<=0 or window.victims.has(m.get_instance_id()): continue
			var contact := {}
			for index in points.size():
				var candidate := Parts.sweep(m,previous[index],points[index],radius)
				if candidate.is_empty() and index>0: candidate = Parts.sweep(m,points[index-1],points[index],radius)
				if not candidate.is_empty():
					contact = candidate
					break
			if contact.is_empty(): continue
			var query := PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1.15,0),contact.point)
			query.exclude = [get_rid(),m.get_rid()]
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			window.victims[m.get_instance_id()] = true
			var result: Dictionary = m.receive_strike(combat.damage(),global_position,window.action,contact.part)
			if result.hit:
				combat.confirm_hit()
				show_hit_feedback(contact.point,result,window.action)
				hit_confirmed.emit(window.action,window.beat,m,result)
				message = ("弱点！ " if result.weak else "命中 ")+str(roundi(result.damage))+" · "+str(result.part)
		window.previous = points

func finish_throw(point: Vector3, allow_arrival := true) -> void:
	projectile = null
	if not allow_arrival or combat.health<=0 or combat.action=="hurt":
		message = "投掷被打断，武器收回"
		return
	var motion := Vector3(point.x-global_position.x,0,point.z-global_position.z)
	var collision := move_and_collide(motion,true)
	if collision: motion = collision.get_travel()*0.90
	var candidate := global_position+motion
	# Search below the projectile, so overhead terrain cannot become an arrival floor.
	var probe_start := Vector3(candidate.x,point.y+0.1,candidate.z)
	var probe := PhysicsRayQueryParameters3D.create(probe_start,Vector3(candidate.x,minf(candidate.y,point.y)-6,candidate.z))
	probe.exclude = [get_rid()]
	probe.collision_mask = 2
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(probe)
	if floor_hit.is_empty() or floor_hit.normal.y<0.72:
		message = "落点悬空或过陡，取消瞬移"
		return
	# Require body clearance above the proposed floor before changing position.
	candidate.y = floor_hit.position.y+0.05
	var body_probe := PhysicsShapeQueryParameters3D.new()
	body_probe.shape = get_child(0).shape
	body_probe.transform = Transform3D(Basis.IDENTITY,candidate+Vector3(0,0.9,0))
	body_probe.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(body_probe,1).is_empty():
		message = "落点空间不足，取消瞬移"
		return
	var departure: Transform3D = rig.root.global_transform
	var travel := global_position.distance_to(candidate)
	global_position = candidate
	motion_epoch += 1
	if travel>0.5:
		var effect := TeleportFeedback.new()
		effect.source = rig.root
		effect.departure = departure
		effect.arrival = rig.root.global_transform
		get_parent().add_child(effect)
	message = "投掷命中落点，已移至安全位置" if motion.length()>0.5 else "落点受阻，武器收回"
