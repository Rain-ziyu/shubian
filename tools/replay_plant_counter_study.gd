extends "res://tools/replay_animation_study.gd"
## Scripted pose study: one explicit fixture damage event triggers the counter.
## Monsters are frozen; this is not a live combat or difficulty demonstration.
var study_clock := 0.0
var stage_clock := 0.0
var stage := 0
var beats := 0
var counter_seen := false
func setup() -> void:
	await super.setup()
	fighter.combat.set_action("idle")
	fighter.combat.drawn = true
	fighter.animate(0,0)
	fighter.combat.strike.connect(func(_beat: int):
		if fighter.combat.action=="finisher": beats += 1)
func step() -> void:
	if finished: return
	study_clock += 1.0/60
	stage_clock += 1.0/60
	fighter.combat.advance(1.0/60)
	if stage==0 and stage_clock>=0.4:
		fighter.combat.request("plant")
		stage = 1
	elif stage==1 and fighter.combat.action=="wait":
		stage = 2
		stage_clock = 0
	elif stage==2 and stage_clock>=0.5:
		fighter.combat.request("counter_window")
		stage = 3
	elif stage==3 and fighter.combat.elapsed>=0.20:
		counter_seen = fighter.combat.receive_damage(30)=="counter"
		stage = 4
	elif stage==4 and fighter.combat.action=="idle":
		stage = 5
		stage_clock = 0
	fighter.animate(1.0/60,0)
	title.text = "戍边 / 插枪反制动作研究（预设触发，非实战）\n"+{
		"idle":"准备与收势", "plant":"双手举杆 · 插枪", "wait":"稳住架势 · 等待",
		"counter_window":"反制窗口", "finisher":"旋枪 · 收杆 · 踢击 / 命中节拍：%d / 2" % beats
	}.get(fighter.combat.action,fighter.combat.action)
	if fighter.combat.action=="finisher" and fighter.combat.elapsed>=0.95 and not captured:
		captured = true
		capture_kick.call_deferred()
	if (stage==5 and stage_clock>=0.3) or study_clock>6:
		finished = true
		finish.call_deferred()
func capture_kick() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Shubian-finisher-kick.png"))
func finish() -> void:
	var passed: bool = counter_seen and beats==2 and fighter.combat.health==240 and stage==5
	print("PLANT_COUNTER_STUDY: counter=",counter_seen," beats=",beats," health=",fighter.combat.health," passed=",passed)
	world.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if passed else 1)
