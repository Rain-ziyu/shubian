extends RefCounted
## Authored side fall with conservative mesh support; not a ragdoll.
var started := false
var elapsed := 0.0
var initial_y := 0.0
var initial_rotation := Vector3.ZERO
var corners: Array[Vector3] = []
var ground_y := -INF
var landed := false
func begin(actor: CharacterBody3D) -> void:
	started = true
	initial_y = actor.mesh.position.y
	initial_rotation = actor.mesh.rotation
	for part in actor.mesh.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D = actor.mesh.global_transform.affine_inverse()*part.global_transform
		var bounds: AABB = part.get_aabb()
		for i in 8: corners.append(transform*(bounds.position+bounds.size*Vector3(i&1,(i>>1)&1,(i>>2)&1)))
	sample_ground(actor)
func sample_ground(actor: CharacterBody3D) -> void:
	ground_y = -INF
	var size: float = actor.data.size
	for offset in [Vector3.ZERO,Vector3(-size*0.7,0,0),Vector3(-size*0.7,0,-size*0.5),Vector3(-size*0.7,0,size*0.5)]:
		var point: Vector3 = actor.global_position+actor.global_basis*offset
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*size*1.5,point-Vector3.UP*size*3,2,[actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): ground_y = maxf(ground_y,hit.position.y)
func update(actor: CharacterBody3D, delta: float) -> void:
	if not started: begin(actor)
	if actor.is_on_floor() and not landed:
		landed = true
		sample_ground(actor)
	elapsed += delta
	var weight := smoothstep(0.05,0.95,elapsed)
	actor.mesh.rotation = initial_rotation.lerp(Vector3(0,initial_rotation.y,PI/2),weight)
	var lowest := INF
	for corner in corners: lowest = minf(lowest,(actor.mesh.basis*corner).y)
	var desired := lerpf(initial_y,0.0,weight)
	if is_finite(ground_y): desired = maxf(desired,ground_y-actor.global_position.y-lowest+0.025)
	actor.mesh.position.y = desired
