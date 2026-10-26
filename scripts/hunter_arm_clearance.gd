extends RefCounted
## Rotate only the elbow pole around the fixed shoulder-to-hand axis.
const SECTIONS := [Vector2(-0.19,0.025),Vector2(-0.10,0.070),Vector2(0.02,0.120),Vector2(0.23,0.120),Vector2(0.50,0.095),Vector2(0.55,0.090),Vector2(0.75,0.075),Vector2(1.0,0.060)]
const SHAFT_MARGIN := 0.045
static func gap(shoulder: Vector3, elbow: Vector3, start: Vector3, shaft: Vector3, inverse_length: float) -> float:
	var result := INF
	for section in SECTIONS:
		var point: Vector3 = shoulder+(elbow-shoulder)*section.x
		var nearest := start+shaft*clampf((point-start).dot(shaft)*inverse_length,0,1)
		result = minf(result,point.distance_to(nearest)-section.y)
	return result

static func solve(shoulder: Vector3, target: Vector3, preferred: Vector3, height: float, weapon: Transform3D, side: int, previous_elbow: Vector3, delta: float, avoid_shaft := true) -> Vector3:
	if height<0.00001: return preferred
	var axis := (target-shoulder).normalized()
	var middle := (target+shoulder)*0.5
	var start := weapon*Vector3(0,-0.90,0)
	var shaft := weapon*Vector3(0,0.82,0)-start
	var inverse_length := 1.0/maxf(0.000001,shaft.length_squared())
	var seed := preferred
	if delta>0:
		var projected := previous_elbow-middle
		projected -= axis*projected.dot(axis)
		if projected.length_squared()>0.000001:
			seed = projected.normalized().lerp(preferred,1-exp(-12*delta))
			seed = seed.normalized() if seed.length_squared()>0.000001 else preferred
	if not avoid_shaft: return seed
	var initial_gap := gap(shoulder,middle+seed*height,start,shaft,inverse_length)
	if initial_gap>=SHAFT_MARGIN: return seed
	for step in range(1,13):
		var answer := INF
		var answer_sign := 1.0
		for direction in [float(side),float(-side)]:
			var angle: float = direction*step*PI/12
			var bend := seed.rotated(axis,angle)
			var clearance := gap(shoulder,middle+bend*height,start,shaft,inverse_length)
			if clearance<SHAFT_MARGIN: continue
			var lower: float = (step-1)*PI/12
			var upper: float = step*PI/12
			for iteration in 7:
				var midpoint := (lower+upper)*0.5
				var candidate := seed.rotated(axis,direction*midpoint)
				if gap(shoulder,middle+candidate*height,start,shaft,inverse_length)>=SHAFT_MARGIN: upper=midpoint
				else: lower=midpoint
			if upper<answer:
				answer = upper
				answer_sign = direction
		if answer<INF:
			# Avoid a one-frame elbow snap when the safe arc changes sides.
			var amount := minf(answer,8.0*delta) if delta>0 else answer
			return seed.rotated(axis,answer_sign*amount)
	return seed
