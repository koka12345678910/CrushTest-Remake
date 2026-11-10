extends SceneTree
## tools/build_druid_anims.gd — собирает анимации Сольвейг (друидесса) из
## листов Character/Shaman_20261110_201203/*.png в два ресурса (как
## build_mage_anims.gd у мага):
##   Player_scene/druid_frames.tres — SpriteFrames для AnimatedSprite2D
##   Player_scene/druid_anims.tres  — AnimationLibrary для DruidAnimations
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/build_druid_anims.gd
## Перезапусти после замены/добавления листов.
##
## Листы — тот же формат, что у Frost-мага: 15 кадров x 8 строк по 128 px,
## строки — направления по кругу (Right, Down_Right, Down, Down_Left, Left,
## Up_Left, Up, Up_Right). Зелёные эффекты природы вшиты в кадры атак.
##
## Имена клипов — те, что ищет код: база (character_base.gd) — Idle_, Walk_,
## Run_, Backwards_, StrafeLeft_/StrafeRight_, Rolling_, Take_Damage_, Die_,
## Attack_, Run_Attack_; Сольвейг (druid.gd) — остальные.

const SRC := "res://Character/Shaman_20261110_201203/"
const DIRS := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]

## [клип, лист, кадров/с, зациклен]
const CLIPS := [
	["Idle_", "Idle", 5.0, true],
	["Walk_", "Walk", 15.0, true],
	["Run_", "Run", 15.0, true],
	["Backwards_", "RunBackwards", 15.0, true],
	["StrafeLeft_", "StrafeLeft", 15.0, true],
	["StrafeRight_", "StrafeRight", 15.0, true],
	["Rolling_", "Rolling", 17.0, false],
	["Take_Damage_", "TakeDamage", 15.0, false],
	["Die_", "Die", 12.0, false],
	# ЛКМ — Шип-семя: ладонь вспыхивает зелёным, семя срывается на ~6-м кадре
	["Attack_", "Attack5", 17.0, false],
	["Run_Attack_", "AttackRun", 18.0, false],
	# G — удар посохом (без Роста): размах с зелёным следом, удар на ~7-м кадре
	["Staff_", "Attack1", 16.0, false],
	# ПКМ — Хлёст лозы: замах рукой вперёд, лоза срывается на 8-м кадре
	["Vine_", "Attack6", 16.0, false],
	# V — Шипы из земли: удар посохом в землю, зелёный круг (кадры 8-11)
	["Spikes_", "Attack4", 15.0, false],
	# B — Оковы корней: посох вверх, удар в землю (8), руки ввысь (11-13)
	["Binding_", "Special1", 12.0, false],
	# Q — Целебные споры: посох поднят — благословение
	["Spores_", "Taunt", 14.0, false],
	# F — Росток жизни: посох поднят над головой, сажает росток
	["Sprout_", "Attack3", 15.0, false],
	# X — Кора: приседает, вокруг нарастает кора
	["Bark_", "CrouchIdle", 12.0, false],
	# Ctrl — Тропа мха: скольжение
	["Slide_", "Slide", 18.0, false],
	# Ульта (Гнев леса, финал дерева «Гнев корней») — тот же лист, что Оковы
	["Special_", "Special1", 12.0, false],
	# --- про запас, кодом пока не используются ---
	["Attack_2_", "Attack2", 16.0, false],
	["Kick_", "Kick", 18.0, false],
	["Run_Attack_2_", "AttackRun2", 18.0, false],
	["Idle_2_", "Idle2", 8.0, true],
	["Idle_3_", "Idle3", 8.0, true],
	["Idle_4_", "Idle4", 8.0, true],
	["Crouch_Run_", "CrouchRun", 15.0, true],
]


func _init() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var lib := AnimationLibrary.new()
	var atlases := 0
	for c in CLIPS:
		var clip_prefix: String = c[0]
		var sheet: String = c[1]
		var fps: float = c[2]
		var loop: bool = c[3]
		var tex: Texture2D = load(SRC + sheet + ".png")
		if tex == null:
			push_error("нет листа " + sheet)
			continue
		for row in DIRS.size():
			var name := StringName(clip_prefix + DIRS[row])
			sf.add_animation(name)
			sf.set_animation_speed(name, fps)
			sf.set_animation_loop(name, loop)
			for f in 15:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(f * 128, row * 128, 128, 128)
				sf.add_frame(name, at)
				atlases += 1
			var a := Animation.new()
			a.length = 15.0 / fps
			a.step = 1.0 / fps
			a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			# Пути от корня героя, как у мага
			var t := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t, NodePath("AnimatedSprite2D:frame"))
			a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
			for i in 15:
				a.track_insert_key(t, i / fps, i)
			var t2 := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t2, NodePath("AnimatedSprite2D:animation"))
			a.value_track_set_update_mode(t2, Animation.UPDATE_DISCRETE)
			a.track_insert_key(t2, 0.0, name)
			lib.add_animation(name, a)
	var e1 := ResourceSaver.save(sf, "res://Player_scene/druid_frames.tres")
	var e2 := ResourceSaver.save(lib, "res://Player_scene/druid_anims.tres")
	print("druid: clips=", sf.get_animation_names().size(), " atlases=", atlases, " save=", e1, ",", e2)
	quit()
