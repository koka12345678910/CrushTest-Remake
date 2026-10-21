extends SceneTree
## tools/build_mage_anims.gd — собирает анимации мага из листов
## Character/Mage_Frost/*.png в два ресурса (как build_sigrid_anims.gd у
## лучницы):
##   Player_scene/mage_frames.tres — SpriteFrames для AnimatedSprite2D
##   Player_scene/mage_anims.tres  — AnimationLibrary для MageAnimations
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/build_mage_anims.gd
## Перезапусти после замены/добавления листов.
##
## Листы: 15 кадров x 8 строк по 128 px, строки — направления по кругу
## (Right, Down_Right, Down, Down_Left, Left, Up_Left, Up, Up_Right).
## В листах Frost-мага в кадры атак вшиты ледяные эффекты — они идут как есть.
##
## Имена клипов — те, что ищет код: база (character_base.gd) — Idle_, Walk_,
## Run_, Backwards_, StrafeLeft_/StrafeRight_, Rolling_, Take_Damage_, Die_,
## Attack_, Run_Attack_; маг (mage.gd) — Attack_2_, Attack_3_, SpecialAttack_.
## Разворота (180Turn) у Frost-мага нет — база тогда поворачивает мгновенно.
## Езда верхом (Ride*) и Slide не берутся.

const SRC := "res://Character/Mage_Frost/"
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
	# ЛКМ — огненный шар: выпад с выбросом руки вперёд (выпуск ~6-й кадр)
	["Attack_", "Attack1", 15.0, false],
	# ПКМ — выжигание: рука вспыхивает и сила срывается с неё (поджиг ~4-й
	# кадр), вокруг проносятся осколки
	["Attack_2_", "Attack5", 15.0, false],
	# V — двойной импульс: тот же лист, что у столпов (Special1) — подъём посоха
	# и выброс силы. Лист Attack2 (вращение с вихрем) пока не используется —
	# его вернём под другой приём
	["Attack_3_", "Special1", 10.0, false],
	# B — столпы: поднимает посох, вокруг вырывается (кадры 9-11)
	["SpecialAttack_", "Special1", 10.0, false],
	["Run_Attack_", "AttackRun", 18.0, false],
	# --- про запас, кодом пока не используются ---
	["Run_Attack_2_", "AttackRun2", 18.0, false],
	["Attack_4_", "Attack4", 15.0, false],
	# Прежний лист выжигания: колдует руками перед собой
	["Cast_", "Attack3", 15.0, false],
	["Attack_6_", "Attack6", 15.0, false],
	["Idle_2_", "Idle2", 8.0, true],
	["Idle_3_", "Idle3", 8.0, true],
	["Idle_4_", "Idle4", 8.0, true],
	["Crouch_Idle_", "CrouchIdle", 10.0, true],
	["Crouch_Run_", "CrouchRun", 15.0, true],
	["Kick_", "Kick", 18.0, false],
	["Taunt_", "Taunt", 12.0, false],
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
			# Пути от корня мага (как у прежних клипов): AnimationPlayer мага
			# смотрит от самого мага, а не от спрайта (у лучницы — наоборот)
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
	var e1 := ResourceSaver.save(sf, "res://Player_scene/mage_frames.tres")
	var e2 := ResourceSaver.save(lib, "res://Player_scene/mage_anims.tres")
	print("mage: clips=", sf.get_animation_names().size(), " atlases=", atlases, " save=", e1, ",", e2)
	quit()
