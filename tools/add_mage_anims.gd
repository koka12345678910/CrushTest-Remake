extends SceneTree
## tools/add_mage_anims.gd — дописывает в Player_scene/mage.tscn анимации мага
## из листов Character/Mage/*.png, которых в сцене ещё нет (CLIPS ниже).
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/add_mage_anims.gd
##
## Сцена правится КАК ТЕКСТ, а не пересохранением через Godot: проект на 4.7,
## а CLI-движок здесь 4.3 — пересохранение выкинуло бы из .tscn новые поля
## (unique_id и т.п.). Дописывается ровно то же, что делает редактор:
##   - ext_resource на листы;
##   - AtlasTexture на каждый кадр (15 кадров x 8 направлений);
##   - анимации в SpriteFrames узла AnimatedSprite2D;
##   - клипы AnimationPlayer (дорожки frame + animation, как у остальных) и
##     их записи в AnimationLibrary.
## Клип, который уже есть в сцене, пропускается — запускать можно повторно.
##
## Листы: 15 кадров x 8 строк по 128 px, строки — направления по кругу
## (Right, Down_Right, Down, Down_Left, Left, Up_Left, Up, Up_Right).

const SCENE := "res://Player_scene/mage.tscn"
const SRC := "res://Character/Mage/"
const DIRS := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]

## [приставка клипа, лист, кадров/с, зациклен]. Имена — те, что ищет код
## персонажа (character_base.gd): Rolling_ (перекат), Run_Attack_ (удар на
## бегу), StrafeLeft_/StrafeRight_ (стрейф в фокусе), Die_ (смерть). Остальные
## — про запас, под будущие приёмы. SittingChair и Slide* не добавляем нарочно
const CLIPS := [
	["Run_Attack_", "AttackRun", 18.0, false],
	["Block_Start_", "BlockStart", 20.0, false],
	["Block_", "BlockMid", 12.0, true],
	["Crouch_Idle_", "CrouchIdle", 10.0, true],
	["Crouch_Run_", "CrouchRun", 15.0, true],
	["Die_", "Die", 12.0, false],
	["Front_Flip_", "FrontFlip", 18.0, false],
	["Idle_2_", "Idle2", 8.0, true],
	["Kick_", "Kick", 18.0, false],
	["Rolling_", "Rolling", 17.0, false],
	["StrafeLeft_", "StrafeLeft", 15.0, true],
	["StrafeRight_", "StrafeRight", 15.0, true],
	["Unsheath_", "UnSheath", 15.0, false],
]


