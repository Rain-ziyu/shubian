extends "res://tools/benchmark_forest_hunt.gd"
## Targeted live encounter with privileged initial placement; all five AI active.
var prepared := false
var observed := {}
var capture_requested := false
var initial_health := 0.0
var target_species := "stormcrest"
func setup() -> void:
	await super.setup()
	for candidate in get_nodes_in_group("monsters"):
		if candidate.data.id==target_species: monster = candidate
	fighter.global_position = monster.global_position-monster.global_basis.z*(float(monster.data.size)*1.25+0.8)
	fighter.global_position.y = preload("res://scripts/forest_terrain.gd").height_at(fighter.position.x,fighter.position.z)+0.15
	fighter.velocity = Vector3.ZERO
	fighter.lock_target = monster
	var offset: Vector3 = monster.global_position-fighter.global_position
	fighter.yaw = atan2(-offset.x,-offset.z)
	fighter.set_process_input(false)
	initial_health = fighter.combat.health
	previous = fighter.position
	sample_limit = 30.0
	prepared = true
func control() -> void:
	if not prepared or finished: return
	if is_instance_valid(monster) and monster.data.id==target_species:
		observed[monster.phase] = int(observed.get(monster.phase,0))+1
		if not capture_requested and monster.phase=="windup" and monster.clock>0.4:
			capture_requested = true
			capture_encounter.call_deferred()
	super.control()
func capture_encounter() -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-"+target_species+"-neck-live.png"))
	print(target_species.to_upper()+"_LIVE_CAPTURE: ",error)
func finish() -> void:
	if finished: return
	var result := {"species":target_species,"phases":observed,"initial_health":initial_health,"final_health":fighter.combat.health,"target_contacts":int(contacts.get(target_species,0)),"scope":"30 second native encounter, actual AI, camera and contact feedback; privileged initial placement and tactics controller; all five AI active, no resource resets; not full expedition or human acceptance"}
	result["passed"] = observed.has("windup") and observed.has("active") and observed.has("recover") and result.target_contacts>0 and fighter.combat.health>0
	var path := "res://../verification/"+target_species+"-neck-"+str(OS.get_process_id())+".json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(target_species.to_upper()+"_NECK_ENCOUNTER: ",JSON.stringify(result))
	await super.finish()
	if not result.passed: quit(1)
