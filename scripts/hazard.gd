extends Node3D
const Visuals = preload("res://scripts/visuals.gd")
const Terrain = preload("res://scripts/forest_terrain.gd")
var target: CharacterBody3D
var radius := 4.0
var lifetime := 6.0
var interval := 0.8
var damage := 9.0
var clock := 0.0
var kind := "mist"
var surface: MeshInstance3D
var source_actor: CollisionObject3D
var mist_material: ShaderMaterial
var boundary: MeshInstance3D
var puffs: Array[MeshInstance3D] = []
var visual_age := 0.0
var puff_base_y: Array[float] = []
# Immutable terrain fit retained from this attack's warning, when compatible.
var prepared_disc: ArrayMesh
var prepared_transform := Transform3D.IDENTITY
var prepared_radius := -1.0

func _ready() -> void:
	add_to_group("hazards")
	surface = Visuals.piece(self,Vector3(0,0.10,0),Vector3(radius*2,0.12,radius*2),Color("79a64b") if kind=="mist" else Color("78cfe2"),true)
	var material := surface.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.45
	if kind in ["mist","pulse"]:
		material.albedo_color.a = 0.12 if kind=="mist" else 0.35
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.02
		disc.radial_segments = 64
		surface.mesh = disc
		surface.scale = Vector3.ONE
		if kind=="mist":
			mist_material = ShaderMaterial.new()
			mist_material.shader = preload("res://shaders/hazard_mist.gdshader")
			mist_material.set_shader_parameter("density",1.0)
		boundary = MeshInstance3D.new()
		boundary.name = "DangerBoundary"
		var ring := TorusMesh.new()
		ring.inner_radius = maxf(0.01,radius-0.04)
		ring.outer_radius = radius+0.04
		ring.rings = 64
		ring.ring_segments = 8
		boundary.mesh = ring
		boundary.material_override = Visuals.mat(Color("aec878") if kind=="mist" else Color("78cfe2"),true)
		boundary.position.y = 0.1
		add_child(boundary)
		for i in (7 if kind=="mist" else 0):
			var angle := i*TAU/7
			var puff := Visuals.piece(self,Vector3(cos(angle)*radius*0.5,0.7,sin(angle)*radius*0.5),Vector3(radius*0.7,1.1,radius*0.7),Color("7ea866"),true)
			puff.material_override = mist_material
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puffs.append(puff)
			puff_base_y.append(0.7)
		conform_ground.call_deferred()

func _process(delta: float) -> void:
	if kind!="mist": return
	visual_age += delta
	mist_material.set_shader_parameter("density",clampf(lifetime/0.6,0,1))
	for index in puffs.size(): puffs[index].position.y = puff_base_y[index]+sin(visual_age*0.9+index*0.8)*0.09

func ground_point(x: float, z: float, lift: float) -> Vector3:
	return disc_point(self,x,z,lift)

static func disc_point(origin: Node3D, x: float, z: float, lift: float) -> Vector3:
	var world := origin.to_global(Vector3(x,0,z))
	return origin.to_local(Vector3(world.x,Terrain.effect_height_at(world.x,world.z)+lift,world.z))

func conform_ground() -> void:
	if is_queued_for_deletion(): return
	var measured := is_instance_valid(source_actor) and bool(source_actor.get_meta("measure_frame_cost",false))
	var started := Time.get_ticks_usec() if measured else 0
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 64:
		var a := TAU*index/64
		var b := TAU*(index+1)/64
		var inner_a := ground_point(cos(a)*(radius-0.04),sin(a)*(radius-0.04),0.08)
		var outer_a := ground_point(cos(a)*(radius+0.04),sin(a)*(radius+0.04),0.08)
		var inner_b := ground_point(cos(b)*(radius-0.04),sin(b)*(radius-0.04),0.08)
		var outer_b := ground_point(cos(b)*(radius+0.04),sin(b)*(radius+0.04),0.08)
		for point in [inner_a,outer_a,inner_b,outer_a,outer_b,inner_b]: band.add_vertex(point)
	band.generate_normals()
	boundary.mesh = band.commit()
	boundary.position = Vector3.ZERO
	boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var same_center := Vector2(global_position.x-prepared_transform.origin.x,global_position.z-prepared_transform.origin.z).length()<0.00001
	if prepared_disc!=null and prepared_radius==radius and same_center:
		surface.mesh = prepared_disc
		surface.transform = global_transform.affine_inverse()*prepared_transform
	else:
		surface.mesh = ground_disc(self,radius)
		surface.transform = Transform3D.IDENTITY
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in puffs.size():
		var puff := puffs[index]
		puff_base_y[index] = ground_point(puff.position.x,puff.position.z,0.7).y
	if started: source_actor.set_meta("hazard_ground_total_us",int(source_actor.get_meta("hazard_ground_total_us",0))+Time.get_ticks_usec()-started)

static func ground_disc(origin: Node3D, disc_radius: float) -> ArrayMesh:
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := maxi(1,ceili(disc_radius/0.35))
	var samples: Array[PackedVector3Array] = []
	var center := disc_point(origin,0,0,0.06)
	for ring in range(rings+1):
		var row := PackedVector3Array()
		var distance := disc_radius*float(ring)/rings
		for index in 64:
			var angle := TAU*index/64
			row.append(center if ring==0 else disc_point(origin,cos(angle)*distance,sin(angle)*distance,0.06))
		samples.append(row)
	for ring in rings:
		for index in 64:
			var next := (index+1)%64
			var ia: Vector3 = samples[ring][index]
			var oa: Vector3 = samples[ring+1][index]
			var ib: Vector3 = samples[ring][next]
			var ob: Vector3 = samples[ring+1][next]
			for point in ([ia,oa,ob] if ring==0 else [ia,oa,ib,oa,ob,ib]): fill.add_vertex(point)
	fill.generate_normals()
	return fill.commit()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime<=0:
		queue_free()
		return
	clock -= delta
	if clock<=0:
		clock += interval
		if contains_target(): target.take_damage(damage,global_position,false,kind!="mist")

func contains_target() -> bool:
	if not is_instance_valid(target) or target.combat.health<=0: return false
	var offset := target.global_position-global_position
	if Vector2(offset.x,offset.z).length()>=radius or absf(offset.y)>=2.0: return false
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,target.global_position+Vector3.UP)
	query.exclude = [target.get_rid()]
	if is_instance_valid(source_actor): query.exclude = [target.get_rid(),source_actor.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
