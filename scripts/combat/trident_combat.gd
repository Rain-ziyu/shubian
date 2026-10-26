extends RefCounted
## Authoritative combat clock, independent of presentation and input devices.
signal action_changed(action: String)
signal strike(beat: int)
signal buffer_rejected(action: String)
const THROW_HOLD_TIME := 0.45

const MOVES := {
	"light": {"duration": 0.66, "hits": [0.25], "chain": 0.37, "damage": 26.0, "reach": 3.1},
	"heavy": {"duration": 0.92, "hits": [0.43], "chain": 0.57, "damage": 42.0, "reach": 3.3},
	"pull": {"duration": 0.86, "hits": [0.40], "chain": 0.55, "damage": 20.0, "reach": 3.5},
	"turn": {"duration": 0.95, "hits": [0.44], "chain": 0.60, "damage": 32.0, "reach": 3.2},
	"guard": {"duration": 1.4, "hits": [], "chain": 1.4, "damage": 0.0, "reach": 0.0},
	"reply": {"duration": 0.82, "hits": [0.20], "contact_window": 0.28, "chain": 0.54, "damage": 30.0, "reach": 3.3},
	"flash": {"duration": 0.58, "hits": [0.23], "chain": 0.39, "damage": 52.0, "reach": 3.8},
	"throw": {"duration": 0.80, "hits": [0.38], "chain": 0.80, "damage": 36.0, "reach": 16.0},
	"fourfold": {"duration": 1.25, "hits": [0.18, 0.43, 0.68, 0.93], "chain": 1.02, "damage": 22.0, "reach": 3.2},
	"spin": {"duration": 1.35, "hits": [0.38, 0.85], "chain": 1.08, "damage": 45.0, "reach": 4.0},
	"plant": {"duration": 0.65, "hits": [], "chain": 0.65, "damage": 0.0, "reach": 0.0},
	"wait": {"duration": 30.0, "hits": [], "chain": 30.0, "damage": 0.0, "reach": 0.0},
	"counter_window": {"duration": 0.5, "hits": [], "chain": 0.5, "damage": 0.0, "reach": 0.0},
	"finisher": {"duration": 1.45, "hits": [0.43, 0.95], "chain": 1.45, "damage": 95.0, "reach": 4.0},
	"dodge": {"duration": 0.55, "hits": [], "chain": 0.55, "damage": 0.0, "reach": 0.0},
	"hurt": {"duration": 0.55, "hits": [], "chain": 0.55, "damage": 0.0, "reach": 0.0}
}
var action := "idle"
var elapsed := 0.0
var beat_index := 0
var drawn := false
var health := 240.0
var stamina := 100.0
var shadow_lifetimes: Array[float] = []
var guard_reward := 0.0
# Historical diagnostic field; playable counters no longer open a flash window.
var flash_window := 0.0
var buffered := ""
var buffer_life := 0.0
var intent_awarded := false

func set_action(next: String) -> void:
	action = next
	elapsed = 0.0
	beat_index = 0
	intent_awarded = false
	buffered = ""
	if next != "idle" and next != "hurt": drawn = true
	action_changed.emit(action)

func request(next: String) -> bool:
	if health <= 0: return false
	if next == "counter_window":
		if action != "wait": return false
		set_action(next)
		return true
	if next == "sheathe":
		if action != "idle": return false
		drawn = false
		return true
	if not MOVES.has(next): return false
	if next == "plant" and not drawn: return false
	if next == "reply" and guard_reward <= 0: return false
	# Flash is retained only as a historical pose clip, not a playable follow-up.
	if next == "flash": return false
	if next in ["wait", "finisher", "hurt"]: return false
	if action != "idle":
		if next == action and next not in ["fourfold", "spin"]: return false
		if action == "guard" and next == "reply" and guard_reward > 0:
			pass
		elif action in ["wait", "plant", "counter_window", "hurt", "dodge", "finisher"]:
			return false
		elif elapsed < float(MOVES[action].chain):
			# Only buffer close to a legal link; do not queue through a whole move.
			if float(MOVES[action].chain) - elapsed <= 0.18:
				buffered = next
				buffer_life = 0.20
			return false
	if next in ["fourfold", "spin"]:
		if shadow_lifetimes.is_empty(): return false
		shadow_lifetimes.pop_front()
	if next == "dodge":
		if stamina < 28: return false
		stamina -= 28
	if next == "reply": guard_reward = 0.0
	if next == "flash": flash_window = 0.0
	set_action(next)
	return true

func advance(delta: float) -> void:
	guard_reward = maxf(0, guard_reward - delta)
	flash_window = maxf(0, flash_window - delta)
	var recovery := 18.0 if action=="idle" else (0.0 if action=="guard" else 6.0)
	stamina = minf(100, stamina + delta*recovery)
	for i in range(shadow_lifetimes.size() - 1, -1, -1):
		shadow_lifetimes[i] -= delta
		if shadow_lifetimes[i] <= 0: shadow_lifetimes.remove_at(i)
	if action == "idle": return
	var current := action
	elapsed += delta
	var data: Dictionary = MOVES[action]
	while beat_index < data.hits.size() and elapsed >= float(data.hits[beat_index]):
		var beat := beat_index
		beat_index += 1
		strike.emit(beat)
		if action != current: return
	if buffered != "":
		buffer_life -= delta
		var next := buffered
		if elapsed >= float(data.chain):
			buffered = ""
			if request(next): return
			buffer_rejected.emit(next)
		elif buffer_life <= 0: buffered = ""
	if elapsed >= float(data.duration):
		set_action("wait" if current == "plant" else "idle")

func receive_damage(amount: float, blockable := true, in_front := true, interrupt := true) -> String:
	if health <= 0: return "dead"
	if action == "counter_window":
		set_action("finisher")
		return "counter"
	if action == "reply" and elapsed <= 0.42: return "immune"
	if action == "dodge" and elapsed >= 0.06 and elapsed <= 0.32: return "immune"
	if action == "guard" and elapsed >= 0.12 and blockable and in_front and stamina >= 15:
		stamina -= 15
		guard_reward = 0.8
		return "guarded"
	health = maxf(0, health - amount)
	if action == "spin" and health > 0: return "armored"
	if not interrupt and health>0: return "ongoing"
	set_action("hurt")
	guard_reward = 0
	flash_window = 0
	return "hurt"

func confirm_hit() -> void:
	if action == "reply" and not intent_awarded:
		intent_awarded = true
		if shadow_lifetimes.size() == 5: shadow_lifetimes.pop_front()
		shadow_lifetimes.append(180.0)

func damage() -> float:
	return float(MOVES.get(action, {}).get("damage", 0.0)) * (1.0 + shadow_lifetimes.size() * 0.10)
