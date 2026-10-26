extends RefCounted
## Waist-driven anticipation, contact and recovery. These curves never change combat time.
## Key = (seconds, forward/back lean, torso yaw, upper-body fore/aft offset).
# Seconds, height offset, fore/aft offset, yaw offset.
const THROW_WEAPON := [Vector4(0,0,0,0),Vector4(0.20,0.25,0.20,-0.25),Vector4(0.38,0.02,-0.15,0),Vector4(0.60,0,-0.06,0),Vector4(0.80,0,0,0)]
# Seconds, yaw offset, fore/aft offset, unused.
# Settle at the far side before recovery; contact and the chain opening keep their times.
const HEAVY_WEAPON := [Vector4(0,0,0,0),Vector4(0.18,-0.90,0.025,0),Vector4(0.30,-0.90,0.025,0),Vector4(0.43,-0.097826,0,0),Vector4(0.50,0.95,0,0),Vector4(0.61,1.25,0,0),Vector4(0.70,1.25,0,0),Vector4(0.92,0,0,0)]
# Seconds, height offset, fore/aft offset, pitch offset.
const PULL_WEAPON := [Vector4(0,0,0,0),Vector4(0.22,0,-0.12,0.12),Vector4(0.40,0,0.04,0.12),Vector4(0.58,0,0.20,0.12),Vector4(0.86,0,0,0)]
const LIGHT_WEAPON := [Vector4(0,0,0,0),Vector4(0.11,-0.13,0.12,-0.12),Vector4(0.15,-0.13,0.12,-0.12),Vector4(0.25,0,-0.15,0.18),Vector4(0.34,0.02,-0.10,0.27),Vector4(0.48,0.01,-0.03,0.12),Vector4(0.66,0,0,0)]
const FOURFOLD_WEAPON := [Vector4(0,0,0,0),Vector4(0.08,0,0.04,0.06),Vector4(0.18,0,-0.15,0.18),Vector4(0.28,0,0.035,0.06),Vector4(0.33,0,0.04,0.06),Vector4(0.43,0,-0.15,0.18),Vector4(0.53,0,0.035,0.06),Vector4(0.58,0,0.04,0.06),Vector4(0.68,0,-0.15,0.18),Vector4(0.78,0,0.035,0.06),Vector4(0.83,0,0.04,0.06),Vector4(0.93,0,-0.15,0.18),Vector4(1.03,0,0.035,0.06),Vector4(1.25,0,0,0)]
# Complete the staff rotation before the kick extends; retain the first contact heading.
const FINISHER_WEAPON := [Vector4(0,-1.5,0,0),Vector4(0.18,-1.95,0,0),Vector4(0.43,-1.5+0.43/1.45*TAU,0,0),Vector4(0.74,TAU-1.5,0,0),Vector4(1.14,TAU-1.5,0,0),Vector4(1.45,TAU,0,0)]
# Seconds, crouch depth: extend while lifting, drive down, then brace.
const PLANT_STANCE := [Vector4(0,0.09,0,0),Vector4(0.18,0.06,0,0),Vector4(0.48,0.22,0,0),Vector4(0.65,0.18,0,0)]
const KEYS := {
	"light":[Vector4(0,0,0,0),Vector4(0.11,0.06,-0.16,0.06),Vector4(0.15,0.06,-0.16,0.06),Vector4(0.25,-0.16,0.20,-0.075),Vector4(0.30,-0.16,0.20,-0.075),Vector4(0.40,-0.07,0.10,-0.025),Vector4(0.66,0,0,0)],
	"heavy":[Vector4(0,0,0,0),Vector4(0.18,0.05,-0.60,0.085),Vector4(0.30,0.05,-0.60,0.085),Vector4(0.43,-0.12,0.28,-0.075),Vector4(0.61,-0.06,0.65,-0.035),Vector4(0.70,-0.06,0.65,-0.035),Vector4(0.92,0,0,0)],
	"pull":[Vector4(0,0,0,0),Vector4(0.25,-0.08,-0.13,-0.025),Vector4(0.40,-0.035,-0.02,0.025),Vector4(0.56,0.12,0.13,0.09),Vector4(0.86,0,0,0)],
	"guard":[Vector4(0,0,0,0),Vector4(0.18,0.06,-0.35,0.018),Vector4(1.20,0.06,-0.35,0.018),Vector4(1.40,0,0,0)],
	"reply":[Vector4(0,0.06,-0.35,0.018),Vector4(0.10,0.06,-0.45,0.04),Vector4(0.36,-0.10,0.45,-0.05),Vector4(0.48,-0.04,0.70,-0.02),Vector4(0.54,-0.04,0.70,-0.02),Vector4(0.82,0,0,0)],
	"flash":[Vector4(0,0,-0.10,0),Vector4(0.08,0.06,-0.13,0.04),Vector4(0.23,-0.14,0.10,-0.06),Vector4(0.30,-0.10,0.08,-0.045),Vector4(0.39,-0.06,0.03,-0.02),Vector4(0.58,0,0,0)],
	"plant":[Vector4(0,0,0,0),Vector4(0.18,0.06,0,0.015),Vector4(0.30,-0.20,0,-0.025),Vector4(0.48,-0.16,0,-0.02),Vector4(0.55,-0.12,0,-0.015),Vector4(0.65,-0.08,0,0)],
	"finisher":[Vector4(0,0,0,0),Vector4(0.22,-0.08,-0.25,-0.02),Vector4(0.43,-0.08,0.22,-0.02),Vector4(0.67,0.04,-0.10,0.01),Vector4(0.95,0.20,-0.12,0.035),Vector4(1.14,0.10,-0.04,0.02),Vector4(1.45,0,0,0)],
	"throw":[Vector4(0,0,0,0),Vector4(0.20,0.09,-0.23,0.06),Vector4(0.38,-0.15,0.20,-0.07),Vector4(0.80,0,0,0)],
	"hurt":[Vector4(0,0,0,0),Vector4(0.08,0.30,-0.12,0.045),Vector4(0.22,0.20,-0.08,0.03),Vector4(0.55,0,0,0)]
}
static func sample(action: String, elapsed: float, gait: float, speed: float) -> Vector4:
	if KEYS.has(action): return interpolate(KEYS[action],elapsed)
	if action in ["wait","counter_window"]: return Vector4(elapsed,-0.08,0,0)
	if action=="fourfold":
		var lean := 0.0
		var twist := 0.0
		for index in 4:
			var pulse := exp(-pow((elapsed-(0.18+index*0.25))/0.09,2))*smoothstep(0,0.07,elapsed)
			lean -= pulse*0.12
			twist += pulse*(0.16 if index%2==0 else -0.16)
		return Vector4(elapsed,lean,twist,lean*0.35)
	if action in ["turn","spin"]:
		var duration := 0.95 if action=="turn" else 1.35
		var weight := sin(clampf(elapsed/duration,0,1)*PI)
		return Vector4(elapsed,-0.06*weight,sin(elapsed/duration*TAU-0.8)*0.28*weight,-0.015*weight)
	if action=="dodge":
		var weight := sin(clampf(elapsed/0.55,0,1)*PI)
		return Vector4(elapsed,-0.23*weight,0,-0.03*weight)
	return Vector4(elapsed,-minf(speed,6.3)*0.008,sin(gait)*minf(speed,4.5)*0.008,0)

