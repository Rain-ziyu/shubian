extends Node3D
## Short-lived visual snapshot; owns no collision, damage, resources or combat clock.
var source: Node3D
var departure := Transform3D.IDENTITY
var arrival := Transform3D.IDENTITY
var age := 0.0
var lifetime := 0.35
var material: StandardMaterial3D
var ghosts: Array[Node3D] = []
var rings: Array[MeshInstance3D] = []
static var shared_template: StandardMaterial3D
static func template() -> StandardMaterial3D:
	if shared_template==null:
		shared_template = StandardMaterial3D.new()
		shared_template.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_template.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shared_template.albedo_color = Color(0.48,0.86,0.79,0.28)
	return shared_template

static func make_snapshot_for(rig: Node3D, ghost_material: StandardMaterial3D) -> Node3D:
	# Build only visible geometry with the ghost material from the outset.
	# Duplicating the complete rig briefly allocates its original per-instance
	# shader parameters, including hidden source meshes and inactive gun shadows.
	var snapshot := Node3D.new()
	var inverse := rig.global_transform.affine_inverse()
	var skeletons := {}
	for original: Skeleton3D in rig.find_children("*","Skeleton3D",true,false):
		var clone := Skeleton3D.new()
		clone.name = original.name
		clone.transform = inverse*original.global_transform
		snapshot.add_child(clone)
		skeletons[original.get_instance_id()] = clone
		for bone in original.get_bone_count(): clone.add_bone(original.get_bone_name(bone))
		for bone in original.get_bone_count():
			var parent := original.get_bone_parent(bone)
			if parent>=0: clone.set_bone_parent(bone,parent)
			clone.set_bone_rest(bone,original.get_bone_rest(bone))
			clone.set_bone_pose_position(bone,original.get_bone_pose_position(bone))
			clone.set_bone_pose_rotation(bone,original.get_bone_pose_rotation(bone))
			clone.set_bone_pose_scale(bone,original.get_bone_pose_scale(bone))
	for original: MeshInstance3D in rig.find_children("*","MeshInstance3D",true,false):
		if not original.is_visible_in_tree(): continue
		var clone := MeshInstance3D.new()
		clone.material_override = ghost_material
		clone.mesh = original.mesh
		clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bones := original.get_node_or_null(original.skeleton) as Skeleton3D if original.skin!=null else null
		if bones!=null and skeletons.has(bones.get_instance_id()):
			skeletons[bones.get_instance_id()].add_child(clone)
			clone.transform = bones.global_transform.affine_inverse()*original.global_transform
			clone.skin = original.skin
			clone.skeleton = NodePath("..")
		else:
			snapshot.add_child(clone)
			clone.transform = inverse*original.global_transform
		for shape in original.get_blend_shape_count(): clone.set_blend_shape_value(shape,original.get_blend_shape_value(shape))
	return snapshot

func _ready() -> void:
	add_to_group("teleport_feedback")
	material = template().duplicate()
	for index in 2:
		var snapshot := make_snapshot_for(source,material)
		snapshot.name = "DepartureGhost" if index==0 else "ArrivalGhost"
		add_child(snapshot)
		snapshot.global_transform = departure if index==0 else arrival
		for bones: Skeleton3D in snapshot.find_children("*","Skeleton3D",true,false): bones.force_update_all_bone_transforms()
		ghosts.append(snapshot)
		var ring := MeshInstance3D.new()
		var shape := TorusMesh.new()
		shape.inner_radius = 0.57
		shape.outer_radius = 0.63
		shape.rings = 24
		shape.ring_segments = 12
		ring.mesh = shape
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = (departure.origin if index==0 else arrival.origin)+Vector3.UP*0.12
		rings.append(ring)
	var distance := departure.origin.distance_to(arrival.origin)
	for index in 3:
		var streak := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.022,0.022,distance)
		streak.mesh = shape
		streak.material_override = material
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(streak)
		streak.global_position = (departure.origin+arrival.origin)*0.5+Vector3.UP*(0.7+index*0.18)
		streak.look_at(arrival.origin+Vector3.UP*(0.7+index*0.18))
func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age/lifetime,0,1)
	material.albedo_color.a = 0.28*pow(1-progress,2)
	for ring in rings: ring.scale = Vector3.ONE*(0.8+progress*0.8)
	if age>=lifetime: queue_free()
