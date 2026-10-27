extends CanvasLayer
const InputKeys = preload("res://scripts/input_keys.gd")
const Feedback = preload("res://scripts/combat_feedback.gd")
const ACTION_NAMES = Feedback.NAMES
const PART_NAMES := {"body":"躯干","head":"头部","tail":"尾部","flank":"侧腹","spine":"背棘"}
var surface: Control
var status: Label
var health_text: Label
var stamina_text: Label
var health: ProgressBar
var stamina: ProgressBar
var shadows: Label
var shadow_bars: Array[ProgressBar] = []
var shadow_times: Array[Label] = []
var context: Label
var help: Label
var target_text: Label
var target_health: ProgressBar
var target_hint: Label
var target_strategy: Label
var notice: Label
var throw_charge: ProgressBar
var throw_charge_text: Label
var action_phase: Label
var action_progress: ProgressBar
var action_event: Label
func text_at(position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("ede9da"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	surface.add_child(label)
	return label
func bar_at(position: Vector2, dimensions: Vector2, maximum: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = position
	bar.max_value = maximum
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size",1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05,0.09,0.08,0.85)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background",background)
	bar.add_theme_stylebox_override("fill",fill)
	surface.add_child(bar)
	bar.size = dimensions
	return bar
func _ready() -> void:
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	health_text = text_at(Vector2(22,16),19)
	health = bar_at(Vector2(22,44),Vector2(248,14),240,Color("bc6e60"))
	stamina_text = text_at(Vector2(22,65),16)
	stamina = bar_at(Vector2(22,89),Vector2(248,9),100,Color("bab67c"))
	shadows = text_at(Vector2(22,109),17)
	for i in 5:
		shadow_bars.append(bar_at(Vector2(22+i*50,138),Vector2(42,8),180,Color("83bdb1")))
		shadow_times.append(text_at(Vector2(22+i*50,152),13))
	status = text_at(Vector2(22,184),17)
	notice = text_at(Vector2(22,238),16)
	context = text_at(Vector2(22,0),20)
	context.anchor_top = 1
	context.anchor_bottom = 1
	context.offset_top = -78
	throw_charge_text = text_at(Vector2(22,0),16)
	throw_charge_text.anchor_top = 1
	throw_charge_text.anchor_bottom = 1
	throw_charge_text.offset_top = -139
	throw_charge = bar_at(Vector2(22,0),Vector2(248,8),1,Color("83bdb1"))
	throw_charge.anchor_top = 1
	throw_charge.anchor_bottom = 1
	throw_charge.offset_top = -109
	throw_charge.offset_bottom = -101
	throw_charge.hide()
	throw_charge_text.hide()
	var hints := text_at(Vector2(22,0),15)
	hints.anchor_top = 1
	hints.anchor_bottom = 1
	hints.offset_top = -34
	hints.text = "WASD 移动  ·  空格闪避  ·  中键锁定 / Tab 切换  ·  F1 操作说明  ·  F5 重试"
	help = text_at(Vector2(22,280),17)
	help.text = "操作说明 · 不暂停战斗\n左键斜刺 / 右键按下横扫\nE 回拉 / Alt+左键转身 / Q 架势 / R 收枪\n斜刺→右键挑斩 / 横扫→左键进步直刺\n回拉→右键下劈 / 闪避末段→左键侧身突刺\n架势内不恢复耐力，每次成功格挡消耗 15\n格挡成功 → 按 Ctrl 右手横扫，命中获得枪意\n有枪意：Ctrl+左键四连刺 / Ctrl+右键旋枪\n拔枪后 Ctrl+空格插地，再按 Ctrl 迎击\nTab 切换目标 / Shift+Tab 反向切换\n锁定跟随 / 鼠标上下调整枪尖高度\nShift 奔跑 / Esc 切换鼠标 / F1 收起说明"
	help.hide()
	target_text = text_at(Vector2.ZERO,17)
	target_text.anchor_left = 0.5
	target_text.anchor_right = 0.5
	target_text.offset_left = -280
	target_text.offset_right = 280
	target_text.offset_top = 18
	target_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_text.offset_bottom = 42
	target_health = bar_at(Vector2.ZERO,Vector2(440,9),1,Color("b49368"))
	target_health.anchor_left = 0.5
	target_health.anchor_right = 0.5
	target_health.offset_left = -220
	target_health.offset_right = 220
	target_health.offset_top = 46
	target_hint = text_at(Vector2.ZERO,16)
	target_hint.anchor_left = 0.5
	target_hint.anchor_right = 0.5
	target_hint.offset_left = -280
	target_hint.offset_right = 280
	target_hint.offset_top = 66
	target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_hint.add_theme_color_override("font_color",Color("e6c57c"))
	# Keep the tall central creature silhouette clear of persistent strategy prose.
	target_strategy = text_at(Vector2.ZERO,14)
	target_strategy.anchor_left = 1
	target_strategy.anchor_right = 1
	target_strategy.offset_left = -322
	target_strategy.offset_right = -22
	target_strategy.offset_top = 78
	target_strategy.offset_bottom = 216
	target_strategy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_strategy.add_theme_color_override("font_color",Color("cecbb9"))
	action_phase = text_at(Vector2.ZERO,19)
	action_phase.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_phase.offset_left = -220
	action_phase.offset_right = 220
	action_phase.offset_top = -126
	action_phase.offset_bottom = -96
	action_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_progress = bar_at(Vector2.ZERO,Vector2(300,6),1,Color("8bbbad"))
	action_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_progress.offset_left = -150
	action_progress.offset_right = 150
	action_progress.offset_top = -92
	action_progress.offset_bottom = -86
	action_event = text_at(Vector2.ZERO,23)
	action_event.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_event.offset_left = -260
	action_event.offset_right = 260
	action_event.offset_top = -172
	action_event.offset_bottom = -135
	action_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and InputKeys.code(event)==KEY_F1:
		help.visible = not help.visible
		get_viewport().set_input_as_handled()
static func can_release_throw(c) -> bool:
	return c.action=="idle" or (c.action not in ["guard","plant","wait","counter_window","hurt","dodge","finisher","throw"] and c.elapsed>=float(c.MOVES[c.action].chain))

static func followup(c, held: float) -> String:
	if c.health<=0: return "任务失败 · F5 重试"
	if c.action=="wait": return "插地等待 %ds · 按 Ctrl 迎击" % ceili(maxf(0,30-c.elapsed))
	if c.action=="counter_window": return "迎击架势 · 接住来袭攻击"
	if c.guard_reward>0: return "格挡成功 · 按 Ctrl 右手横扫"
	if c.action=="reply": return "右手横扫中 · 命中获得一层枪意"
	if c.action=="light": return "衔接右键 · 挑斩"
	if c.action=="heavy": return "衔接左键 · 进步直刺"
	if c.action=="pull": return "衔接右键 · 下劈"
	if c.action=="dodge": return "闪避末段衔接左键 · 侧身突刺"
	if c.action=="guard":
		return "耐力不足 · 收势后走位恢复" if c.stamina<15 else "架势中不恢复耐力 · 格挡成功后按 Ctrl 横扫"
	if not c.drawn: return "背负待机 · 左键或右键拔枪出招"
	if not c.shadow_lifetimes.is_empty(): return "枪意就绪 · Ctrl+左键四连刺 / Ctrl+右键旋枪"
	return "Q 格挡成功 → Ctrl 右手横扫命中获得枪意"
func update_state(fighter, defeated: int) -> void:
	var c = fighter.combat
	var phase: Dictionary = Feedback.phase(c)
	var showing: bool = c.health>0 and defeated<5 and c.action!="idle"
	action_phase.visible = showing
	action_progress.visible = showing
	action_phase.text = str(ACTION_NAMES.get(c.action,""))+" · "+str(phase.text)
	action_phase.add_theme_color_override("font_color",phase.color)
	action_progress.modulate = phase.color
	if showing:
		action_progress.max_value = float(c.MOVES[c.action].duration)
		action_progress.value = c.elapsed
	action_event.text = fighter.feedback.text
	action_event.add_theme_color_override("font_color",fighter.feedback.color)
	action_event.visible = c.health>0 and defeated<5 and fighter.feedback.remaining>0
	throw_charge.hide()
	throw_charge_text.hide()
	health.value = c.health
	stamina.value = c.stamina
	health_text.text = "生命 %d / 240" % ceili(c.health)
	stamina_text.text = "耐力 %d / 100" % floori(c.stamina)
	shadows.text = "枪意 %d / 5" % c.shadow_lifetimes.size()
	if not c.shadow_lifetimes.is_empty(): shadows.text += "  攻击 +%d%%" % (c.shadow_lifetimes.size()*10)
	for i in 5:
		var remaining: float = c.shadow_lifetimes[i] if i<c.shadow_lifetimes.size() else 0
		shadow_bars[i].value = remaining
		shadow_times[i].text = "%d:%02d" % [ceili(remaining)/60,ceili(remaining)%60] if remaining>0 else "—"
	var action: String = ACTION_NAMES.get(c.action,"持枪待机" if c.drawn else "背负待机")
	status.text = "击退 %d / 5\n%s" % [defeated,action]
	if c.health<=0: status.text = "任务失败 · F5 重试"
	elif defeated==5: status.text = "林地已清理 · F5 重新挑战"
	context.text = "林地已清理 · F5 重新挑战" if c.health>0 and defeated==5 else followup(c,fighter.heavy_held)
	notice.text = fighter.message if fighter.message!="观察金色预警后躲避或格挡。" and c.health>0 else ""
	for part in PART_NAMES: notice.text = notice.text.replace(part,PART_NAMES[part])
	var locked: bool = c.health>0 and is_instance_valid(fighter.lock_target) and fighter.lock_target.health>0
	target_text.visible = locked
	target_health.visible = locked
	target_hint.visible = locked
	target_strategy.visible = locked
	if locked:
		var target = fighter.lock_target
		var trait_text: String = target.data.trait
		var strategy: String = target.data.weakness
		if target.data.id=="mossback" and target.armor_integrity<=0:
			trait_text = "背甲已破 · 正面减伤解除"
			strategy = "绕后追击尾根；正面攻击也已不受重甲减伤"
		target_text.text = "%s  %d / %d" % [target.data.name,ceili(target.health),int(target.data.health)]
		target_strategy.text = "%s\n\n对策：%s" % [trait_text,strategy]
		target_health.max_value = target.data.health
		target_health.value = target.health
		target_hint.text = target.combat_hint()
