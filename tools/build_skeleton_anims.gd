extends SceneTree
## tools/build_skeleton_anims.gd — собирает анимации скелетов кладбища из
## листов enemy/location_cemetery/<вид>/*.png. Для каждого вида пишет два
## ресурса рядом с листами:
##   <вид>_frames.tres — SpriteFrames для AnimatedSprite2D
##   <вид>_anims.tres  — AnimationLibrary для EnemyAnim
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/build_skeleton_anims.gd
##
## Листы: 15 кадров x 8 строк по 128 px, строки — направления по кругу
## (Right, Down_Right, Down, Down_Left, Left, Up_Left, Up, Up_Right).
## Имена клипов — те, что ждёт enemy.gd: <действие>_<направление>.
##
## Вместо листа можно дать список: берётся первый существующий. Так у скелета
## с топором (пока нет Idle/Walk/Run/TakeDamage/Die) стоят временные замены —
## положите недостающий лист в папку и перезапустите инструмент.

const ROOT := "res://enemy/location_cemetery/"
const DIRS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]

## Стрейф: строка листа — направление ДВИЖЕНИЯ, лицо повёрнуто на 90°.
## Left/Right у этих листов названы со стороны зрителя (как у Сигрид и мага,
## проверено по кадрам): в StrafeRight лицо = строка + 2, в StrafeLeft —
## строка - 2. Клипы называем по направлению ЛИЦА:
##   strafe_cw_<лицо>  — шаг по часовой (движение = лицо + 2), лист StrafeLeft
##   strafe_ccw_<лицо> — шаг против часовой (движение = лицо - 2), лист StrafeRight
## RunBackwards: строка = направление лица

## [клип, лист или [листы], кадров/с, зациклен, первый кадр, последний кадр, сдвиг строки]
const COMMON := [
	["idle2", "Idle", 8.0, true, 0, 14, 0],
	["walk", "Walk", 15.0, true, 0, 14, 0],
	["run", "Run", 20.0, true, 0, 14, 0],
	["take_damage", "TakeDamage", 20.0, false, 0, 14, 0],
	["stagger", "TakeDamage", 18.0, false, 0, 14, 0],
	["stagger2", "TakeDamage", 15.0, false, 0, 14, 0],
	["stagger3", "TakeDamage", 16.0, false, 2, 14, 0],
	["die", "Die", 15.0, false, 0, 14, 0],
	["pummel", "Kick", 20.0, false, 0, 14, 0],
	["taunt", "Taunt", 12.0, false, 0, 14, 0],
	["roll", "Rolling", 24.0, false, 0, 14, 0],
	["backwards", "RunBackwards", 15.0, true, 0, 14, 0],
	["strafe_cw", "StrafeLeft", 15.0, true, 0, 14, 2],
	["strafe_ccw", "StrafeRight", 15.0, true, 0, 14, -2],
]

