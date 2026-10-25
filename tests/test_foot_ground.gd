extends SceneTree
const Model = preload("res://scripts/hunter_model.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p = world.hunter
	p.set_physics_process(false)
	var boot_mesh: ArrayMesh = p.rig.legs[-1].boot.mesh
	var shoe_arrays := boot_mesh.surface_get_arrays(0)
	var shoe_points: PackedVector3Array = shoe_arrays[Mesh.ARRAY_VERTEX]
	var shoe_normals: PackedVector3Array = shoe_arrays[Mesh.ARRAY_NORMAL]
	var sole_area := 0.0
	var sole_faces_out := true
	for i in range(0,shoe_points.size(),3):
		if is_equal_approx(shoe_points[i].y,-0.5) and is_equal_approx(shoe_points[i+1].y,-0.5) and is_equal_approx(shoe_points[i+2].y,-0.5):
			sole_area += (shoe_points[i+1]-shoe_points[i]).cross(shoe_points[i+2]-shoe_points[i]).length()*0.5
			sole_faces_out = sole_faces_out and shoe_normals[i].dot(Vector3.DOWN)>0.99
	check(sole_area>0.65,"authored boot has a broad flat sole rather than one tangent vertex")
	check(sole_faces_out,"bottom sole normals face outward")
	check(shoe_arrays[Mesh.ARRAY_COLOR].size()==shoe_points.size(),"boot retains material regions as vertex colors")
	for m in get_nodes_in_group("monsters"): m.set_physics_process(false)
	for slope in [Vector2(0.35,0),Vector2(0,0.35),Vector2(0,-0.35)]:
		var terrain := func(point: Vector3) -> float: return point.x*slope.x+point.z*slope.y
		# The runtime callback receives rig-local points and samples their world
		# location. Include the authored body shift in this synthetic terrain too.
		var sample := func(point: Vector3) -> float: return terrain.call(p.rig.root.transform*point)
		for action in ["idle","guard","plant","finisher","light","heavy","reply","hurt"]:
			var elapsed: float = {"light":0.25,"heavy":0.43,"reply":0.26,"hurt":0.08}.get(action,0.95)
			for frame in 90:
				Model.pose_legs(p.rig,action,elapsed,true,0,0,1.0/60,sample)
			var supported := true
			for side in [-1,1]:
				if action=="finisher" and side==1: continue
				var leg: Dictionary = p.rig.legs[side]
				var sole: Vector3 = p.rig.root.transform*(leg.hip.transform*leg.knee.transform*leg.ankle.transform*Vector3(0,-0.1,0))
				# Sole coordinates are in actor space; yaw is zero in this fixture.
				supported = supported and absf(sole.y-terrain.call(sole))<0.003
			check(supported,"support feet fit slope: "+action+str(slope))
			check(p.rig.root.position.y> -0.30,"body offset does not accumulate over frames")
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 2
	ramp.position = Vector3(100,-0.1,0)
	ramp.rotation.z = 0.3
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10,0.2,10)
	collider.shape = box
	ramp.add_child(collider)
	world.add_child(ramp)
	p.global_position = Vector3(100,0,0)
	p.rig.root.rotation = Vector3.ZERO
	await physics_frame
	await physics_frame
	for x in [-0.14,0.14]:
		var actual: float = p.foot_ground_height(Vector3(x,0,0))
		var expected: float = -0.1+0.1/cos(0.3)+x*tan(0.3)
		check(absf(actual-expected)<0.002,"real collision ray samples ramp")
	for frame in 30:
		p.velocity = Vector3(0,-1,0)
		p.move_and_slide()
		await physics_frame
	check(p.is_on_floor(),"actor actually grounded on slope")
	p.combat.drawn = true
	p.combat.set_action("guard")
	for frame in 90: p.animate(1.0/60,0)
	for side in [-1,1]:
		var ankle: Node3D = p.rig.legs[side].ankle
		var sole := ankle.to_global(Vector3(0,-0.1,0))
		var expected: float = -0.1+0.1/cos(0.3)+(sole.x-100)*tan(0.3)
		check(absf(sole.y-expected)<0.003,"runtime animation samples real ramp under each foot")
	var slope_normal := Vector3(-sin(0.3),cos(0.3),0)
	for yaw in [0.0,0.9,2.0]:
		p.rig.root.rotation.y = yaw
		p.animate(0,0)
		for side in [-1,1]:
			var boot: MeshInstance3D = p.rig.legs[side].boot
			check(boot.global_basis.y.normalized().dot(slope_normal)>0.9999,"sole follows world normal at different actor yaw")
			var corners_fit := true
			for x in [-0.5,0.5]:
				for z in [-0.5,0.5]:
					var corner := boot.to_global(Vector3(x,-0.5,z))
					var height: float = -0.1+0.1/cos(0.3)+(corner.x-100)*tan(0.3)
					corners_fit = corners_fit and absf(corner.y-height)<0.003
			check(corners_fit,"all four sole corners lie on actual ramp")
			var actual_sole_fits := true
			var points: PackedVector3Array = boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for point in points:
				if not is_equal_approx(point.y,-0.5): continue
				var contact: Vector3 = boot.to_global(point)
				var height: float = -0.1+0.1/cos(0.3)+(contact.x-100)*tan(0.3)
				actual_sole_fits = actual_sole_fits and absf(contact.y-height)<0.003
			check(actual_sole_fits,"actual mesh sole vertices rest on slope")
			var skeleton: Skeleton3D = p.rig.skinning.skeleton
			var bone := skeleton.find_bone("LeftFoot" if side==-1 else "RightFoot")
			var rendered_up := skeleton.global_basis*skeleton.get_bone_global_pose(bone).basis.y
			check(rendered_up.dot(slope_normal)>0.9999,"rendered Foot bone follows slope")
	p.combat.set_action("finisher")
	p.combat.elapsed = 0.95
	p.animate(0,0)
	check(p.rig.legs[1].boot.global_basis.y.normalized().dot(Vector3.UP)<0.8,"kicking foot releases slope tilt and raises toes for the front kick")
	check(p.rig.legs[-1].boot.global_basis.y.normalized().dot(slope_normal)>0.9999,"kick support foot stays aligned")
	if "--capture" in OS.get_cmdline_user_args():
		world.hud.get_parent().hide()
		p.rig.root.rotation.y = 0.0
		p.combat.set_action("guard")
		p.combat.elapsed = 0.3
		p.animate(0,0)
		var surface := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		surface.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("627068")
		surface.material_override = material
		ramp.add_child(surface)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(101.4,0.70,-2.6)
		camera.look_at(Vector3(100,0.38,0))
		camera.fov = 30
		camera.current = true
		for frame in 30: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-slope-feet.png"))
	p.global_position.y = 3
	check(is_zero_approx(p.foot_ground_height(Vector3.ZERO)),"missing nearby ground returns no offset")
	print("FOOT_GROUND_CHECKS: ",checks," FAILURES: ",failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
