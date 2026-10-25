extends RefCounted
## Rigid surfaces use mesh triangles. Skinned limbs/tail use posed fitted tubes;
## these remain approximations, but follow the animated bones outside the body capsule.
const Parts = preload("res://scripts/monster_parts.gd")
const TailSkin = preload("res://scripts/creature_tail_skin.gd")
var triangle_meshes := {}
var model_meshes := {}

func tube(volumes: Array[Dictionary], first: Vector3, last: Vector3, radius: float, part := "limb") -> void:
	var steps := maxi(1,ceili(first.distance_to(last)/maxf(radius,0.03)))
	for step in steps+1:
		volumes.append({"id":part,"center":first.lerp(last,float(step)/steps),"radius":radius})

func cast(monster: Node3D, start: Vector3, end: Vector3) -> Dictionary:
	var result := {}
	var nearest := start.distance_to(end)+0.0001
	var s: float = monster.data.size
	var center := monster.global_position+Vector3.UP*s*0.6
	if Geometry3D.get_closest_point_to_segment(center,start,end).distance_to(center)>s*2.1: return result
	var id := monster.get_instance_id()
	if not model_meshes.has(id): model_meshes[id] = monster.mesh.find_children("*","MeshInstance3D",true,false)
	var neck: Node3D = monster.mesh.get_node("Neck")
	for mesh: MeshInstance3D in model_meshes[id]:
		if mesh in monster.weak_markers or not mesh.is_visible_in_tree() or mesh.skin!=null: continue
		var inverse := mesh.global_transform.affine_inverse()
		var first := inverse*start
		var last := inverse*end
		if mesh.get_aabb().intersects_segment(first,last)==null: continue
		var geometry_id := mesh.mesh.get_instance_id()
		if not triangle_meshes.has(geometry_id): triangle_meshes[geometry_id] = mesh.mesh.generate_triangle_mesh()
		var geometry: TriangleMesh = triangle_meshes[geometry_id]
		if geometry==null: continue
		var contact := geometry.intersect_segment(first,last)
		if contact.is_empty(): continue
		var point: Vector3 = mesh.global_transform*contact.position
		var distance := start.distance_to(point)
		if distance>=nearest: continue
		nearest = distance
		var part := "head" if neck.is_ancestor_of(mesh) else ("spine" if str(mesh.name).begins_with("Crest") else ("flank" if Parts.at_point(monster,point)=="flank" else "body"))
		if str(mesh.name).begins_with("Forelimb"): part = "limb"
		result = {"point":point,"part":part,"distance":distance,"surface":str(mesh.name)}
	var fitted: Array[Dictionary] = []
	var tail: Node3D = monster.mesh.get_node("Tail")
	var rings: Array[Vector4] = TailSkin.contact_profile(tail,monster.tail_rings)
	for index in range(rings.size()-1):
		var a := rings[index]
		var b := rings[index+1]
		tube(fitted,tail.to_global(Vector3(a.w,a.y,a.x)),tail.to_global(Vector3(b.w,b.y,b.x)),maxf(a.z,b.z)+0.015,"tail")
	for label in ["Front-1","Front1","Hind-1","Hind1"]:
		var leg := monster.mesh.get_node_or_null(label) as Node3D
		if leg==null: continue
		var bones: Skeleton3D = leg.get_node("LegSkeleton")
		var hip := bones.to_global(bones.get_bone_global_pose(0).origin)
		var knee := bones.to_global(bones.get_bone_global_pose(1).origin)
		var ankle := bones.to_global(bones.get_bone_global_pose(2).origin)
		tube(fitted,hip,knee,s*0.14)
		tube(fitted,knee,ankle,s*0.075)
		tube(fitted,ankle,ankle+leg.global_basis*Vector3(0,0,-s*0.18),s*0.10)
	var direction := end-start
	var hit := Parts.cast_volumes(fitted,start,direction.normalized(),direction.length(),0)
	if not hit.is_empty() and float(hit.distance)<nearest:
		var part: String = "tail" if Parts.at_point(monster,hit.point)=="tail" else "tail_tip"
		if hit.part!="tail": part = str(hit.part)
		result = {"point":hit.point,"part":part,"distance":hit.distance,"surface":"posed_skin"}
	return result
