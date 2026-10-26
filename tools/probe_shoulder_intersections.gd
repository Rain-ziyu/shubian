extends "res://tests/test_counter_cloth.gd"
## Diagnostic only: completion exit code does not mean the surfaces are clear.
## Shared triangle edges can be counted twice; these are not unique collision points.
func count_crossing_edges(faces: PackedVector3Array, target: TriangleMesh) -> int:
	var count := 0
	for triangle in range(0,faces.size(),3):
		for edge in 3:
			if not target.intersect_segment(faces[triangle+edge],faces[triangle+(edge+1)%3]).is_empty(): count += 1
	return count

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var p := preload("res://scripts/player.gd").new()
	p.set_physics_process(false)
	stage.add_child(p)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	p.combat.drawn = true
	p.pitch = -0.25
	var rest_only := "--rest" in OS.get_cmdline_user_args()
	if rest_only: p.combat.drawn = false
	var samples := [["heavy",0.18],["heavy",0.43],["heavy",0.60],["guard",0.18],["plant",0.18],["plant",0.34]]
	if "--all" in OS.get_cmdline_user_args():
		samples.clear()
		for spec in [["light",0.66],["heavy",0.92],["pull",0.86],["turn",0.95],["guard",1.40],["reply",0.82],["throw",0.80],["fourfold",1.25],["spin",1.35],["plant",0.65],["finisher",1.45]]:
			for frame in 13: samples.append([spec[0],float(spec[1])*frame/12.0])
	if rest_only: samples = [["bind",0.0],["idle",0.0]]
	var results := []
	var cape_total := 0
	var arm_total := 0
	var affected := 0
	for sample in samples:
		if sample[0]!="bind":
			p.combat.set_action(sample[0])
			p.combat.elapsed = sample[1]
			p.animate(0,0)
		for side in [-1,1]:
			var cape: MeshInstance3D
			var arm: MeshInstance3D
			for binding in p.rig.skinning.bindings:
				if binding.source.name=="RainCape"+str(side): cape = binding.rendered
				if binding.source.name=="UpperArmSurface"+str(side): arm = binding.rendered
			var skin := surface(arm,p.rig.skinning.skeleton)
			var cloth := surface(cape,p.rig.skinning.skeleton)
			var faces := cloth.get_faces()
			var refs: PackedVector3Array = cape.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			assert(faces.size()==refs.size())
			var lower := Vector3.INF
			var upper := -Vector3.INF
			var count := 0
			for tri in range(0,faces.size(),3):
				for edge in 3:
					var a := tri+edge
					var b := tri+(edge+1)%3
					if not skin.intersect_segment(faces[a],faces[b]).is_empty():
						lower = lower.min(refs[a]).min(refs[b])
						upper = upper.max(refs[a]).max(refs[b])
						count += 1
			var reverse := count_crossing_edges(skin.get_faces(),cloth)
			cape_total += count
			arm_total += reverse
			if count>0 or reverse>0: affected += 1
			results.append({"action":sample[0],"time":sample[1],"side":side,"cape_edges":count,"arm_edges":reverse,"rest_lower":[lower.x,lower.y,lower.z] if count else null,"rest_upper":[upper.x,upper.y,upper.z] if count else null})
			print("SHOULDER_CROSSING: action=",sample," side=",side," cape_edges=",count," arm_edges=",reverse," rest_lower=",lower," rest_upper=",upper)
	var report := {"rest_only":rest_only,"scope":"Exact skinned RainCape versus same-side UpperArmSurface triangle edges, neutral aim, direct authored samples. Shared edges may repeat; counts are not unique contacts or penetration depth. Does not cover other body parts, continuous transitions or saved model.","samples":samples.size(),"pairs":results.size(),"affected_pairs":affected,"cape_edge_total":cape_total,"arm_edge_total":arm_total,"results":results}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var path := argument.trim_prefix("--report=")
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file==null:
				printerr("SHOULDER_REPORT_WRITE_FAILED: ",path)
				quit(2)
				return
			file.store_string(JSON.stringify(report,"  "))
			file.close()
			print("SHOULDER_PROBE_REPORT: ",path)
	print("SHOULDER_PROBE_TOTAL: pairs=",results.size()," affected=",affected," cape_edges=",cape_total," arm_edges=",arm_total)
	stage.queue_free()
	await process_frame
	quit(1 if affected>0 and "--require-clear" in OS.get_cmdline_user_args() else 0)
