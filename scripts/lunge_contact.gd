extends RefCounted
## Swept fitted ring volumes follow visible rigid attack parts and the hunter capsule.
## This remains a surface-fitted volume approximation, not exact triangle collision.
const Contact = preload("res://scripts/tail_contact.gd")
var surfaces: Array[Dictionary] = []
var previous_feet := Vector3.ZERO
var previous_epoch := -1
var last_part := ""
func configure(actor: CharacterBody3D) -> void:
	surfaces.clear()
	for source: MeshInstance3D in actor.mesh.find_children("*","MeshInstance3D",true,false):
		var label := str(source.name)
		if label not in ["BodySurface","HeadSurface","Jaw","Palm","Finger","Talon"] and not label.begins_with("Forelimb") and not label.begins_with("BrowHorn"): continue
		var rings: Array[Vector4] = Contact.profile(source.mesh)
		var radius_scale := maxf(source.global_basis.x.length(),source.global_basis.y.length())
		for index in rings.size(): rings[index].z *= radius_scale
		surfaces.append({"source":source,"rings":rings,"previous":source.global_transform})
func update(actor: CharacterBody3D, active: bool) -> Dictionary:
	var result := {}
	var target: CharacterBody3D = actor.target
	if not is_instance_valid(target): return result
	var start: Vector3 = previous_feet if target.motion_epoch==previous_epoch else target.global_position
	var possible: bool = active and (actor.lunge_contains(target.global_position) or actor.lunge_contains(start))
	for surface in surfaces:
		var current: Transform3D = surface.source.global_transform
		if possible and result.is_empty():
			result = Contact.contact(surface.rings,surface.previous,current,target.global_position,start)
			if not result.is_empty():
				last_part = str(surface.source.name)
				result["part"] = last_part
		surface.previous = current
	previous_feet = target.global_position
	previous_epoch = target.motion_epoch
	return result

