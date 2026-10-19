extends SceneTree
## tools/build_sigrid_anims.gd — собирает анимации лучницы Сигрид из листов
## Character/Archer/Sigrid/*.png в два ресурса:
##   Player_scene/sigrid_frames.tres — SpriteFrames для AnimatedSprite2D
##   Player_scene/sigrid_anims.tres  — AnimationLibrary для ArcherAnimation
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/build_sigrid_anims.gd
##
## Листы: 15 кадров x 8 строк по 128 px, строки — направления по кругу
## (Right, Down_Right, Down, Down_Left, Left, Up_Left, Up, Up_Right).
## Файлы с "_with_Bow" — режим лука (имена клипов без приставки), остальные —
## режим меча (приставка "Sword_", см. archer.gd::_play).

const SRC := "res://Character/Archer/Sigrid/"
const DIRS := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]

## [клип, лист, кадров/с, зациклен, первый кадр, последний кадр]
const CLIPS := [
	# --- лук ---
	["Idle_", "Idle_with_Bow", 5.0, true, 0, 14],
	["Walk_", "Walk_with_Bow", 15.0, true, 0, 14],
	# Бег с луком
	["Run_", "Run_with_Bow", 20.0, true, 0, 14],
	["Backward_", "RunBackwards_with_Bow", 15.0, true, 0, 14],
	["StrafeLeft_", "StrafeLeft_with_Bow", 15.0, true, 0, 14],
	["StrafeRight_", "StrafeRight_with_Bow", 15.0, true, 0, 14],
	["Rolling_", "Rolling_with_Bow", 15.0, false, 0, 14],
	["Take_Damage_", "TakeDamage_with_Bow", 15.0, false, 0, 14],
	["Die_", "Die_with_Bow", 12.0, false, 0, 14],
	["Attack_", "Attack3_with_Bow", 25.0, false, 0, 14],
	["Run_Attack_", "AttackRun2_with_Bow", 25.0, false, 0, 14],
	# Натяжение — кадры 0-8 того же выстрела, растянутые на 2.25с (полное
	# натяжение в archer.gd — 2с), отпускание — кадры 9-14
	["Tension_", "Attack3_with_Bow", 4.0, false, 0, 8],
	["Shot_", "Attack3_with_Bow", 25.0, false, 9, 14],
	["QuickShot_", "Attack3_with_Bow", 30.0, false, 5, 14],
	# --- меч ---
	["Sword_Idle_", "Idle", 5.0, true, 0, 14],
	["Sword_Walk_", "Walk", 15.0, true, 0, 14],
	["Sword_Run_", "Run", 20.0, true, 0, 14],
	["Sword_Backward_", "RunBackwards", 15.0, true, 0, 14],
	["Sword_StrafeLeft_", "StrafeLeft", 15.0, true, 0, 14],
	["Sword_StrafeRight_", "StrafeRight", 15.0, true, 0, 14],
	["Sword_Rolling_", "Rolling", 15.0, false, 0, 14],
	["Sword_Take_Damage_", "TakeDamage", 15.0, false, 0, 14],
	["Sword_Attack_", "Attack1", 25.0, false, 0, 14],
	["Sword_Attack_2_", "Attack6", 20.0, false, 0, 14],
	["Sword_Attack_3_", "Attack4", 25.0, false, 0, 14],
	["Sword_Spin_", "Attack2", 25.0, false, 0, 14],
	["Sword_Lunge_", "Attack5", 25.0, false, 0, 14],
	["Sword_Run_Attack_", "AttackRun", 25.0, false, 0, 14],
]


func _init() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var lib := AnimationLibrary.new()
	var atlas_cache := {}
	var textures := {}
	for c in CLIPS:
		var clip_prefix: String = c[0]
		var sheet: String = c[1]
		var fps: float = c[2]
		var loop: bool = c[3]
		var f0: int = c[4]
		var f1: int = c[5]
		if not textures.has(sheet):
			textures[sheet] = load(SRC + sheet + ".png")
		var tex: Texture2D = textures[sheet]
		for row in DIRS.size():
			var name := StringName(clip_prefix + DIRS[row])
			sf.add_animation(name)
			sf.set_animation_speed(name, fps)
			sf.set_animation_loop(name, loop)
			for f in range(f0, f1 + 1):
				var key := "%s/%d/%d" % [sheet, row, f]
				if not atlas_cache.has(key):
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(f * 128, row * 128, 128, 128)
					atlas_cache[key] = at
				sf.add_frame(name, atlas_cache[key])
			var n := f1 - f0 + 1
			var a := Animation.new()
			a.length = n / fps
			a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			var t := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t, NodePath(".:frame"))
			a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
			for i in n:
				a.track_insert_key(t, i / fps, i)
			var t2 := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t2, NodePath(".:animation"))
			a.value_track_set_update_mode(t2, Animation.UPDATE_DISCRETE)
			a.track_insert_key(t2, 0.0, name)
			lib.add_animation(name, a)
	var e1 := ResourceSaver.save(sf, "res://Player_scene/sigrid_frames.tres")
	var e2 := ResourceSaver.save(lib, "res://Player_scene/sigrid_anims.tres")
	print("sigrid: clips=", sf.get_animation_names().size(), " atlases=", atlas_cache.size(), " save=", e1, ",", e2)
	quit()