func _init() -> void:
	var path := ProjectSettings.globalize_path(SCENE)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Не прочитать " + SCENE)
		quit(1)
		return
	var lines := text.split("\n")

	var ext_lines := PackedStringArray()
	var atlas_blocks := PackedStringArray()
	var frame_anims := PackedStringArray()
	var anim_blocks := PackedStringArray()
	var lib_entries := PackedStringArray()
	var added := []
	var counter := 0
	for c in CLIPS:
		var prefix: String = c[0]
		var sheet: String = c[1]
		var fps: float = c[2]
		var loop: bool = c[3]
		if text.contains("&\"%sDown\"" % prefix):
			print("уже есть: ", prefix)
			continue
		if not FileAccess.file_exists(SRC + sheet + ".png"):
			push_error("нет листа " + sheet)
			continue
		var ext_id := "mx_" + sheet
		ext_lines.append("[ext_resource type=\"Texture2D\" path=\"%s%s.png\" id=\"%s\"]" % [SRC, sheet, ext_id])
		for row in DIRS.size():
			var name: String = prefix + DIRS[row]
			var frames := PackedStringArray()
			for f in 15:
				counter += 1
				var atlas_id := "AtlasTexture_mx%04d" % counter
				atlas_blocks.append("[sub_resource type=\"AtlasTexture\" id=\"%s\"]\natlas = ExtResource(\"%s\")\nregion = Rect2(%d, %d, 128, 128)\n" % [atlas_id, ext_id, f * 128, row * 128])
				frames.append("{\n\"duration\": 1.0,\n\"texture\": SubResource(\"%s\")\n}" % atlas_id)
			frame_anims.append("{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %.1f\n}" % [", ".join(frames), "true" if loop else "false", name, fps])

			var anim_id := "Animation_mx%04d" % counter
			var times := PackedStringArray()
			var ones := PackedStringArray()
			var values := PackedStringArray()
			for f in 15:
				times.append(_num(f / fps))
				ones.append("1")
				values.append(str(f))
			var b := "[sub_resource type=\"Animation\" id=\"%s\"]\n" % anim_id
			b += "length = %s\n" % _num(15.0 / fps)
			if loop:
				b += "loop_mode = 1\n"
			b += "step = %s\n" % _num(1.0 / fps)
			b += "tracks/0/type = \"value\"\ntracks/0/imported = false\ntracks/0/enabled = true\n"
			b += "tracks/0/path = NodePath(\"AnimatedSprite2D:frame\")\ntracks/0/interp = 1\ntracks/0/loop_wrap = true\n"
			b += "tracks/0/keys = {\n\"times\": PackedFloat32Array(%s),\n\"transitions\": PackedFloat32Array(%s),\n\"update\": 1,\n\"values\": [%s]\n}\n" % [", ".join(times), ", ".join(ones), ", ".join(values)]
			b += "tracks/1/type = \"value\"\ntracks/1/imported = false\ntracks/1/enabled = true\n"
			b += "tracks/1/path = NodePath(\"AnimatedSprite2D:animation\")\ntracks/1/interp = 1\ntracks/1/loop_wrap = true\n"
			b += "tracks/1/keys = {\n\"times\": PackedFloat32Array(0),\n\"transitions\": PackedFloat32Array(1),\n\"update\": 1,\n\"values\": [&\"%s\"]\n}\n" % name
			anim_blocks.append(b)
			lib_entries.append("&\"%s\": SubResource(\"%s\")" % [name, anim_id])
		added.append(prefix)

	if added.is_empty():
		print("Добавлять нечего")
		quit()
		return

	# Точки вставки в тексте сцены
	var last_ext := -1
	var sf_start := -1
	var first_anim := -1
	var lib_start := -1
	for i in lines.size():
		var l: String = lines[i]
		if l.begins_with("[ext_resource"):
			last_ext = i
		elif l.begins_with("[sub_resource type=\"SpriteFrames\"") and sf_start < 0:
			sf_start = i
		elif l.begins_with("[sub_resource type=\"Animation\"") and first_anim < 0:
			first_anim = i
		elif l.begins_with("[sub_resource type=\"AnimationLibrary\""):
			lib_start = i
	# Конец массива анимаций SpriteFrames — последняя строка "}]" блока
	var sf_end := -1
	for i in range(sf_start + 1, lines.size()):
		if lines[i].begins_with("["):
			break
		if lines[i] == "}]":
			sf_end = i
	# Конец словаря библиотеки клипов — первая строка "}" после её начала
	var lib_end := -1
	for i in range(lib_start + 1, lines.size()):
		if lines[i] == "}":
			lib_end = i
			break
	if last_ext < 0 or sf_start < 0 or sf_end < 0 or first_anim < 0 or lib_start < 0 or lib_end < 0:
		push_error("Не нашёл точки вставки: ext=%d sf=%d..%d anim=%d lib=%d..%d" % [last_ext, sf_start, sf_end, first_anim, lib_start, lib_end])
		quit(1)
		return

	# Вставляем с конца файла к началу, чтобы индексы выше не съезжали
	var out := Array(lines)
	# У последней записи словаря запятой нет — дописываем её, новые идут через ","
	out[lib_end - 1] = String(out[lib_end - 1]) + ","
	out.insert(lib_end, ",\n".join(lib_entries))
	out.insert(lib_start, "\n".join(anim_blocks))
	out[sf_end] = "}, " + ", ".join(frame_anims) + "]"
	out.insert(sf_start, "\n".join(atlas_blocks))
	out.insert(last_ext + 1, "\n".join(ext_lines))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(out)))
	f.close()
	print("Добавлено: ", added, " кадров: ", counter)
	quit()


## Число так, как его пишет Godot в .tscn (без лишних нулей)
func _num(v: float) -> String:
	var s := "%.8f" % v
	s = s.rstrip("0")
	if s.ends_with("."):
		s += "0"
	return s
