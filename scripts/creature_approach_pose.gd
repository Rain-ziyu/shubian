extends RefCounted
## Preserve support while changing locomotion or entering authored anticipation.
const DURATION := 0.18
static func capture(actor: CharacterBody3D, world_feet := false) -> Dictionary:
	var mesh: Node3D = actor.mesh
	var source := {"body_y_from":mesh.position.y-float(mesh.get_meta("ground_offset",0)),"feet":{},"feet_world":world_feet}
	for name in ["Hind-1","Hind1","Front-1","Front1"]:
		var leg := mesh.get_node_or_null(name) as Node3D
		if leg==null: continue
		var bones: Skeleton3D = leg.get_node("LegSkeleton")
		var ankle := bones.get_bone_global_pose(2)
		var point := leg.to_global(ankle.origin)
		var basis := leg.global_basis*ankle.basis
		source.feet[name] = {"point":point if world_feet else actor.to_local(point),"basis":basis if world_feet else actor.global_basis.inverse()*basis}
	return source
static func sample(source: Dictionary, clock: float) -> Dictionary:
	if source.is_empty() or clock>=DURATION: return {}
	return {"body_y_from":source.body_y_from,"feet":source.feet,"feet_world":source.get("feet_world",false),"blend":smoothstep(0,DURATION,clock)}
