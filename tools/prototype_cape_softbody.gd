extends "res://tools/probe_shoulder_intersections.gd"
## Isolated cloth experiment, never installed in the game scene.
## Fixed-clock samples do not establish real-time cost or full-motion clearance.
func measure_cloth(cloths: Dictionary, arm_meshes: Dictionary, head_mesh: MeshInstance3D, p: CharacterBody3D, action: String, elapsed: float, measurements: Array) -> bool:
	var skull := surface(head_mesh,p.rig.skinning.skeleton)
	for side in [-1,1]:
		var soft: SoftBody3D = cloths[side]
		var arrays: Array = soft.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var points := PackedVector3Array()
		for index in arrays[Mesh.ARRAY_VERTEX].size(): points.append(soft.to_global(soft.get_point_transform(index)))
		var max_extent := 0.0
		var center: Vector3 = p.rig.torso.to_global(Vector3(0,0.25,0))
		for point in points:
			if not point.is_finite():
				printerr("Prototype cloth has non-finite vertices")
				quit(2)
				return false
			max_extent = maxf(max_extent,point.distance_to(center))
		var rest: PackedVector3Array = soft.get_meta("cloth_rest_vertices")
		var max_stretch := 1.0
		var worst_edge := {}
		for triangle in range(0,indices.size(),3):
			for edge in 3:
				var a := indices[triangle+edge]
				var b := indices[triangle+(edge+1)%3]
				var length := rest[a].distance_to(rest[b])
				if length>0.0001:
					var ratio := points[a].distance_to(points[b])/length
					if ratio>max_stretch:
						max_stretch = ratio
						worst_edge = {"indices":[a,b],"rest_length":length,"posed_length":points[a].distance_to(points[b]),"rest_a":[rest[a].x,rest[a].y,rest[a].z],"rest_b":[rest[b].x,rest[b].y,rest[b].z],"pinned":[soft.is_point_pinned(a),soft.is_point_pinned(b)],"posed_a":[points[a].x,points[a].y,points[a].z],"posed_b":[points[b].x,points[b].y,points[b].z]}
		var pinned_overlaps := []
		var pins: Array = soft.get_meta("cloth_pins")
		var bodies: Array = soft.get_meta("cloth_colliders")
		for pin in pins:
			for body in bodies:
				if (soft.collision_mask & body.collision_layer)==0: continue
				var local: Vector3 = body.to_local(points[pin])
				var shape: Shape3D = body.get_child(0).shape
				var inside := false
				if shape is CapsuleShape3D:
					var segment: float = shape.height*0.5-shape.radius
					inside = Vector3(local.x,local.y-clampf(local.y,-segment,segment),local.z).length()<shape.radius-0.001
				elif shape is BoxShape3D:
					inside = local.abs().x<shape.size.x*0.5-0.001 and local.abs().y<shape.size.y*0.5-0.001 and local.abs().z<shape.size.z*0.5-0.001
				if inside: pinned_overlaps.append({"index":pin,"collider":str(body.name)})
		var deformation_invalid := max_extent>1.5 or max_stretch>2.0
		var faces := PackedVector3Array()
		for index in indices: faces.append(points[index])
		var skin := surface(arm_meshes[side],p.rig.skinning.skeleton)
		var cloth := TriangleMesh.new()
		var built := cloth.create_from_faces(faces)
		if not built:
			printerr("Prototype cloth triangle construction failed")
			quit(2)
			return false
		var cape_edges := count_crossing_edges(faces,skin)
		var arm_edges := count_crossing_edges(skin.get_faces(),cloth)
		var cloth_head := count_crossing_edges(faces,skull)
		var head_cloth := count_crossing_edges(skull.get_faces(),cloth)
		var weapon_crossing := false
		for ray in 9:
			var offset := Vector3.ZERO if ray==0 else Vector3(cos((ray-1)*TAU/8)*0.024,0,sin((ray-1)*TAU/8)*0.024)
			weapon_crossing = weapon_crossing or not cloth.intersect_segment(p.rig.weapon.to_global(Vector3(0,-0.90,0)+offset),p.rig.weapon.to_global(Vector3(0,0.82,0)+offset)).is_empty()
		measurements.append({"action":action,"time":elapsed,"side":side,"cape_edges":cape_edges,"arm_edges":arm_edges,"cloth_head_edges":cloth_head,"head_cloth_edges":head_cloth,"weapon_crossing":weapon_crossing,"max_extent":max_extent,"max_edge_stretch":max_stretch,"deformation_invalid":deformation_invalid,"worst_edge":worst_edge,"pinned_overlaps":pinned_overlaps})
		if cape_edges+arm_edges+cloth_head+head_cloth>0 or weapon_crossing or deformation_invalid: print("SOFT_CROSSING: action=",action," time=",elapsed," side=",side," cape_edges=",cape_edges," arm_edges=",arm_edges," cloth_head=",cloth_head," head_cloth=",head_cloth," weapon=",weapon_crossing," max_stretch=",max_stretch," max_extent=",max_extent)
	return true

