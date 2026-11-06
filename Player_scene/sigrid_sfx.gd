extends RefCounted
## sigrid_sfx.gd — звуки оружия Сигрид: кинжал-сакс и лук (файлы и авторы —
## Sound/sigrid_sfx/, CREDITS.txt). Каждый звук — пул вариантов: подряд один и
## тот же не повторяется, высота каждый раз чуть плавает. Каждое проигрывание —
## свой одноразовый AudioStreamPlayer2D, поэтому звуки не обрывают друг друга
## (натяжение тетивы не глушит шорох колчана, удар — свист замаха).
##
## Файлы грузятся лениво: если какого-то нет (ещё не импортирован), звук просто
## не играет, без ошибок.

const DIR := "res://Sound/sigrid_sfx/"

const POOLS := {
	"dagger_swing": ["dagger_swing_1.wav", "dagger_swing_2.wav", "dagger_swing_3.wav",
			"dagger_swing_b_1.wav", "dagger_swing_b_2.wav", "dagger_swing_b_3.wav"],
	"dagger_hit": ["dagger_hit_1.ogg", "dagger_hit_2.ogg",
			"dagger_hit_cut_1.wav", "dagger_hit_cut_2.wav", "dagger_hit_cut_3.wav"],
	# Сочный удар — три слоя разом: рез клинка (dagger_hit), влажный шлепок по
	# плоти (dagger_flesh) и низкий глухой удар по телу (dagger_body — тот же
	# слой "туши", что у рыцаря, player.gd BODY_IMPACT_SOUNDS, но ниже)
	"dagger_flesh": ["arrow_hit_flesh_1.ogg", "arrow_hit_flesh_2.ogg"],
	"dagger_body": ["res://Sound/melee_sound/hit2.wav"],
	"dagger_block": ["dagger_block_1.wav", "dagger_block_2.wav", "dagger_block_3.wav"],
	"dagger_draw": ["dagger_draw_1.wav", "dagger_draw_2.wav"],
	"dagger_sheathe": ["dagger_sheathe_1.wav", "dagger_sheathe_2.wav"],
	"arrow_grab": ["arrow_grab_1.wav", "arrow_grab_2.wav"],
	"bow_nock": ["bow_nock_1.wav", "bow_nock_2.wav", "bow_nock_3.wav"],
	"bow_draw": ["bow_draw_1.wav", "bow_draw_2.wav", "bow_draw_3.wav", "bow_draw_b_1.wav", "bow_draw_b_2.wav"],
	"bow_release": ["bow_release_1.wav", "bow_release_2.wav", "bow_release_3.wav",
			"bow_release_b_1.wav", "bow_release_b_2.wav"],
	"arrow_fly": ["arrow_fly_1.wav", "arrow_fly_2.wav", "arrow_fly_3.wav"],
	"arrow_hit_flesh": ["arrow_hit_flesh_1.ogg", "arrow_hit_flesh_2.ogg"],
	"arrow_hit_shield": ["arrow_hit_shield_1.ogg", "arrow_hit_shield_2.ogg", "arrow_hit_shield_3.ogg"],
	"arrow_hit_wood": ["arrow_hit_wood_1.ogg", "arrow_hit_wood_2.ogg", "arrow_hit_wood_3.ogg"],
	"arrow_hit_stone": ["arrow_hit_stone_1.ogg"],
	"quiver": ["quiver_1.wav", "quiver_2.wav"],
	"roll": ["roll_cloth_1.ogg", "roll_cloth_2.ogg", "roll_cloth_3.ogg", "roll_cloth_4.ogg"],
}

## Громкость каждого вида (дБ). Файлы нормализованы по пику, поэтому тихие по
## природе звуки (шорохи, свист стрелы) здесь опускаем, удары — громче
const VOLUME := {
	"dagger_swing": -9.0, "dagger_hit": -4.0, "dagger_flesh": -5.0, "dagger_body": -9.0,
	"dagger_block": -7.0,
	"dagger_draw": -9.0, "dagger_sheathe": -10.0,
	"arrow_grab": -11.0, "bow_nock": -10.0, "bow_draw": -9.0, "bow_release": -3.0,
	"arrow_fly": -15.0, "arrow_hit_flesh": -4.0, "arrow_hit_shield": -6.0,
	"arrow_hit_wood": -6.0, "arrow_hit_stone": -7.0,
	"quiver": -12.0, "roll": -13.0,
}

static var _cache := {}
static var _last := {}


static func stream(key: String) -> AudioStream:
	var files: Array = POOLS.get(key, [])
	if files.is_empty():
		return null
	var idx := randi() % files.size()
	if files.size() > 1 and idx == int(_last.get(key, -1)):
		idx = (idx + 1 + randi() % (files.size() - 1)) % files.size()
	_last[key] = idx
	var f: String = files[idx]
	# Чужие файлы проекта (слой тела рыцаря) — полным путём
	var path: String = f if f.begins_with("res://") else DIR + f
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Звук, который едет вместе с узлом (замах — с Сигрид, свист — со стрелой).
## Возвращает плеер (можно оборвать — натяжение при отпускании), или null
static func play_on(owner: Node, key: String, db_offset := 0.0, pitch := 1.0, pitch_var := 0.06) -> AudioStreamPlayer2D:
	var s := stream(key)
	if s == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = s
	p.bus = "Combat"
	p.volume_db = float(VOLUME.get(key, -6.0)) + db_offset
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.finished.connect(p.queue_free)
	owner.add_child(p)
	p.play()
	return p


## Звук в точке мира, независимо от того, кто его вызвал (стрела после
## попадания исчезает — звук должен доиграть)
static func play_at(tree: SceneTree, key: String, at: Vector2, db_offset := 0.0, pitch := 1.0, pitch_var := 0.08) -> void:
	var s := stream(key)
	var scene := tree.current_scene if tree else null
	if s == null or scene == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = s
	p.bus = "Combat"
	p.volume_db = float(VOLUME.get(key, -6.0)) + db_offset
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.global_position = at
	p.play()
