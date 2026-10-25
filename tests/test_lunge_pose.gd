extends SceneTree
const Model = preload("res://scripts/creature_model.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func sole(leg: Node3D) -> Vector3:
	var bones: Skeleton3D = leg.get_node("LegSkeleton")
	var foot: MeshInstance3D = leg.get_node("Foot")
	return leg.to_global(bones.get_bone_global_pose(2)*bones.get_bone_global_rest(2).affine_inverse()*(foot.transform*Vector3(0,-0.5,0)))
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/monsters.json"))
	for species in data.species:
		if species.pattern not in ["charge","leap"]: continue
		var model := Model.create(holder,species)
		var neck: Node3D = model.get_node("Neck")
		var speed := 13.0 if species.pattern=="charge" else 10.0
		Model.animate(model,species,1.1,"windup",species.windup,0)
		var loaded := model.transform
		var neck_loaded := neck.transform
		var foot_loaded := sole(model.get_node("Hind1"))
		check(model.position.y< -0.1,"windup compresses center of mass: "+str(species.id))
		check(absf(foot_loaded.y)<0.002,"windup keeps sole grounded")
		Model.animate(model,species,1.1,"active",0,speed)
		check(model.transform.is_equal_approx(loaded) and neck.transform.is_equal_approx(neck_loaded),"full-speed attack begins in loaded pose")
		check(sole(model.get_node("Hind1")).distance_to(foot_loaded)<0.002,"attack start does not pop stance foot")
		var lowest := 100.0
		var maximum := -100.0
		for frame in 40:
			var clock := minf(float(frame)/60,0.65)
			Model.animate(model,species,clock*species.speed*1.2*Model.GAIT_PER_METER,"active",clock,speed)
			lowest = minf(lowest,sole(model.get_node("Hind1")).y)
			maximum = maxf(maximum,model.position.y)
		check(lowest>= -0.002,"attack keeps feet at or above ground")
		check(maximum>0.8 if species.pattern=="leap" else maximum<0,"leap rises while charge holds compression")
		if species.pattern=="leap":
			var arm: Node3D = model.get_node("Forelimb1")
			Model.animate(model,species,0,"windup",species.windup,0)
			var loaded_arm := arm.transform
			var wrist: Node3D = arm.get_node("Wrist")
			var loaded_wrist := wrist.transform
			var finger: Node3D = wrist.get_node("Digit1")
			var loaded_finger := finger.transform
			check(wrist.rotation.x>0.2 and absf(finger.rotation.y)>0.3,"anticipation opens wrist and fans fingers")
			check(absf(arm.rotation.z)>0.4,"leap anticipation spreads front limbs")
			Model.animate(model,species,0,"active",0,speed)
			check(arm.transform.is_equal_approx(loaded_arm),"front limb takeoff joins loaded pose")
			check(wrist.transform.is_equal_approx(loaded_wrist) and finger.transform.is_equal_approx(loaded_finger),"wrist and fingers join takeoff without a snap")
			Model.animate(model,species,0.0,"active",0.30,speed,Callable(),Callable(),true)
			check(arm.rotation.x>0.5,"airborne front limbs reach forward")
			check(wrist.rotation.x< -0.3 and finger.rotation.x< -0.25,"airborne claws close through articulated wrist and fingers")
			var tucked := sole(model.get_node("Hind1"))
			Model.animate(model,species,2.7,"active",0.30,speed,Callable(),Callable(),true)
			check(sole(model.get_node("Hind1")).distance_to(tucked)<0.002,"airborne leg pose does not depend on running gait")
			check(tucked.y>0.35 and tucked.z>0.15,"airborne foot folds up and back")
			Model.animate(model,species,2.7,"active",0.65,speed,Callable(),Callable(),true)
			check(absf(sole(model.get_node("Hind1")).y)<0.002,"feet extend back to landing support")
			check(arm.rotation.length()<0.001,"front limbs settle before recovery")
			check(absf(wrist.rotation.x)<0.001 and absf(finger.rotation.x)<0.001 and absf(finger.rotation.y+0.20)<0.001,"landing returns wrist and fingers to rest")
			Model.animate(model,species,0,"recover",0.50,0)
			check(model.position.y< -float(species.size)*0.02 and arm.rotation.z< -0.25,"recovery keeps a low braced silhouette during flank exposure")
			check(absf(sole(model.get_node("Hind1")).y)<0.002,"extended recovery brace keeps support sole grounded")
		Model.animate(model,species,3.0,"active",0.65,speed)
		var end_body := model.transform
		var end_neck := neck.transform
		var end_foot := sole(model.get_node("Hind1"))
		Model.animate(model,species,3.0,"recover",0,0)
		check(model.transform.is_equal_approx(end_body) and neck.transform.is_equal_approx(end_neck),"recovery joins body and neck without phase snap")
		check(sole(model.get_node("Hind1")).distance_to(end_foot)<0.002,"recovery joins stance foot without pop")
		Model.animate(model,species,3.0,"recover",0.15,0)
		check(model.position.y< -0.05,"recovery absorbs landing or braking")
		check(absf(sole(model.get_node("Hind1")).y)<0.002,"recovery compression keeps actual sole on ground")
		Model.animate(model,species,3.0,"recover",species.recovery,0)
		check(absf(model.position.y)<0.001 and absf(neck.rotation.x)<0.001,"recovery returns body and neck to neutral")
	print("LUNGE_POSE_CHECKS: ",checks," FAILURES: ",failures)
	holder.queue_free()
	await process_frame
	quit(1 if failures else 0)
