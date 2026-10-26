extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
const Mouth = preload("res://scripts/creature_mouth_skin.gd")
class MouthBlocker extends Node3D:
	var mesh: Node3D
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func inspect(model: Node3D, data: Dictionary, context: String) -> void:
	var neck: Node3D = model.get_node("Neck")
	var jaw: MeshInstance3D = neck.get_node("Jaw")
	var skull: MeshInstance3D = neck.get_node("HeadSurface")
	var skeleton: Skeleton3D = neck.get_node("MouthSkeleton")
	var size: float = data.size
	var rest := jaw.transform
	var jaw_surface := jaw.mesh.generate_triangle_mesh()
	var head_surface := skull.mesh.generate_triangle_mesh()
	var state := {}
	for side in [-1,1]: state[side] = {"weights":true,"anchors":true,"fit":true,"bounds":true,"triangles":true}
	var joint := true
	for sample in [["idle",0.0],["windup",float(data.windup)],["active",0.15],["recover",0.2],["override",0.15]]:
		var overridden: bool = sample[0]=="override"
		Model.animate(model,data,0,"active" if overridden else sample[0],sample[1],0,Callable(),Callable(),false,{"jaw_rotation":Vector3(-0.23,0.05,0.02)} if overridden else {})
		joint = joint and skeleton.get_bone_global_pose(1).is_equal_approx(jaw.transform)
		for side in [-1,1]:
			var part: MeshInstance3D = skeleton.get_node("Cheek"+str(side))
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			# TriangleMesh BVH welds positions to a 0.0001 grid (engine
			# core/math/triangle_mesh.cpp). Compare the corresponding grid points.
			var faces := Mouth.triangles(part).get_faces()
			state[side].triangles = state[side].triangles and faces.size()==points.size()
			var box := Mouth.bounds(part).grow(size*0.0001)
			var worst := 0.0
			for index in points.size():
				state[side].weights = state[side].weights and bones[index*4]==0 and bones[index*4+1]==1 and absf(weights[index*4]+weights[index*4+1]-1)<1.1/65535
				var posed := Vector3.ZERO
				for slot in 4:
					var bone := bones[index*4+slot]
					posed += (skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(bone)*points[index])*weights[index*4+slot]
				state[side].bounds = state[side].bounds and box.has_point(posed) and posed.is_finite()
				if index<faces.size():
					worst = maxf(worst,faces[index].distance_to(posed.snappedf(0.0001)))
					state[side].triangles = state[side].triangles and faces[index].distance_to(posed.snappedf(0.0001))<size*0.00001
				if uv[index].y==0:
					state[side].anchors = state[side].anchors and posed.distance_to(points[index])<size*0.00001
					var hit := head_surface.intersect_segment(Vector3(posed.x,-size*0.25,posed.z),Vector3(posed.x,size*0.40,posed.z))
					state[side].fit = state[side].fit and not hit.is_empty() and absf(posed.y-hit.get("position",Vector3.INF).y-size*0.03)<size*0.0001
				elif uv[index].y==1:
					var expected := jaw.transform*rest.affine_inverse()*points[index]
					state[side].anchors = state[side].anchors and posed.distance_to(expected)<size*0.00001
					var local := jaw.transform.affine_inverse()*posed
					var hit := jaw_surface.intersect_segment(Vector3(local.x,size*0.25,local.z),Vector3(local.x,-size*0.25,local.z))
					state[side].fit = state[side].fit and not hit.is_empty() and absf(local.y-hit.get("position",Vector3.INF).y+size*0.005)<size*0.0001
			if context=="mossback live" and side==1: print("CHEEK_DEVIATION: ",sample," verts=",points.size()," faces=",faces.size()," max=",worst)
	check(joint,"cheek jaw follows the final jaw transform including pose override: "+context)
	for side in state:
		for key in state[side]: check(state[side][key],context+" cheek "+str(side)+" "+key)
		var part: MeshInstance3D = skeleton.get_node("Cheek"+str(side))
		check(Mouth.triangles(part)==Mouth.triangles(part),"unchanged jaw reuses its evaluated occlusion geometry: "+context)
func inspect_visibility(model: Node3D, cue: Node, holder: Node3D) -> void:
	var blocker := MouthBlocker.new()
	blocker.mesh = model
	holder.add_child(blocker)
	blocker.add_to_group("monsters")
	var surfaces: Array = cue.collect_surfaces()
	for side in [-1,1]:
		var part: MeshInstance3D = model.get_node("Neck/MouthSkeleton/Cheek"+str(side))
		var candidates := surfaces.filter(func(item: Dictionary): return item.get("deforming")==part)
		check(candidates.size()==1,"visibility collector includes the deforming cheek with a posed bound")
		var faces := Mouth.triangles(part).get_faces()
		var center := (faces[18]+faces[19]+faces[20])/3
		var normal := (faces[19]-faces[18]).cross(faces[20]-faces[18]).normalized()
		var begin := part.to_global(center+normal*0.3)
		var end := part.to_global(center-normal*0.3)
		check(cue.foreign_blocks(begin,end,candidates),"camera ray hits the current cheek after the jaw pose changes")
	blocker.free()
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var hunter := preload("res://scripts/player.gd").new()
	holder.add_child(hunter)
	hunter.set_physics_process(false)
	hunter.set_process_input(false)
	var cue := hunter.get_node("OcclusionVisibility")
	cue.set_physics_process(false)
	var species: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json")).species
	for data in species:
		var live := Model.create(holder,data)
		var saved: Node3D = load("res://assets/models/"+str(data.id)+"-v1.tscn").instantiate()
		holder.add_child(saved)
		for side in [-1,1]:
			var path := "Neck/MouthSkeleton/Cheek"+str(side)
			check(live.get_node(path).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==saved.get_node(path).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"saved cheek bind surface matches live: "+str(data.id))
		inspect(live,data,str(data.id)+" live")
		inspect(saved,data,str(data.id)+" saved")
		inspect_visibility(live,cue,holder)
		live.queue_free()
		saved.queue_free()
	holder.queue_free()
	await process_frame
	print("CREATURE_CHEEK_CHECKS: ",checks," FAILURES: ",failures)
	quit(1 if failures else 0)
