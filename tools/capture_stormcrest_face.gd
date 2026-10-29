extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(800,600);root.content_scale_size=root.size
	var stage=Node3D.new();root.add_child(stage)
	var world=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("aeb8b3")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.45;stage.add_child(world)
	var sun=DirectionalLight3D.new();sun.rotation=Vector3(-.7,-.6,0);sun.light_energy=1.;stage.add_child(sun)
	var data:Dictionary
	for species in JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json")).species:
		if species.id=="stormcrest":data=species
	var model=preload("res://scripts/creature_model.gd").create(stage,data)
	var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=32
	var neck:Node3D=model.get_node("Neck");var size:float=data.size
	var focus=neck.to_global(Vector3(0,.13,-.40)*size)
	var sheet=Image.create(1600,600,false,Image.FORMAT_RGB8)
	for side in range(2):
		camera.position=focus+Vector3(0 if side==0 else size*.85,size*.15,-size*1.40)
		camera.look_at(focus)
		for frame in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var shot=root.get_texture().get_image();shot.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shot,Rect2i(0,0,800,600),Vector2i(side*800,0))
	var folder=ProjectSettings.globalize_path("res://../verification/stormcrest-face")
	DirAccess.make_dir_recursive_absolute(folder)
	var path=folder+("/before.png" if "--before" in OS.get_cmdline_user_args() else "/after.png")
	var error=sheet.save_png(path);print("STORMCREST_FACE_CAPTURE ",error," ",path)
	stage.queue_free();await process_frame;quit(0 if error==OK else 1)
