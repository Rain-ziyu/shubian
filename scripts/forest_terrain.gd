extends Node3D
const Visuals = preload("res://scripts/visuals.gd")
const CLEARINGS := [Vector2(0,-16),Vector2(-26,-22),Vector2(26,-22),Vector2(-25,24),Vector2(25,24)]
const HALF := 60
const STEP := 2
const WATER_CENTER_Y := -0.12
const WATER_THICKNESS := 0.03
const WATER_HALF_WIDTH := 1.7
const WATER_HALF_LENGTH := 59.0
var terrain_body: StaticBody3D
static var grid_heights := {}

static func grid_height(x: float, z: float) -> float:
	# Only the fixed STEP grid is cached; interpolation and the authored surface stay unchanged.
	var key := Vector2i(roundi(x),roundi(z))
	if not grid_heights.has(key): grid_heights[key] = height_at(x,z)
	return grid_heights[key]

static func height_at(x: float, z: float) -> float:
	var height := 1.8+sin(x*0.10)*cos(z*0.08)*1.3+sin(z*0.19+x*0.04)*0.4
	var blend := smoothstep(6,13,absf(x))
	for center in CLEARINGS:
		blend = minf(blend,smoothstep(9,16,Vector2(x,z).distance_to(center)))
	height *= blend
	var river := 1.0-smoothstep(1.8,5.0,absf(x-41))
	return lerpf(height,-0.45,river)

static func mesh_height_at(x: float, z: float) -> float:
	# Match the actual two collision triangles in each STEP-wide ground cell.
	x = clampf(x,-HALF,HALF)
	z = clampf(z,-HALF,HALF)
	var cell_x := clampf(floor(x/STEP)*STEP,-HALF,HALF-STEP)
	var cell_z := clampf(floor(z/STEP)*STEP,-HALF,HALF-STEP)
	var u := (x-cell_x)/STEP
	var v := (z-cell_z)/STEP
	var b := grid_height(cell_x+STEP,cell_z)
	var c := grid_height(cell_x,cell_z+STEP)
	if u+v<=1: return grid_height(cell_x,cell_z)*(1-u-v)+b*u+c*v
	return b*(1-v)+grid_height(cell_x+STEP,cell_z+STEP)*(u+v-1)+c*(1-u)

static func effect_height_at(x: float, z: float) -> float:
	var height := mesh_height_at(x,z)
	if absf(x-41)<=WATER_HALF_WIDTH and absf(z)<=WATER_HALF_LENGTH:
		height = maxf(height,WATER_CENTER_Y+WATER_THICKNESS*0.5)
	return height

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-HALF,HALF,STEP):
		for x in range(-HALF,HALF,STEP):
			var a := Vector3(x,height_at(x,z),z)
			var b := Vector3(x+STEP,height_at(x+STEP,z),z)
			var c := Vector3(x,height_at(x,z+STEP),z+STEP)
			var d := Vector3(x+STEP,height_at(x+STEP,z+STEP),z+STEP)
			for point in [a,b,c,b,d,c]:
				var moss := 0.5+sin(point.x*0.38+point.z*0.23)*0.18
				var color := Color("344d39").lerp(Color("64734d"),moss)
				if absf(point.x)<6: color = Color("4a5141")
				if absf(point.x-41)<4: color = Color("4a514c")
				surface.set_color(color)
				surface.add_vertex(point)
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	ground.name = "WetGround"
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/forest_ground.gdshader")
	ground.material_override = material
	add_child(ground)
	terrain_body = StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = 2
	var collision := CollisionShape3D.new()
	collision.shape = ground.mesh.create_trimesh_shape()
	terrain_body.add_child(collision)
	add_child(terrain_body)
	var water := Visuals.piece(self,Vector3(41,WATER_CENTER_Y,0),Vector3(WATER_HALF_WIDTH*2,WATER_THICKNESS,WATER_HALF_LENGTH*2),Color("4b8884"))
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/forest_water.gdshader")
	water.material_override = water_mat
	water.name = "ShallowStream"
	add_to_group("terrain")