## Experimental17x17 surface, sampled by arc length from the current24-column cape loft.
func regular_cape(arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var rows := {}
	for i in vertices.size():
		var key := roundi(uv[i].y*1000000)
		if not rows.has(key): rows[key] = {"v":uv[i].y,"points":{}}
		rows[key].points[roundi(uv[i].x*24)] = vertices[i]
	var keys := rows.keys()
	keys.sort()
	var lengths := PackedFloat32Array([0.0])
	for i in range(1,keys.size()):
		var a: Vector3 = rows[keys[i-1]].points[12]
		var b: Vector3 = rows[keys[i]].points[12]
		lengths.append(lengths[-1]+a.distance_to(b))
	var grid := []
	var v_coordinates := []
	for y in 17:
		var distance := lengths[-1]*y/16.0
		var row := 0
		while row<keys.size()-2 and lengths[row+1]<distance: row += 1
		var fraction := (distance-lengths[row])/maxf(0.000001,lengths[row+1]-lengths[row])
		v_coordinates.append(lerpf(rows[keys[row]].v,rows[keys[row+1]].v,fraction))
		for x in 17:
			var coordinate := x*24.0/16.0
			var column := mini(int(coordinate),23)
			var u := coordinate-column
			var a: Vector3 = rows[keys[row]].points[column].lerp(rows[keys[row]].points[column+1],u)
			var b: Vector3 = rows[keys[row+1]].points[column].lerp(rows[keys[row+1]].points[column+1],u)
			grid.append(a.lerp(b,fraction))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for y in 16:
		for x in 16:
			for corner in [Vector2i(x,y),Vector2i(x,y+1),Vector2i(x+1,y),Vector2i(x+1,y),Vector2i(x,y+1),Vector2i(x+1,y+1)]:
				tool.set_uv(Vector2(corner.x/16.0,v_coordinates[corner.y]))
				tool.add_vertex(grid[corner.y*17+corner.x])
	tool.generate_normals()
	return tool.commit().surface_get_arrays(0)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Cloth prototype requires native rendering")
		quit(2)
		return
	var no_collision := "--no-collision" in OS.get_cmdline_user_args()
	var regular_mesh := "--regular-mesh" in OS.get_cmdline_user_args()
	var weapon_collision := "--weapon-collision" in OS.get_cmdline_user_args()
	var arm_margin := 0.0
	var precision := 12
	var start_unarmed := "--start-unarmed" in OS.get_cmdline_user_args()
	var collar_drop := 0.0
	var damping := 0.08
	var stiffness := 0.95
	var head_collision := "--head-collision" in OS.get_cmdline_user_args()
	var back_ties := "--back-ties" in OS.get_cmdline_user_args()
	var neck_only := "--neck-only" in OS.get_cmdline_user_args()
	var output_name := "Shubian-cape-softbody-trial"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arm-margin="): arm_margin = clampf(float(argument.trim_prefix("--arm-margin=")),0,0.03)
		if argument.begins_with("--precision="): precision = clampi(int(argument.trim_prefix("--precision=")),4,32)
		if argument.begins_with("--collar-drop="): collar_drop = clampf(float(argument.trim_prefix("--collar-drop=")),0,0.025)
		if argument.begins_with("--damping="): damping = clampf(float(argument.trim_prefix("--damping=")),0,1)
		if argument.begins_with("--stiffness="): stiffness = clampf(float(argument.trim_prefix("--stiffness=")),0.01,1)
		if argument.begins_with("--output="): output_name = argument.trim_prefix("--output=").get_file()
	Engine.physics_ticks_per_second = 120
	root.size = Vector2i(800,600)
	root.content_scale_size = Vector2i(800,600)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("58655c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8,-0.4,0)
	stage.add_child(light)
	var p := preload("res://scripts/player.gd").new()
	stage.add_child(p)
	p.set_physics_process(false)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	p.combat.drawn = not start_unarmed
	p.combat.set_action("idle")
	p.animate(0,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(1.45,1.65,-1.35)
	camera.look_at(Vector3(0,1.38,-0.05))
	camera.fov = 30
	camera.current = true
	var colliders := {}
	for side in [-1,1]:
		var body := AnimatableBody3D.new()
		body.name = "ArmCollider"+str(side)
		body.collision_layer = 1<<20
		body.collision_mask = 0
		body.sync_to_physics = false
		var shape := CollisionShape3D.new()
		shape.shape = CapsuleShape3D.new()
		shape.shape.radius = 0.10+arm_margin
		shape.shape.height = 0.52+arm_margin*2
		body.add_child(shape)
		stage.add_child(body)
		colliders[side] = body
		body.global_transform = p.rig.arms[side].upper.global_transform.orthonormalized()
	var torso := AnimatableBody3D.new()
	torso.name = "TorsoCollider"
	torso.collision_layer = 1<<20
	torso.collision_mask = 0
	torso.sync_to_physics = false
	var torso_shape := CollisionShape3D.new()
	torso_shape.shape = BoxShape3D.new()
	torso_shape.shape.size = Vector3(0.35,0.42,0.25)
	torso.add_child(torso_shape)
	stage.add_child(torso)
	torso.global_position = Vector3(0,1.23,0)
	var head_source: MeshInstance3D = p.rig.torso.get_node("Head")
	var head := AnimatableBody3D.new()
	head.collision_layer = (1<<20) if head_collision else 0
	head.collision_mask = 0
	head.sync_to_physics = false
	var head_shape := CollisionShape3D.new()
	head_shape.shape = head_source.mesh.create_convex_shape(true,true)
	head.add_child(head_shape)
	stage.add_child(head)
	head.global_transform = head_source.global_transform
	var head_mesh: MeshInstance3D
	var weapon_body := AnimatableBody3D.new()
	weapon_body.name = "WeaponCollider"
	weapon_body.collision_layer = (1<<20) if weapon_collision else 0
	weapon_body.collision_mask = 0
	weapon_body.sync_to_physics = false
	var weapon_shape := CollisionShape3D.new()
	weapon_shape.shape = CapsuleShape3D.new()
	weapon_shape.shape.radius = 0.04
	weapon_shape.shape.height = 1.80
	weapon_body.add_child(weapon_shape)
	stage.add_child(weapon_body)
	weapon_body.global_transform = p.rig.weapon.global_transform.orthonormalized()
	weapon_body.global_position = p.rig.weapon.to_global(Vector3(0,-0.04,0))
	var cloths := {}
	var arm_meshes := {}
	for binding in p.rig.skinning.bindings:
		var label := str(binding.source.name)
		if label=="Head": head_mesh = binding.rendered
		if label.begins_with("UpperArmSurface"): arm_meshes[-1 if label.ends_with("-1") else 1] = binding.rendered
		if label.begins_with("CapeHem"): binding.rendered.hide()
		if not label.begins_with("RainCape"): continue
		binding.rendered.hide()
		var arrays: Array = binding.rendered.mesh.surface_get_arrays(0)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		if regular_mesh: arrays = regular_cape(arrays)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size(): vertices[i].x += signf(vertices[i].x)*0.035*smoothstep(0.16,0.28,absf(vertices[i].x))
		for i in vertices.size(): vertices[i].y -= collar_drop*smoothstep(1.49,1.53,vertices[i].y)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool := SurfaceTool.new()
		tool.create_from(mesh,0)
		tool.index()
		var soft := SoftBody3D.new()
		soft.mesh = tool.commit()
		soft.material_override = binding.rendered.material_override
		soft.collision_layer = 1<<19
		soft.collision_mask = 0 if no_collision else 1<<20
		soft.linear_stiffness = stiffness
		soft.damping_coefficient = damping
		soft.total_mass = 0.25
		soft.simulation_precision = precision
		stage.add_child(soft)
		soft.global_transform = p.rig.root.global_transform
		soft.force_update_transform()
		var points: PackedVector3Array = soft.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		soft.set_meta("cloth_rest_vertices",points.duplicate())
		var pin_uv: PackedVector2Array = soft.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var pin_height := 1.525 if neck_only else 1.49
		for i in points.size():
			# Select the authored collar by material coordinates, never by a fitted/colliding position.
			if pin_uv[i].y>(pin_height-1.14)/0.39: soft.set_point_pinned(i,true,soft.get_path_to(p.rig.torso))
		if back_ties:
			var tie := 0
			var target := Vector3(-0.17 if label.ends_with("-1") else 0.17,1.11,0.24)
			for i in points.size():
				if points[i].distance_squared_to(target)<points[tie].distance_squared_to(target): tie = i
			soft.set_point_pinned(tie,true,soft.get_path_to(p.rig.torso))
		var pins := []
		for i in points.size():
			if soft.is_point_pinned(i): pins.append(i)
		soft.set_meta("cloth_pins",pins)
		soft.set_meta("cloth_colliders",[colliders[-1],colliders[1],torso,weapon_body])
		cloths[-1 if label.ends_with("-1") else 1] = soft
		print("SOFT_CLOTH_VERTICES: ",points.size())
	print("SOFT_PHYSICS: ",ProjectSettings.get_setting("physics/3d/physics_engine"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var suffix := "-no-collision" if no_collision else ""
	var output := ProjectSettings.globalize_path("res://../"+output_name+suffix)
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var label := Label.new()
	label.position = Vector2(15,15)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_constant_override("outline_size",3)
	layer.add_child(label)
	var sheet := Image.create(2400,600,false,Image.FORMAT_RGB8)
	for frame in 360:
		await physics_frame
	var all_actions := "--all-actions" in OS.get_cmdline_user_args()
	var specs := [["heavy",0.92]]
	if all_actions: specs = [["light",0.66],["heavy",0.92],["pull",0.86],["turn",0.95],["guard",1.40],["reply",0.82],["throw",0.80],["fourfold",1.25],["spin",1.35],["plant",0.65],["finisher",1.45]]
	var measurements := []
	for spec in specs:
		p.combat.drawn = true
		p.combat.set_action(spec[0])
		var duration: float = spec[1]
		var snapshots := {roundi(duration*0.20*120):0,roundi(duration*0.47*120):1,roundi(duration*0.65*120):2}
		for frame in ceili(duration*120)+1:
			p.combat.elapsed = minf(duration,frame/120.0)
			p.animate(1.0/120,0)
			for side in [-1,1]: colliders[side].global_transform = p.rig.arms[side].upper.global_transform.orthonormalized()
			torso.global_transform = p.rig.torso.global_transform
			torso.global_position += p.rig.root.global_basis*Vector3(0,0.15,0)
			weapon_body.global_transform = p.rig.weapon.global_transform.orthonormalized()
			weapon_body.global_position = p.rig.weapon.to_global(Vector3(0,-0.04,0))
			head.global_transform = head_source.global_transform
			await physics_frame
			if frame%6==0 or snapshots.has(frame):
				if not measure_cloth(cloths,arm_meshes,head_mesh,p,spec[0],p.combat.elapsed,measurements): return
			if not snapshots.has(frame): continue
			var cell: int = snapshots[frame]
			label.text = str(spec[0]).to_upper()+" / %.3fs" % p.combat.elapsed
			camera.make_current()
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(800,600)
			image.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(image,Rect2i(0,0,800,600),Vector2i(cell*800,0))
		if all_actions and spec[0] in ["heavy","guard","plant"]:
			if sheet.save_png(output+"-"+spec[0]+".png")!=OK:
				printerr("Prototype image write failed")
				quit(2)
				return
	if not all_actions and sheet.save_png(output+".png")!=OK:
		printerr("Prototype image write failed")
		quit(2)
		return
	var affected := 0
	for result in measurements:
		if result.cape_edges+result.arm_edges+result.cloth_head_edges+result.head_cloth_edges>0 or result.weapon_crossing or result.deformation_invalid or not result.pinned_overlaps.is_empty(): affected += 1
	var report := {
		"prototype_only":true,"regular_mesh":regular_mesh,"weapon_collision":weapon_collision,
		"arm_margin":arm_margin,"precision":precision,"start_unarmed":start_unarmed,"collar_drop":collar_drop,
		"head_collision":head_collision,"back_ties":back_ties,
		"neck_only":neck_only,"damping":damping,"stiffness":stiffness,"no_collision":no_collision,
		"scope":"Continuous authored motion at120Hz after3s cloth settling; measurements every6 frames plus three snapshot times per action. Independent prototype, no game integration, saved clips, whole-map cost or human art acceptance. Cape hems omitted. Head excludes hair and face accessories; shaft uses nine radius0.024 rays from localY -0.90 to0.82.",
		"all_actions":all_actions,"actions":specs,"simulation_hz":120,"settle_seconds":3,
		"physics_setting":ProjectSettings.get_setting("physics/3d/physics_engine"),
		"pin_check_scope":"Active capsule and box colliders for both arms, torso and weapon; excludes convex head collider.",
		"deformation_limits":{"max_extent_from_torso":1.5,"max_edge_stretch":2.0,"note":"Broad diagnostic failure limits, not final art approval."},
		"pairs":measurements.size(),"affected_pairs":affected,"measurements":measurements
	}
	var file := FileAccess.open(output+".json",FileAccess.WRITE)
	if file==null:
		printerr("Prototype report write failed: ",output)
		quit(2)
		return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("SOFT_CLOTH_TOTAL: pairs=",measurements.size()," affected=",affected)
	stage.queue_free()
	await process_frame
	quit(1 if affected>0 and "--require-clear" in OS.get_cmdline_user_args() else 0)
