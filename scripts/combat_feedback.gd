extends RefCounted
## Presentation follows the authoritative clock; it never changes combat timing.
const NAMES := {"rising":"挑斩","advance_thrust":"进步直刺","cleave":"下劈","evade_thrust":"侧身突刺","light":"斜刺","heavy":"横扫","pull":"钩齿回拉","turn":"转身甩枪","guard":"枪尾架势","reply":"右手反击横扫","flash":"闪刺","throw":"投枪","fourfold":"枪意 · 四连刺","spin":"枪意 · 旋枪","plant":"插地蓄势","wait":"插地等待","counter_window":"迎击架势","finisher":"旋枪踢击","dodge":"闪避","hurt":"受击"}
const PART_NAMES := {"head":"头部","body":"躯干","limb":"四肢","flank":"侧腹","tail":"尾部","spine":"背棘"}
var current := "idle"
var text := ""
var color := Color("bde4d4")
var remaining := 0.0
var priority := 0
var hurt_flash := 0.0
func hit_message(result: Dictionary) -> String:
	var part: String = PART_NAMES.get(str(result.get("part","")),"")
	var prefix := "命中 "
	if result.get("armor_just_broken",false): prefix = "破甲 "
	elif result.get("weak",false): prefix = "弱点命中 "
	elif result.get("armor_reduced",false): prefix = "重甲减伤 "
	var text: String = prefix+str(roundi(float(result.get("damage",0))))
	return text+(" · "+part if not part.is_empty() else "")
func advance(delta: float) -> void:
	remaining = maxf(0,remaining-delta)
	hurt_flash = maxf(0,hurt_flash-delta)
	if remaining==0:
		text = ""
		priority = 0
func show_event(value: String, tint := Color("bde4d4"), seconds := 0.65, importance := 0) -> void:
	if remaining>0 and importance<priority: return
	text = value
	color = tint
	remaining = seconds
	priority = importance
func action_changed(next: String) -> void:
	var previous := current
	current = next
	if next=="hurt":
		hurt_flash = 0.22
		var value: String = str(NAMES.get(previous,previous))+"被打断" if previous not in ["idle","hurt"] else "受击失衡"
		show_event(value,Color("f0947d"),1.15,3)
	elif next not in ["idle","wait"]:
		if priority<3:
			remaining = 0
			priority = 0
		show_event(NAMES.get(next,next)+"已发动")
func strike_outcome(action: String, landed: bool, shadows := 0) -> void:
	if landed:
		if action=="reply": show_event("反击横扫命中 · 枪意 %d/5" % shadows,Color("f3d58b"),0.8,2)
		elif action=="flash": show_event("闪刺命中 · 枪影 %d/5" % shadows,Color("f3d58b"),0.9,2)
	elif action in ["light","heavy","pull","turn","reply","flash","rising","advance_thrust","cleave","evade_thrust"]:
		var value: String = str(NAMES.get(action,action))+"落空"
		if action=="reply": value += " · 未获得枪意"
		elif action=="flash": value += " · 未获得枪影"
		show_event(value,Color("e7c88b"),0.8,2 if action in ["reply","flash"] else 1)

func rejected(c, next: String) -> String:
	var reason := "当前动作尚未收势"
	if c.buffered==next: reason = "已预输入"+str(NAMES.get(next,next))+" · 等待衔接"
	elif next in ["fourfold","spin"] and c.shadow_lifetimes.is_empty(): reason = "枪意不足 · 格挡成功后按 Ctrl 横扫命中获取"
	elif next=="dodge" and c.stamina<28: reason = "耐力不足 · 无法闪避"
	elif next=="plant" and not c.drawn: reason = "先拔枪，再插地迎击"
	elif next=="reply" and c.guard_reward<=0: reason = "尚未格挡成功 · 无法反击横扫"
	elif next=="flash": reason = "已改为格挡成功后按 Ctrl 横扫"
	elif next==c.action: reason = "同一动作不能连发 · 衔接其他动作"
	show_event(reason,Color("e7c88b"),0.8,1)
	return reason
static func phase(c) -> Dictionary:
	var label := ""
	var tint := Color("8bbbad")
	if c.action=="idle": return {"text":"","color":tint}
	if c.action=="hurt": return {"text":"失衡恢复中","color":Color("f0947d")}
	if c.action=="wait": label = "等待迎击 · 按 Ctrl"
	elif c.action=="counter_window": label = "迎击判定中"
	elif c.action=="guard": label = "架势建立中" if c.elapsed<0.12 else "格挡生效中"
	elif c.action=="dodge": label = "闪避免伤中" if c.elapsed>=0.06 and c.elapsed<=0.32 else "闪避准备" if c.elapsed<0.06 else "闪避收势"
	else:
		var data: Dictionary = c.MOVES[c.action]
		var hits: Array = data.hits
		var active_seconds := float(data.get("contact_window",0.12))
		label = "准备出招"
		if not hits.is_empty():
			for i in hits.size():
				if c.elapsed>=float(hits[i]) and c.elapsed<=float(hits[i])+active_seconds:
					return {"text":"攻击生效"+(" · 第 %d 段" % (i+1) if hits.size()>1 else ""),"color":Color("f3d58b")}
			if c.elapsed>float(hits[-1])+active_seconds: label = "收势"
			elif c.elapsed>=float(hits[0]): label = "连击准备"
		if c.elapsed>=float(data.chain): label += " · 可衔接"
	return {"text":label,"color":tint}
