extends RefCounted
## World-space support during grounded windup turns. Attack clocks and yaw remain owned by AI.
static func group_for(leg: Node3D) -> int:
	return 0 if str(leg.name) in ["Hind-1","Front1"] else 1

static func apply(root: Node3D, data: Dictionary, phase: String, clock: float, delta: float, entries: Array, grounded: bool) -> void:
	var heading: float = root.get_parent().global_rotation.y
	var state: Dictionary = root.get_meta("turn_support",{})
	var previous_heading: float = state.get("heading",heading)
	var eligible := phase=="windup" and grounded and delta>0 and clock>=0.18 and clock<float(data.windup)-0.005
	if not eligible or state.get("phase","")!="windup" or not state.get("eligible",false):
		state = {"heading":heading,"phase":phase,"eligible":eligible,"anchors":{},"active_group":-1,"settle_until":0.0,"age":0.0}
		for entry in entries:
			state.anchors[str(entry.leg.name)] = Transform3D(entry.leg.global_basis*entry.foot_basis,entry.leg.to_global(entry.target))
		root.set_meta("turn_support",state)
		return
	state.heading = heading
	if absf(angle_difference(previous_heading,heading))>0.0001: state.settle_until=clock+0.32
	var desired := {}
	var errors := [0.0,0.0]
	for entry in entries:
		var name: String = str(entry.leg.name)
		var world := Transform3D(entry.leg.global_basis*entry.foot_basis,entry.leg.to_global(entry.target))
		desired[name] = world
		if not state.anchors.has(name): state.anchors[name]=world
		var anchor: Transform3D = state.anchors[name]
		var distance := Vector2(world.origin.x-anchor.origin.x,world.origin.z-anchor.origin.z).length()
		var group := group_for(entry.leg)
		errors[group] = maxf(errors[group],distance)
	if state.active_group<0 and clock<state.settle_until and maxf(errors[0],errors[1])>float(data.size)*0.012:
		state.active_group = 0 if errors[0]>=errors[1] else 1
		state.age = 0.0
		state.duration = minf(0.16,maxf(0.02,float(data.windup)-clock-0.01))
	else: state.age += delta
	var weight := clampf(float(state.age)/float(state.get("duration",0.16)),0,1)
	for entry in entries:
		var name: String = str(entry.leg.name)
		var anchor: Transform3D = state.anchors[name]
		var goal: Transform3D = desired[name]
		if group_for(entry.leg)==state.active_group:
			anchor = anchor.interpolate_with(goal,smoothstep(0,1,weight))
			anchor.origin.y += sin(weight*PI)*float(data.size)*0.035
			if weight>=1: state.anchors[name]=goal
		elif clock>=state.settle_until and state.active_group<0:
			# Resume the ordinary preparation after the turn settles.
			anchor=goal
			state.anchors[name]=goal
		entry.target = entry.leg.to_local(anchor.origin)
		entry.foot_basis = entry.leg.global_basis.inverse()*anchor.basis
	if weight>=1: state.active_group=-1
	root.set_meta("turn_support",state)
