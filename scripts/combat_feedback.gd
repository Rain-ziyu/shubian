extends RefCounted
## Presentation follows the authoritative clock; it never changes combat timing.
const NAMES := {"light":"斜刺","heavy":"横扫","pull":"钩齿回拉","turn":"转身甩枪","guard":"枪尾架势","reply":"枪尾反击","flash":"闪刺","throw":"投枪","fourfold":"枪意 · 四连刺","spin":"枪意 · 旋枪","plant":"插地蓄势","wait":"插地等待","counter_window":"迎击架势","finisher":"旋枪踢击","dodge":"闪避","hurt":"受击"}
var current := "idle"
var text := ""
var color := Color("bde4d4")
var remaining := 0.0
var priority := 0
var hurt_flash := 0.0
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
func rejected(c, next: String) -> void:
	var reason := "当前动作尚未收势"
	if c.buffered==next: reason = "已预输入"+str(NAMES.get(next,next))+" · 等待衔接"
	elif next in ["fourfold","spin"] and c.shadow_lifetimes.is_empty(): reason = "枪影不足 · 格挡反击后闪刺获取"
	elif next=="dodge" and c.stamina<28: reason = "耐力不足 · 无法闪避"
	elif next=="plant" and not c.drawn: reason = "先拔枪，再插地迎击"
	elif next==c.action: reason = "同一动作不能连发 · 衔接其他动作"
	show_event(reason,Color("e7c88b"),0.8,1)
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
		label = "准备出招"
		if not hits.is_empty():
			for i in hits.size():
				if c.elapsed>=float(hits[i]) and c.elapsed<=float(hits[i])+0.12:
					return {"text":"攻击生效"+(" · 第 %d 段" % (i+1) if hits.size()>1 else ""),"color":Color("f3d58b")}
			if c.elapsed>float(hits[-1])+0.12: label = "收势"
			elif c.elapsed>=float(hits[0]): label = "连击准备"
		if c.elapsed>=float(data.chain): label += " · 可衔接"
	return {"text":label,"color":tint}
