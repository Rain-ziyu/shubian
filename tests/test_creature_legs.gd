extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func skinned_point(skeleton: Skeleton3D, arrays: Array, index: int) -> Vector3:
	var result := Vector3.ZERO
	for slot in 4:
		var bone: int = arrays[Mesh.ARRAY_BONES][index*4+slot]
		var weight: float = arrays[Mesh.ARRAY_WEIGHTS][index*4+slot]
		result += skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse()*arrays[Mesh.ARRAY_VERTEX][index]*weight
	return skeleton.to_global(result)
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in database.species:
		var model := Model.create(holder,species)
		var saved = load("res://assets/models/"+str(species.id)+"-v1.tscn").instantiate()
		holder.add_child(saved)
		check_claw(model.get_node("Hind1/Claw0"),float(species.size),"runtime")
		check_claw(saved.get_node("Hind1/Claw0"),float(species.size),"saved")
		check_foot(model.get_node("Hind1/Foot"),"runtime")
		check_foot(saved.get_node("Hind1/Foot"),"saved")
		for side in [-1,1]:
			var saved_leg: Node3D = saved.get_node("Hind"+str(side))
			var skeleton := saved_leg.get_node_or_null("LegSkeleton") as Skeleton3D
			check(skeleton!=null and skeleton.get_bone_count()==4,"saved model retains leg bones")
			if skeleton:
				var foot: MeshInstance3D = skeleton.get_node("Skin_Foot")
				check(foot.skin!=null and foot.skin.get_bind_count()==4 and foot.skeleton==NodePath(".."),"saved model retains ankle skin")
		for gait in [0.0,PI/2,PI,PI*1.5]:
			for frame in 30: Model.animate(model,species,gait,"idle",0,4)
			check(model.position.y> -0.25,"body height does not accumulate over frames")
			for side in [-1,1]:
				var leg: Node3D = model.get_node("Hind"+str(side))
				var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
				var hip := skeleton.get_bone_global_pose(0)
				var knee := skeleton.get_bone_global_pose(1)
				var ankle := skeleton.get_bone_global_pose(2)
				check(absf(hip.origin.distance_to(knee.origin)-skeleton.get_bone_rest(1).origin.length())<0.001 and absf(knee.origin.distance_to(ankle.origin)-skeleton.get_bone_rest(2).origin.length())<0.001,"two leg segments retain lengths")
				check(ankle.basis.y.dot(Vector3.UP)>0.999,"ankle levels foot through knee bends")
				var foot: MeshInstance3D = leg.get_node("Foot")
				var sole := leg.to_global(ankle*skeleton.get_bone_global_rest(2).affine_inverse()*(foot.transform*Vector3(0,-0.5,0)))
				check(sole.y>= -0.002,"animated foot avoids flat floor penetration")
				check(absf(skeleton.get_bone_pose_rotation(1).get_angle())>0.02,"walking bends actual knee bone")
		Model.animate(model,species,0,"idle",0,0)
		for phase in ["idle","windup"]:
			Model.animate(model,species,0,phase,float(species.windup),0)
			for side in [-1,1]:
				var leg: Node3D = model.get_node("Hind"+str(side))
				var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
				var foot: MeshInstance3D = leg.get_node("Foot")
				var sole := leg.to_global(skeleton.get_bone_global_pose(2)*skeleton.get_bone_global_rest(2).affine_inverse()*(foot.transform*Vector3(0,-0.5,0)))
				check(absf(sole.y)<0.002,"idle or lowered charging torso keeps planted feet on flat floor")
				var claw: MeshInstance3D = skeleton.get_node("Skin_Claw0")
				var claw_arrays: Array = claw.mesh.surface_get_arrays(0)
				var lowest := INF
				for vertex in claw_arrays[Mesh.ARRAY_VERTEX].size(): lowest = minf(lowest,skinned_point(skeleton,claw_arrays,vertex).y)
				check(lowest>= -0.002 and lowest<float(species.size)*0.04,"curved claw stays near the floor without piercing it during "+phase)
		for leg_name in ["Hind-1","Hind1","Front-1","Front1"]:
			var leg := model.get_node_or_null(leg_name) as Node3D
			if not leg: continue
			var skeleton: Skeleton3D = leg.get_node("LegSkeleton")
			check(skeleton.get_bone_count()==4 and skeleton.get_bone_parent(2)==1,"hip knee ankle chain exists")
			var rendered: MeshInstance3D = skeleton.get_node("Skin_LegSurface")
			var arrays := rendered.mesh.surface_get_arrays(0)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var normalized := true
			for i in range(0,weights.size(),4): normalized = normalized and absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)<0.0001
			check(normalized and not leg.get_node("LegSurface").visible and rendered.visible,"leg uses normalized blended skin")
			check(skeleton.has_node("Skin_Foot") and skeleton.has_node("Skin_Claw0"),"foot and claws are attached to ankle skin")
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var top := 0
			for index in vertices.size():
				if vertices[index].y>vertices[top].y: top = index
			check(weights[top*4+2]>0.999 and arrays[Mesh.ARRAY_BONES][top*4+2]==3,"upper thigh is anchored to pelvis")
			Model.animate(model,species,0,"idle",0,0)
			var body: MeshInstance3D = model.get_node("BodySurface")
			var attachment := body.to_local(skinned_point(skeleton,arrays,top))
			check(body.mesh.get_aabb().has_point(attachment),"attachment tip is buried inside torso bounds")
			var stable := true
			for phase in ["idle","windup","active","recover"]:
				for frame in 20:
					Model.animate(model,species,float(frame)*0.4,phase,float(frame)*0.03,5)
					stable = stable and body.to_local(skinned_point(skeleton,arrays,top)).distance_to(attachment)<0.002
			check(stable,"actual weighted attachment follows torso throughout gait and attack poses")
	print("CREATURE_LEG_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)

func check_foot(foot: MeshInstance3D, context: String) -> void:
	var points: PackedVector3Array = foot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lower := Vector2(INF,INF)
	var upper := Vector2(-INF,-INF)
	var above_floor := true
	for point in points:
		above_floor = above_floor and point.y>= -0.50001
		if absf(point.y+0.5)>0.00001: continue
		lower = lower.min(Vector2(point.x,point.z))
		upper = upper.max(Vector2(point.x,point.z))
	check(above_floor and upper.x-lower.x>0.2 and upper.y-lower.y>0.2,"foot has a broad sole rather than a single contact pole: "+context)

func check_claw(claw: MeshInstance3D, size: float, context: String) -> void:
	var points: PackedVector3Array = claw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges := {}
	for triangle in range(0,points.size(),3):
		for edge in 3:
			var a := str(Vector3i((points[triangle+edge]*1000000).round()))
			var b := str(Vector3i((points[triangle+(edge+1)%3]*1000000).round()))
			var key := a+"|"+b if a<b else b+"|"+a
			edges[key] = int(edges.get(key,0))+1
	var closed := true
	for count in edges.values(): closed = closed and count==2
	check(closed and points.size()>1000 and claw.mesh.get_aabb().position.z< -size*0.045,"closed keratin claw has a genuinely curved tip: "+context)
