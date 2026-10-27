extends AnimatableBody3D
## Player-only anatomy obstruction. Terrain/AI motion retains its trunk capsules.
var actor: CharacterBody3D
var parts: Array[Dictionary] = []

func _ready() -> void:
	top_level = true
	sync_to_physics = false
	collision_mask = 0
	for label in ["HeadSurface","Jaw"]:
		var source: MeshInstance3D = actor.mesh.get_node("Neck/"+label)
		var shape := CollisionShape3D.new()
		shape.name = label+"Blocker"
		shape.shape = source.mesh.create_convex_shape(true,true)
		add_child(shape)
		parts.append({"source":source,"shape":shape})
	sync_pose()

func _physics_process(_delta: float) -> void: sync_pose()

func sync_pose() -> void:
	if not is_instance_valid(actor): return
	var desired_layer := 4 if actor.health>0 and actor.collision_layer!=0 else 0
	if collision_layer!=desired_layer: collision_layer = desired_layer
	if desired_layer==0: return
	if global_transform!=actor.global_transform: global_transform = actor.global_transform
	var inverse := actor.global_transform.affine_inverse()
	for part in parts:
		var transform: Transform3D = inverse*part.source.global_transform
		if part.shape.transform!=transform: part.shape.transform = transform
