extends SceneTree
const Outfit = preload("res://scripts/hunter_outfit.gd")
const Model = preload("res://scripts/hunter_model.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var profile := Outfit.loft(holder,"NormalProbe",[Vector4(0,0.1,0.1,0),Vector4(1,0.1,0.1,0)],Color.WHITE)
	var arrays: Array = profile.mesh.surface_get_arrays(0)
	var alignment := 0.0
	for index in 28*6:
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		alignment += Vector3(point.x,0,point.z).normalized().dot(normal)
	check(alignment/(28*6)>0.9,"profile mesh normals face outward")
	var rig := Model.create(holder)
	check_collars(rig.torso,"runtime")
	check_cape(rig.root,"runtime")
	var collar_saved: Node3D = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	root.add_child(collar_saved)
	check_collars(collar_saved.get_node("Torso"),"saved")
	check_cape(collar_saved,"saved")
	check_metal(rig.root,"runtime")
	check_metal(collar_saved,"saved")
	check_face(rig.root,"runtime")
	check_face(collar_saved,"saved")
	for side in [-1,1]:
		for path in ["Bracer"+str(side),"Pelvis/BeltPouch"+str(side)]:
			var live: MeshInstance3D = rig.root.get_node(path)
			var saved: MeshInstance3D = collar_saved.get_node(path)
			var data: Array = live.mesh.surface_get_arrays(0)
			var colors: PackedColorArray = data[Mesh.ARRAY_COLOR]
			var distinct := {}
			for color in colors: distinct[color] = true
			check(distinct.size()>1 and live.material_override.vertex_color_use_as_albedo,"equipment panel and rim colours reach material: "+path)
			check(data[Mesh.ARRAY_VERTEX]==saved.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] and colors==saved.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR],"saved equipment keeps refined shape and colour: "+path)
			if "Pouch" in path:
				var bounds := live.mesh.get_aabb()
				check(bounds.size.x<0.123 and bounds.size.z<0.075 and bounds.size.y<0.136,"rounded pouch stays within the belt attachment envelope")
	for model in [rig.root,collar_saved]:
		for side in [-1,1]:
			var arm: MeshInstance3D = model.get_node("UpperArmSurface"+str(side))
			var vertices: PackedVector3Array = arm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var end_disks := 0
			for i in range(0,vertices.size(),3):
				if absf(vertices[i].y-0.5)<0.0001 and absf(vertices[i+1].y-0.5)<0.0001 and absf(vertices[i+2].y-0.5)<0.0001: end_disks += 1
			check(end_disks==0,"upper arm has no elbow end disk cutting through flexible skin")
			var cape: MeshInstance3D = model.get_node("Torso/RainCape"+str(side))
			var hem: MeshInstance3D = model.get_node("Torso/CapeHem"+str(side))
			var hem_arrays: Array = hem.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = hem_arrays[Mesh.ARRAY_VERTEX]
			var roles: PackedVector2Array = hem_arrays[Mesh.ARRAY_TEX_UV2]
			var triangles := cape.mesh.generate_triangle_mesh()
			var clear := true
			var minimum_gap := INF
			var maximum_gap := -INF
			var missing := 0
			# Probe every face interior: exact outer-edge vertices have no stable ray hit.
			for i in range(0,points.size(),3):
				if roles[i].x!=0: continue
				var center := (points[i]+points[i+1]+points[i+2])/3
				var point: Vector3 = cape.transform.affine_inverse()*hem.transform*center
				var outward := Vector3(0,0,sign(point.z))
				var hit := triangles.intersect_segment(point+outward*0.02,point-outward*0.02)
				if hit.is_empty(): missing += 1
				clear = clear and not hit.is_empty()
				if not hit.is_empty():
					var gap: float = (point-hit.position).dot(outward)
					minimum_gap = minf(minimum_gap,gap)
					maximum_gap = maxf(maximum_gap,gap)
					clear = clear and gap>0.0005 and gap<0.002
			print("HEM_CLEARANCE: ",side," min=",minimum_gap," max=",maximum_gap," missing=",missing)
			check(clear,"torso binding sits just outside cape instead of coplanar triangles")
	collar_saved.queue_free()
	for label in ["KneePlate","ShinPlate"]:
		var plate: MeshInstance3D = rig.legs[1].knee.get_node(label)
		var points: PackedVector3Array = plate.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var edges := {}
		for triangle in range(0,points.size(),3):
			for edge in 3:
				var a := str(Vector3i((points[triangle+edge]*1000000).round()))
				var b := str(Vector3i((points[triangle+(edge+1)%3]*1000000).round()))
				var key := a+"|"+b if a<b else b+"|"+a
				edges[key] = int(edges.get(key,0))+1
		var closed := true
		for count in edges.values(): closed = closed and count==2
		check(closed and plate.mesh.get_aabb().size.z>0.03,"leg armor is a closed solid with a raised face: "+label)
	check(rig.root.has_node("Torso/Head") and rig.root.has_node("Torso/HairCap"),"head and hair are separate editable meshes")
	check(rig.root.has_node("Torso/RainCape1") and rig.root.has_node("Torso/RainCape-1"),"split cape panels exist")
	check(rig.weapon.has_node("CenterBlade") and rig.weapon.has_node("Hook1") and rig.weapon.has_node("Hook-1"),"three blade silhouettes exist")
	check(rig.weapon.has_node("Grip") and rig.weapon.has_node("Butt") and rig.weapon.has_node("JadeCell"),"grip butt and jade insert remain separate")
	for label in ["CenterBlade","Hook-1","Hook1"]:
		var blade_arrays: Array = rig.weapon.get_node(label).mesh.surface_get_arrays(0)
		var points: PackedVector3Array = blade_arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = blade_arrays[Mesh.ARRAY_NORMAL]
		var edges := {}
		var outward := true
		var bevel := false
		for index in points.size():
			if absf(points[index].z)>0.0119:
				outward = outward and points[index].z*normals[index].z>0
			bevel = bevel or (absf(normals[index].z)>0.05 and absf(normals[index].z)<0.95)
		for triangle in range(0,points.size(),3):
			for edge in 3:
				var a := str(Vector3i((points[triangle+edge]*1000000).round()))
				var b := str(Vector3i((points[triangle+(edge+1)%3]*1000000).round()))
				var key := a+"|"+b if a<b else b+"|"+a
				edges[key] = int(edges.get(key,0))+1
		var closed := true
		for count in edges.values(): closed = closed and count==2
		check(closed,"blade bevel remains a closed surface: "+label)
		check(outward and bevel,"blade has outward broad faces and distinct angled bevel normals: "+label)
	var grip: MeshInstance3D = rig.weapon.get_node("Grip")
	check(grip.position.y-grip.mesh.height/2<=-0.28 and grip.position.y+grip.mesh.height/2>=0.18,"existing hand grip points fit new wrapped handle")
	check(is_equal_approx(rig.weapon.get_node("TipContact").position.y,1.2) and is_equal_approx(rig.weapon.get_node("ButtContact").position.y,-0.98),"combat endpoints preserved in model markers")
	Model.pose_legs(rig,"finisher",0.95,true,0,0,0)
	check(rig.skirts[1].rotation.x>0.4,"coat panel opens with kicking thigh")
	for label in ["CoatPanel","PanelTrim"]:
		var panel: MeshInstance3D = rig.skirts[1].get_node(label)
		check(panel.get_blend_shape_count()==1 and panel.get_blend_shape_value(0)>0.4,"cloth and trim flex with the lifted thigh: "+label)
		var rest: PackedVector3Array = panel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bent: PackedVector3Array = panel.mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
		var collar_fixed := true
		var hem_moves := false
		for index in rest.size():
			if absf(rest[index].y)<0.001: collar_fixed = collar_fixed and rest[index].distance_to(bent[index])<0.0001
			if rest[index].y< -0.22: hem_moves = hem_moves or rest[index].distance_to(bent[index])>0.02
		check(collar_fixed and hem_moves,"cloth flex preserves waist while bending its free hem: "+label)
	Model.pose_arms(rig,true,0)
	var rendered_flex := 0
	for binding in rig.skinning.bindings:
		if binding.source.name in ["CoatPanel","PanelTrim"] and binding.rendered.get_blend_shape_value(0)>0.4: rendered_flex += 1
	check(rendered_flex>=2,"visible skinned panels receive authored cloth flex")
	var saved = load("res://assets/models/hunter-forest-v1.tscn").instantiate()
	holder.add_child(saved)
	check(saved.get_node("Pelvis/Skirt1/CoatPanel").get_blend_shape_count()==1 and saved.get_node("Pelvis/Skirt1/PanelTrim").get_blend_shape_count()==1,"exported cloth and trim retain their flex targets")
	var saved_flex := 0
	for part in saved.get_node("Skeleton3D").get_children():
		if part is MeshInstance3D and part.get_meta("source_part","") in ["CoatPanel","PanelTrim"] and part.get_blend_shape_count()==1: saved_flex += 1
	check(saved_flex==4,"exported visible skin preserves both panels and matching trims")
	var preview: AnimationPlayer = saved.get_node("AnimationPreview")
	preview.play("finisher")
	preview.advance(0)
	preview.advance(0.95)
	var played_flex := false
	for part in saved.get_node("Skeleton3D").get_children():
		if part is MeshInstance3D and part.get_meta("source_part","")=="CoatPanel": played_flex = played_flex or part.get_blend_shape_value(0)>0.4
	check(played_flex,"saved finisher clip animates cloth flex using its own shape name")
	Model.pose_arms(rig,false,0)
	for side in [-1,1]:
		check(rig.arms[side].elbow.position.distance_to(rig.arms[side].hand.position)>0.38,"relaxed arm remains full length")
	print("COSTUME_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)

func check_face(model: Node3D, context: String) -> void:
	var head: MeshInstance3D = model.get_node("Torso/Head")
	var surface := head.mesh.generate_triangle_mesh()
	var tip := surface.intersect_segment(Vector3(0,1.670,-0.30),Vector3(0,1.670,0))
	var cheek := surface.intersect_segment(Vector3(0.030,1.670,-0.30),Vector3(0.030,1.670,0))
	var rise: float = cheek.position.z-tip.position.z if not tip.is_empty() and not cheek.is_empty() else 0
	check(rise>0.012 and rise<0.04,"nose tip is part of the continuous facial surface: "+context)
	var visible_head := false
	var duplicate_nose := false
	for part in model.get_node("Skeleton3D").get_children():
		if not part is MeshInstance3D: continue
		if part.get_meta("source_part","")=="Head": visible_head = part.visible
		if part.get_meta("source_part","")=="NoseBridge": duplicate_nose = part.visible
	check(visible_head and not duplicate_nose,"visible skin draws the continuous face without the old intersecting nose: "+context)

func check_cape(model: Node3D, context: String) -> void:
	for side in [-1,1]:
		var cape: MeshInstance3D = model.get_node("Torso/RainCape"+str(side))
		check(cape.get_blend_shape_count()==1 and cape.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED,"cape corrective uses absolute targets: "+context)
		if cape.get_blend_shape_count()!=1: continue
		var points: PackedVector3Array = cape.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var target: PackedVector3Array = cape.mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
		var fixed_roles: PackedVector2Array = cape.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		var neck_fixed := true
		var maximum := 0.0
		for i in points.size():
			maximum = maxf(maximum,points[i].distance_to(target[i]))
			var fixed_panel: bool = fixed_roles[i].x==0 if fixed_roles.size()==points.size() else absf(points[i].x)<0.13
			if fixed_panel or points[i].y>1.53: neck_fixed = neck_fixed and points[i].distance_to(target[i])<0.0001
		if cape.get_meta("segmented_mantle",false):
			var roles: PackedVector2Array = cape.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			var torso_count := 0
			var arm_count := 0
			var uniform_triangles := roles.size()==points.size()
			for i in range(0,roles.size(),3):
				uniform_triangles = uniform_triangles and roles[i].x==roles[i+1].x and roles[i].x==roles[i+2].x
				if roles[i].x==0: torso_count += 1
				elif roles[i].x==1: arm_count += 1
				else: uniform_triangles = false
			check(neck_fixed and maximum>0.03 and maximum<0.075 and uniform_triangles and torso_count>100 and arm_count>100,"segmented cape keeps fixed torso panels and bounded shoulder gathering without connector triangles: "+context)
		else:
			check(neck_fixed and maximum>0.03 and maximum<0.062,"cape leaves neck anchored and adds bounded shoulder allowance: "+context)
		print("CAPE_ALLOWANCE: ",context," side=",side," fixed=",neck_fixed," maximum=",maximum)
	if context=="saved":
		var preview: AnimationPlayer = model.get_node("AnimationPreview")
		preview.play("plant")
		preview.seek(0.18,true)
		var driven := 0
		for part in model.get_node("Skeleton3D").get_children():
			if part is MeshInstance3D and str(part.get_meta("source_part","")).begins_with("RainCape"):
				print("CAPE_SAVED_DRIVE: ",part.get_meta("source_part")," ",part.get_blend_shape_value(0))
				if part.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED and part.get_blend_shape_value(0)>0.5: driven += 1
		check(driven>=1,"saved raised-arm clip actually drives its lifted shoulder corrective")
		var folded := {}
		for part in model.get_node("Skeleton3D").get_children():
			if not part is MeshInstance3D or part.get_blend_shape_count()==0: continue
			folded[str(part.get_meta("source_part",""))] = part.get_blend_shape_value(0)
		for side in [-1,1]:
			check(folded.has("CapeHem"+str(side)) and is_equal_approx(float(folded["CapeHem"+str(side)]),float(folded["RainCape"+str(side)])),"saved raised-arm clip keeps cape binding on the same cloth fold")


func check_collars(torso: Node3D, context: String) -> void:
	var coat: MeshInstance3D = torso.get_node("Undercoat")
	var coat_triangles := coat.mesh.generate_triangle_mesh()
	for collar_label in ["CrossedCollar","InnerCollar"]:
		var collar: MeshInstance3D = torso.get_node(collar_label)
		var supported := true
		var minimum := INF
		var maximum := -INF
		var positions: PackedVector3Array = collar.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var samples := positions.duplicate()
		for triangle in range(0,positions.size(),3): samples.append((positions[triangle]+positions[triangle+1]+positions[triangle+2])/3)
		for vertex: Vector3 in samples:
			var point := coat.to_local(collar.to_global(vertex))
			var hit := coat_triangles.intersect_segment(Vector3(point.x,point.y,-1),Vector3(point.x,point.y,1))
			if hit.is_empty():
				supported = false
				continue
			var gap: float = hit.position.z-point.z
			minimum = minf(minimum,gap)
			maximum = maxf(maximum,gap)
		check(supported and minimum>=0.0015 and maximum<=0.010,"continuous collar stays outside the actual undercoat surface: "+context+" / "+collar_label)
		print("COLLAR_CLEARANCE: ",collar_label," min=",minimum," max=",maximum)

func check_metal(model: Node3D, context: String) -> void:
	for side in [-1,1]:
		var parts: Array[MeshInstance3D] = [model.get_node("ShoulderPlate"+str(side)),model.get_node("Leg"+str(side)+"/Knee/KneePlate"),model.get_node("Leg"+str(side)+"/Knee/ShinPlate"),model.get_node("Bracer"+str(side)).get_child(0)]
		for part in parts:
			var material := part.material_override as StandardMaterial3D
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var low := Vector2(INF,INF)
			var high := Vector2(-INF,-INF)
			for point in uv:
				low = low.min(point)
				high = high.max(point)
			var mapped: bool = uv.size()==arrays[Mesh.ARRAY_VERTEX].size() and high.x-low.x>0.1 and high.y-low.y>0.1
			var textures: bool = material!=null and material.albedo_texture!=null and material.roughness_texture!=null
			if textures: textures = material.albedo_texture.get_image().has_mipmaps() and material.roughness_texture.get_image().has_mipmaps() and material.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_RED
			check(mapped and textures,"metal maps retain nondegenerate UV and filtered roughness: "+context+" / "+str(part.name))
