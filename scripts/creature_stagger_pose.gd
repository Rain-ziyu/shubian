extends RefCounted
const Model = preload("res://scripts/creature_model.gd")
const DURATION := 0.22
var clock := 0.0
var source := {}
var tail_rotations: Array[Quaternion] = []
func begin(actor: CharacterBody3D) -> void:
	clock = 0
	var mesh: Node3D = actor.mesh
	source = {"body_y":mesh.position.y-float(mesh.get_meta("ground_offset",0.0)),"body_rotation":mesh.rotation,"neck_rotation":mesh.get_node("Neck").rotation,"tail_rotation":mesh.get_node("Tail").rotation,"feet":{}}
	source.jaw_rotation = mesh.get_node("Neck/Jaw").rotation
	source.body_surface_rotation = mesh.get_node("BodySurface").rotation
	source.forelimbs = {}
	for side in [-1,1]:
		var arm := mesh.get_node_or_null("Forelimb"+str(side)) as Node3D
		if arm==null: continue
		source.forelimbs[mesh.get_path_to(arm)] = arm.rotation
		var wrist := arm.get_node_or_null("Wrist") as Node3D
		if wrist==null: continue
		source.forelimbs[mesh.get_path_to(wrist)] = wrist.rotation
		for digit in [-1,0,1]:
			var finger: Node3D = wrist.get_node("Digit"+str(digit))
			source.forelimbs[mesh.get_path_to(finger)] = finger.rotation
	for name in ["Hind-1","Hind1","Front-1","Front1"]:
		var leg := mesh.get_node_or_null(name) as Node3D
		if leg==null: continue
		var bones: Skeleton3D = leg.get_node("LegSkeleton")
		var ankle := bones.get_bone_global_pose(2)
		source.feet[name] = {"point":actor.to_local(leg.to_global(ankle.origin)),"basis":actor.global_basis.inverse()*leg.global_basis*ankle.basis}
	tail_rotations.clear()
	var tail: Skeleton3D = mesh.get_node("Tail/TailSkeleton")
	for bone in tail.get_bone_count(): tail_rotations.append(tail.get_bone_pose_rotation(bone))
func apply(actor: CharacterBody3D, delta: float) -> void:
	var blend := smoothstep(0,DURATION,clock)
	# Keep a visible brace while control is disabled, then release before AI resumes.
	# Entry remains the captured attack pose; no ordinary-hit flinch is introduced.
	var brace := smoothstep(0,0.10,clock)*smoothstep(0,0.18,actor.stagger)
	var override := {"body_y":float(source.body_y)*(1-blend)-float(actor.data.size)*(0.018*sin(blend*PI)+0.025*brace),"body_rotation":source.body_rotation.lerp(Vector3.ZERO,blend),"neck_rotation":source.neck_rotation.lerp(Vector3(0.16*brace,0,0),blend),"tail_rotation":source.tail_rotation.lerp(Vector3.ZERO,blend),"feet":source.feet,"blend":blend}
	override.jaw_rotation = source.jaw_rotation.lerp(Model.REST_JAW_ROTATION,blend)
	override.body_surface_rotation = source.body_surface_rotation.lerp(Vector3.ZERO,blend)
	override.forelimbs = source.forelimbs
	Model.animate(actor.mesh,actor.data,actor.gait,"stagger",clock,0,actor.foot_ground_height if actor.is_on_floor() else Callable(),actor.foot_ground_normal if actor.is_on_floor() else Callable(),actor.data.pattern=="leap",override)
	var tail: Skeleton3D = actor.mesh.get_node("Tail/TailSkeleton")
	for bone in tail_rotations.size():
		tail.set_bone_pose_rotation(bone,tail_rotations[bone].slerp(tail.get_bone_pose_rotation(bone),blend))
	tail.force_update_all_bone_transforms()
	clock += delta
static func neutral() -> Dictionary:
	return {"body_y":0.0,"body_rotation":Vector3.ZERO,"body_surface_rotation":Vector3.ZERO,"neck_rotation":Vector3.ZERO,"jaw_rotation":Model.REST_JAW_ROTATION,"tail_rotation":Vector3.ZERO,"cancelled_attack":true}