static func turn_progress(action: String, elapsed: float) -> float:
	if action=="turn": return smoothstep(0.10,0.58,elapsed)
	if action=="spin": return smoothstep(0.08,1.08,elapsed)
	if action=="finisher": return (interpolate(FINISHER_WEAPON,minf(elapsed,0.74)).y+1.5)/TAU
	return 0.0

static func sweep_foot_yaw(side: int, elapsed: float) -> float:
	# Open after the stance lands, then turn the rear support into the sweep.
	var drive := smoothstep(0.30,0.50,elapsed)*(1-smoothstep(0.70,0.92,elapsed))
	return (0.16 if side==-1 else 0.42)*drive

static func counter_foot_yaw(side: int, elapsed: float) -> float:
	var drive := smoothstep(0.10,0.36,elapsed)*(1-smoothstep(0.54,0.82,elapsed))
	return (0.12 if side==-1 else 0.34)*drive

static func interpolate(keys: Array, elapsed: float) -> Vector4:
	if elapsed<=float(keys[0].x): return keys[0]
	for index in range(1,keys.size()):
		var a: Vector4 = keys[index-1]
		var b: Vector4 = keys[index]
		if elapsed<=b.x:
			var weight := smoothstep(a.x,b.x,elapsed)
			return a.lerp(b,weight)
	return keys[-1]
