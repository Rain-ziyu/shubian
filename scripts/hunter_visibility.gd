extends Node
## Foreign-object gating avoids highlighting the hunter's own overlapping limbs.
var hunter: CharacterBody3D
var parts: Array[MeshInstance3D] = []
var sources: Array[MeshInstance3D] = []
var material: ShaderMaterial
var occluded := false
var visual_bounds := {}
var triangle_meshes := {}
var blocked_states: Array[bool] = []
var enabled_state: Variant = null
var hurt_state := -1.0
var parameter_updates := 0
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
	var started := Time.get_ticks_usec() if get_meta("measure_frame_cost",false) else 0
	update_visibility()
	if started: set_meta("frame_cost_total_us",int(get_meta("frame_cost_total_us",0))+Time.get_ticks_usec()-started)

func update_visibility() -> void:
	var camera := get_viewport().get_camera_3d()
	occluded = false
	var surfaces: Array = collect_surfaces() if is_instance_valid(camera) and hunter.combat.health>0 else []
	for index in parts.size():
		var blocked := false
		if is_instance_valid(camera) and hunter.combat.health>0:
			var source := sources[index]
			var center := source.to_global(source.get_aabb().get_center())
			blocked = foreign_blocks(camera.global_position,center,surfaces)
		# Keep ray tests current; submit shader state only when its value changes.
		if index>=blocked_states.size():
			blocked_states.append(blocked)
			parts[index].set_instance_shader_parameter("blocked_part",blocked)
			parameter_updates += 1
		elif blocked_states[index]!=blocked:
			blocked_states[index] = blocked
			parts[index].set_instance_shader_parameter("blocked_part",blocked)
			parameter_updates += 1
		occluded = occluded or blocked
	if enabled_state==null or enabled_state!=occluded:
		enabled_state = occluded
		material.set_shader_parameter("enabled",occluded)
		parameter_updates += 1
	var hurt: float = hunter.feedback.hurt_flash/0.22 if hunter.combat.health>0 else 0.0
	if hurt_state!=hurt:
		hurt_state = hurt
		material.set_shader_parameter("hurt_flash",hurt)
		parameter_updates += 1

func collect_surfaces() -> Array:
	# Geometry is static, but articulated transforms change each tick. Share this
	# snapshot across all hunter parts rather than inverting it for every ray.
	var surfaces := []
	for monster in get_tree().get_nodes_in_group("monsters"):
		if not monster.is_visible_in_tree() or monster.global_position.distance_to(hunter.global_position)>24: continue
		var id: int = monster.get_instance_id()
		if not visual_bounds.has(id): visual_bounds[id] = monster.mesh.find_children("*","MeshInstance3D",true,false)
		for mesh in visual_bounds[id]:
			if not is_instance_valid(mesh) or not mesh.is_visible_in_tree(): continue
			var transform: Transform3D = mesh.global_transform
			surfaces.append({"bounds":mesh.get_aabb(),"transform":transform,"inverse":transform.affine_inverse(),"geometry":mesh.mesh,"id":mesh.mesh.get_instance_id()})
	return surfaces

func foreign_blocks(camera_position: Vector3, destination: Vector3, surfaces: Variant = null) -> bool:
	# Keep direct callers fresh; the normal update supplies one coherent snapshot.
	var query := PhysicsRayQueryParameters3D.create(camera_position,destination,2,[hunter.get_rid()])
	var hit := hunter.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.position.distance_to(destination)>0.15: return true
	var candidates: Array = collect_surfaces() if surfaces==null else surfaces
	for surface in candidates:
		var local_start: Vector3 = surface.inverse*camera_position
		var local_end: Vector3 = surface.inverse*destination
		if surface.bounds.intersects_segment(local_start,local_end)==null: continue
		# Empty space inside a large head/body bounding box is not an obstruction.
		var geometry_id: int = surface.id
		if not triangle_meshes.has(geometry_id): triangle_meshes[geometry_id] = surface.geometry.generate_triangle_mesh()
		var triangles: TriangleMesh = triangle_meshes[geometry_id]
		if triangles==null: continue
		var contact: Dictionary = triangles.intersect_segment(local_start,local_end)
		if not contact.is_empty() and (surface.transform*contact.position).distance_to(destination)>0.15: return true
	return false
