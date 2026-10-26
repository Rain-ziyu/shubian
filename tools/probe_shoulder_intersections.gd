extends "res://tests/test_counter_cloth.gd"
## Diagnostic only: completion exit code does not mean the surfaces are clear.
## Shared triangle edges can be counted twice; these are not unique collision points.
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
	for sample in [["heavy",0.18],["heavy",0.43],["heavy",0.60],["guard",0.18],["plant",0.18],["plant",0.34]]:
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
			var faces := surface(cape,p.rig.skinning.skeleton).get_faces()
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
			print("SHOULDER_CROSSING: action=",sample," side=",side," edges=",count," rest_lower=",lower," rest_upper=",upper)
	stage.queue_free()
	await process_frame
	quit()
