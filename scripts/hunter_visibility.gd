extends Node
## Foreign-object gating avoids highlighting the hunter's own overlapping limbs.
var hunter: CharacterBody3D
var parts: Array[MeshInstance3D] = []
var sources: Array[MeshInstance3D] = []
var material: ShaderMaterial
var occluded := false
var visual_bounds := {}
var triangle_meshes := {}
func _ready() -> void:
	hunter = get_parent()
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/hunter_occlusion.gdshader")
	material.render_priority = 10
	for binding in hunter.rig.skinning.bindings:
		parts.append(binding.rendered)
		sources.append(binding.source)
		binding.rendered.material_overlay = material
func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	occluded = false
	for index in parts.size():
		var blocked := false
		if is_instance_valid(camera) and hunter.combat.health>0:
			var source := sources[index]
			var center := source.to_global(source.get_aabb().get_center())
			blocked = foreign_blocks(camera.global_position,center)
		parts[index].set_instance_shader_parameter("blocked_part",blocked)
		occluded = occluded or blocked
	material.set_shader_parameter("enabled",occluded)
	material.set_shader_parameter("hurt_flash",hunter.feedback.hurt_flash/0.22 if hunter.combat.health>0 else 0.0)

func foreign_blocks(camera_position: Vector3, destination: Vector3) -> bool:
	# Broad actor capsules can extend into empty space around a visible monster.
	# Use world collision here and articulated visual bounds for monsters below.
	var query := PhysicsRayQueryParameters3D.create(camera_position,destination,2,[hunter.get_rid()])
	var hit := hunter.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.position.distance_to(destination)>0.15: return true
	for monster in get_tree().get_nodes_in_group("monsters"):
		if not monster.is_visible_in_tree() or monster.global_position.distance_to(hunter.global_position)>24: continue
		var id: int = monster.get_instance_id()
		if not visual_bounds.has(id): visual_bounds[id] = monster.mesh.find_children("*","MeshInstance3D",true,false)
		for mesh in visual_bounds[id]:
			if not is_instance_valid(mesh) or not mesh.is_visible_in_tree(): continue
			var local_start: Vector3 = mesh.to_local(camera_position)
			var local_end: Vector3 = mesh.to_local(destination)
			if mesh.get_aabb().intersects_segment(local_start,local_end)==null: continue
			# Empty space inside a large head/body bounding box is not an obstruction.
			var geometry_id: int = mesh.mesh.get_instance_id()
			if not triangle_meshes.has(geometry_id): triangle_meshes[geometry_id] = mesh.mesh.generate_triangle_mesh()
			var triangles: TriangleMesh = triangle_meshes[geometry_id]
			if triangles==null: continue
			var contact: Dictionary = triangles.intersect_segment(local_start,local_end)
			if not contact.is_empty() and mesh.to_global(contact.position).distance_to(destination)>0.15: return true
	return false