const TYPES := {
	# Обычный скелет — «мясо»
	"default_skeleton": [
		["attack", "Attack1", 20.0, false, 0, 14, 0],
		["attack2", "Attack2", 20.0, false, 0, 14, 0],
		["attack3", "Attack4", 20.0, false, 0, 14, 0],
		["block", "CrouchIdle", 8.0, true, 0, 14, 0],
		["parry", "Special1", 22.0, false, 0, 6, 0],
	],
	# Щитовик: блок — щит перед собой (Idle4), парирование — короткий подъём
	# щита, контратака — пинок (pummel из COMMON)
	"skeleton_shield_bag": [
		["attack", "Attack1", 20.0, false, 0, 14, 0],
		["attack2", "Attack4", 20.0, false, 0, 14, 0],
		["attack3", "Attack3", 20.0, false, 0, 14, 0],
		["block", "Idle4", 8.0, true, 0, 14, 0],
		["parry", "Idle4", 24.0, false, 0, 6, 0],
	],
	# Танк с топором (axe_skeleton_2 заменил первый вариант). Все листы
	# развёрнуты как у остальных скелетов — без сдвига строк: проверено
	# попиксельно, каждый лист против ТОГО ЖЕ листа ловкого скелета (стойку
	# Idle2 с атаками сравнивать нельзя — в стойке корпус сам повёрнут, и
	# сравнение "на глаз" давало ложный поворот)
	"axe_skeleton_2": [
		["idle2", "Idle2", 8.0, true, 0, 14, 0],
		["walk", "Walk", 11.0, true, 0, 14, 0],
		["run", "Run", 18.0, true, 0, 14, 0],
		["take_damage", "TakeDamage", 20.0, false, 0, 14, 0],
		["stagger", "TakeDamage", 16.0, false, 0, 14, 0],
		["stagger2", "TakeDamage", 14.0, false, 0, 14, 0],
		["stagger3", "TakeDamage", 16.0, false, 2, 14, 0],
		["die", "Die", 15.0, false, 0, 14, 0],
		["attack", "Attack1", 20.0, false, 0, 14, 0],
		["attack2", "Attack4", 18.0, false, 0, 14, 0],
		["attack3", "Attack2", 20.0, false, 0, 14, 0],
		["run_attack", "AttackRun", 20.0, false, 0, 14, 0],
		["block", "CrouchIdle", 8.0, true, 0, 14, 0],
		["parry", "CrouchIdle", 22.0, false, 0, 6, 0],
		["pummel", ["Kick"], 20.0, false, 0, 14, 0],
	],
	# Ловкий: дерётся как игрок. Парирование собрано как у рыцаря — кадры 0-6
	# листа Special1 (клинок вскинут навстречу удару), блок — удержание
	# конечной позы парирования
	"skeleton_dexterous": [
		["attack", "Attack1", 22.0, false, 0, 14, 0],
		["attack2", "Attack2", 22.0, false, 0, 14, 0],
		["attack3", "Attack4", 22.0, false, 0, 14, 0],
		["run_attack", "AttackRun", 22.0, false, 0, 14, 0],
		["block", "Special1", 4.0, true, 5, 6, 0],
		["parry", "Special1", 22.0, false, 0, 6, 0],
	],
}


func _init() -> void:
	for kind in TYPES:
		_build(kind)
	quit()


func _resolve(kind: String, sheet) -> String:
	var options: Array = sheet if sheet is Array else [sheet]
	for s in options:
		if ResourceLoader.exists(ROOT + kind + "/" + s + ".png"):
			return s
	return ""


func _build(kind: String) -> void:
	# Свои клипы вида перекрывают общие с тем же именем
	var clips := {}
	for c in COMMON:
		clips[c[0]] = c
	for c in TYPES[kind]:
		clips[c[0]] = c

	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var lib := AnimationLibrary.new()
	var atlas_cache := {}
	var textures := {}
	var missing := []
	for clip in clips:
		var c: Array = clips[clip]
		var sheet := _resolve(kind, c[1])
		if sheet == "":
			missing.append(clip)
			continue
		var fps: float = c[2]
		var loop: bool = c[3]
		# Первый кадр может быть списком — тогда это готовая последовательность
		# кадров (туда-обратно, выборка из середины листа и т.п.)
		var frames: Array = c[4] if c[4] is Array else range(c[4], c[5] + 1)
		var row_shift: int = c[6]
		if not textures.has(sheet):
			textures[sheet] = load(ROOT + kind + "/" + sheet + ".png")
		var tex: Texture2D = textures[sheet]
		for d in DIRS.size():
			var row := posmod(d + row_shift, DIRS.size())
			var name := StringName(clip + "_" + DIRS[d])
			sf.add_animation(name)
			sf.set_animation_speed(name, fps)
			sf.set_animation_loop(name, loop)
			for f in frames:
				var key := "%s/%d/%d" % [sheet, row, f]
				if not atlas_cache.has(key):
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(f * 128, row * 128, 128, 128)
					atlas_cache[key] = at
				sf.add_frame(name, atlas_cache[key])
			var n := frames.size()
			var a := Animation.new()
			a.length = n / fps
			a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			var t := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t, NodePath("AnimatedSprite2D:frame"))
			a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
			for i in n:
				a.track_insert_key(t, i / fps, i)
			var t2 := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(t2, NodePath("AnimatedSprite2D:animation"))
			a.value_track_set_update_mode(t2, Animation.UPDATE_DISCRETE)
			a.track_insert_key(t2, 0.0, name)
			lib.add_animation(name, a)
	var base := ROOT + kind + "/" + kind
	var e1 := ResourceSaver.save(sf, base + "_frames.tres")
	var e2 := ResourceSaver.save(lib, base + "_anims.tres")
	print(kind, ": clips=", sf.get_animation_names().size(), " atlases=", atlas_cache.size(),
		" missing=", missing, " save=", e1, ",", e2)
