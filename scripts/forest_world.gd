extends Node3D
const Visuals = preload("res://scripts/visuals.gd")
const Hunter = preload("res://scripts/player.gd")
const Monster = preload("res://scripts/monster.gd")
const Terrain = preload("res://scripts/forest_terrain.gd")
const ForestArt = preload("res://scripts/forest_art.gd")
const CombatHUD = preload("res://scripts/combat_hud.gd")
var hunter: CharacterBody3D
var hud: Label
var combat_hud
var navigation = preload("res://scripts/forest_navigation.gd").new()

func obstacle(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	navigation.add_obstacle(pos,size)
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos
	var visual := Visuals.piece(body,Vector3.ZERO,size,color)
	visual.name = "ObstacleVisual"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _ready() -> void:
	var env := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("698185")
	sky_material.sky_horizon_color = Color("a1b1a6")
	sky_material.ground_bottom_color = Color("354b3a")
	sky_material.ground_horizon_color = Color("91a18f")
	sky_material.sun_angle_max = 0.0
	sky.sky_material = sky_material
	atmosphere.sky = sky
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("ccd5dc")
	atmosphere.ambient_light_energy = 0.45
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("879b9e")
	atmosphere.fog_density = 0.014
	env.environment = atmosphere
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-25,0)
	sun.light_energy = 1.0
	sun.light_color = Color("f1e2c8")
	sun.shadow_enabled = true
	add_child(sun)
	add_child(Terrain.new())
	for side in [-1,1]:
		var wall_x := obstacle(Vector3(side*60,4,0),Vector3(1,8,120),Color("3f5348"))
		wall_x.get_node("ObstacleVisual").hide()
		var wall_z := obstacle(Vector3(0,4,side*60),Vector3(120,8,1),Color("3f5348"))
		wall_z.get_node("ObstacleVisual").hide()
	ForestArt.cliffs(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37214
	var positions := [Vector3(0,1,-16),Vector3(-26,1,-22),Vector3(26,1,-22),Vector3(-25,1,24),Vector3(25,1,24)]
	var trunks: Array[Vector3] = []
	for i in 110:
		var pos := Vector3(rng.randf_range(-56,56),0,rng.randf_range(-56,56))
		var clearing := absf(pos.x)<12
		for encounter in positions:
			if pos.distance_to(encounter)<9: clearing = true
		if clearing: continue
		pos.y = Terrain.height_at(pos.x,pos.z)
		var height := rng.randf_range(7,13)
		var trunk := obstacle(pos+Vector3(0,height/2,0),Vector3(0.65,height,0.65),Color("4b5040"))
		trunk.get_node("ObstacleVisual").hide()
		trunk.add_to_group("forest_tree_collisions")
		ForestArt.tree(self,pos,height,i)
		trunks.append(pos)
	# Independent planting seed preserves the original rocks and collision locations.
	var planting := RandomNumberGenerator.new()
	planting.seed = 50894
	for index in 220:
		var pos := Vector3(planting.randf_range(-56,56),0,planting.randf_range(-56,56))
		var safe := absf(pos.x)>8 and absf(pos.x-41)>2.5
		for clearing in Terrain.CLEARINGS:
			if Vector2(pos.x,pos.z).distance_to(clearing)<11: safe = false
		for tree in trunks:
			if Vector2(pos.x-tree.x,pos.z-tree.z).length()<6.2: safe = false
		if not safe: continue
		pos.y = Terrain.height_at(pos.x,pos.z)
		var height := planting.randf_range(9,15)
		var trunk := obstacle(pos+Vector3(0,height/2,0),Vector3(0.65,height,0.65),Color("4b5040"))
		trunk.get_node("ObstacleVisual").hide()
		trunk.add_to_group("forest_tree_collisions")
		ForestArt.tree(self,pos,height,index+300)
		trunks.append(pos)
	var fern_locations: Array[Vector3] = []
	for i in 65:
		var pos := Vector3(rng.randf_range(-55,55),0,rng.randf_range(-55,55))
		pos.y = Terrain.height_at(pos.x,pos.z)
		if absf(pos.x)>7: fern_locations.append(pos)
	ForestArt.understory(self,fern_locations)
	for i in 24:
		var pos := Vector3(rng.randf_range(-55,55),0,rng.randf_range(-55,55))
		var safe := absf(pos.x)>13
		for encounter in positions:
			if pos.distance_to(encounter)<10: safe = false
		if not safe or absf(pos.x-41)<5: continue
		pos.y = Terrain.height_at(pos.x,pos.z)
		var radius := rng.randf_range(0.8,1.7)
		var size := Vector3(radius*1.8,radius,radius*1.5)
		var rock := obstacle(pos+Vector3(0,radius*0.45,0),size,Color("5a665e"))
		rock.get_node("ObstacleVisual").hide()
		ForestArt.rock(rock,size)
	hunter = Hunter.new()
	hunter.position = Vector3(0,1,8)
	add_child(hunter)
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	# All static obstacles now exist. Build the shared clearance grids before
	# gameplay, so entering a new species' aggro radius cannot build one mid-frame.
	navigation.grid_for(0.5)
	for species in database.species: navigation.grid_for(float(species.size)*0.54)
	for i in database.species.size():
		var monster := Monster.new()
		monster.data = database.species[i]
		monster.target = hunter
		monster.position = positions[i]
		add_child(monster)
	combat_hud = CombatHUD.new()
	add_child(combat_hud)
	hud = combat_hud.status
	print("SHUBIAN_FOREST_READY: hunter + five monster species")
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()

func _process(_delta: float) -> void:
	var defeated := 0
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.health<=0: defeated += 1
	combat_hud.update_state(hunter,defeated)

func capture() -> void:
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-forest-prototype.png"))
	get_tree().quit()
