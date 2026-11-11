extends CharacterBody2D
## net_puppet.gd — чужой игрок на своём экране («кукла», Net/net.gd).
##
## Внутри — копия спрайта его героя (AnimatedSprite2D со всеми кадрами,
## материалом и масштабом из сцены героя), его тело-коллизия и подпись над
## головой. Ни скриптов героя, ни камеры, ни HUD, ни ввода: кукла ничего не
## решает, только повторяет снимки, которые присылает хозяин 30 раз в секунду
## (плавно, через snap_buffer.gd).
##
## Для врагов кукла — такой же герой: в группе "player", на том же слое тела
## (враг её видит зоной зрения и бьёт хитбоксом), отдаёт те же поля, что враг
## читает у героя (is_attacking, is_rolling, dodge_velocity...). Всё, что враг
## делает С героем — удар, парирование, награда за убийство, лечение от
## союзника, — кукла не применяет к себе, а отправляет хозяину (Net), и
## решает уже его настоящий герой: увернулся ли, заблокировал ли.

const SnapBuffer := preload("res://Net/snap_buffer.gd")

var peer_id := 0
var character_id := ""
var label_text := ""
var sprite: AnimatedSprite2D

# --- Поля, которые враг читает у героя (enemy.gd) — из снимка хозяина ---
var is_attacking := false
var is_rolling := false
var is_dodging := false
var dodge_velocity := Vector2.ZERO
var _dead := false
## Доля здоровья хозяина 0..1 (из снимка) — полоска над головой и выбор цели
## лекарем; max_health — для тех, кто лечит процентом (Росток жизни)
var hp_frac := 1.0
var max_health := 100.0
var _hp_bar: Node2D

var _snaps := SnapBuffer.new()
var _label: Label


static func find_sprite(n: Node) -> AnimatedSprite2D:
	for c in n.get_children():
		if c is AnimatedSprite2D:
			return c
	return null


func setup(id: int, hero: String, text: String) -> void:
	peer_id = id
	character_id = hero
	label_text = text
	name = "NetPuppet_%d" % id


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("net_puppet")
	add_to_group("player")
	if character_id == "archer":
		add_to_group("ranged_player")
	if character_id == "mage" or character_id == "druid":
		add_to_group("caster_player")
	# Тело есть, но само никуда не ходит и ни во что не упирается — его
	# переставляют снимки. Свои удары враги ловят по слою тела героя
	collision_mask = 0
	_build_from_hero()
	_build_label()


## Спрайт и коллизию берём из сцены героя: инстанс не попадает в дерево,
## поэтому его _ready (HUD, камера, инвентарь) не выполняется
func _build_from_hero() -> void:
	var scene := Characters.get_scene(character_id)
	if scene == null:
		return
	var inst := scene.instantiate()
	if inst is CollisionObject2D:
		collision_layer = (inst as CollisionObject2D).collision_layer
	for c in inst.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null:
			var cs := (c as CollisionShape2D).duplicate() as CollisionShape2D
			add_child(cs)
			break
	var src := find_sprite(inst)
	if src != null:
		sprite = src.duplicate() as AnimatedSprite2D
		sprite.name = "AnimatedSprite2D"
		sprite.stop()
		add_child(sprite)
	inst.free()


func _build_label() -> void:
	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 3)
	_label.size = Vector2(160, 12)
	_label.position = Vector2(-80, -52)
	_label.z_index = 20
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_label.material = m
	add_child(_label)
	# Тонкая полоска здоровья под именем — видно, кого лечить
	_hp_bar = _HpBar.new()
	_hp_bar.position = Vector2(0, -38)
	_hp_bar.z_index = 20
	_hp_bar.material = m
	_hp_bar.puppet = self
	add_child(_hp_bar)


class _HpBar extends Node2D:
	var puppet: Node
	var _shown := 1.0

	func _process(delta: float) -> void:
		var want: float = puppet.hp_frac
		_shown = move_toward(_shown, want, delta * 1.5) if _shown > want else want
		queue_redraw()

	func _draw() -> void:
		var w := 26.0
		draw_rect(Rect2(-w * 0.5 - 1, -1, w + 2, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, 0, w * _shown, 2), Color(0.95, 0.85, 0.6, 0.6))
		var col := Color(0.55, 0.85, 0.4) if puppet.hp_frac > 0.35 else Color(0.9, 0.3, 0.25)
		draw_rect(Rect2(-w * 0.5, 0, w * puppet.hp_frac, 2), col)


# ═════════════════ СНИМКИ ═════════════════

## Снимок от хозяина (Net._snapshot): [время, позиция, анимация, кадр,
## отражение, смещение спрайта, масштаб спрайта, поворот, наклон, цвет,
## масштаб героя, флаги, скорость уклона, скорость]
func push(s: Array) -> void:
	if _snaps.push(float(s[0]), s):
		global_position = s[1]
		_apply_look(s)


func _process(_delta: float) -> void:
	var smp := _snaps.sample(1)
	if smp.is_empty():
		return
	global_position = smp[0]
	_apply_look(smp[1])


func _apply_look(s: Array) -> void:
	if sprite != null:
		var anim := StringName(s[2])
		if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
			sprite.animation = anim
		sprite.frame = int(s[3])
		sprite.flip_h = bool(s[4])
		sprite.position = s[5]
		sprite.scale = s[6]
		sprite.rotation = float(s[7])
		sprite.skew = float(s[8])
		sprite.self_modulate = s[9]
	scale = s[10]
	if s.size() > 13:
		var f := int(s[11])
		is_attacking = (f & 1) != 0
		is_rolling = (f & 2) != 0
		is_dodging = (f & 4) != 0
		_set_dead((f & 8) != 0)
		dodge_velocity = s[12]
		velocity = s[13]
	if s.size() > 14:
		hp_frac = float(s[14])


var _alive_layer := 0

## Павший игрок лежит, пока не встанет у костра (Net._respawn_local): враги
## его не видят и не бьют — кукла уходит из группы "player" и гасит слой тела
func _set_dead(dead: bool) -> void:
	if dead == _dead:
		return
	_dead = dead
	if dead:
		_alive_layer = collision_layer
		collision_layer = 0
		remove_from_group("player")
	else:
		collision_layer = _alive_layer
		add_to_group("player")


# ═════════════════ ДЛЯ ВРАГОВ И СОЮЗНИКОВ ═════════════════
# Всё, что делают с героем, уходит его хозяину — решает его настоящий герой

func is_dead() -> bool:
	return _dead


## Враг дотянулся ударом. Попал или нет (перекат, блок, парирование), решит
## хозяин у себя; врагу отвечаем «попал» — как и он видит у себя
func receive_attack(attack_data: Dictionary) -> bool:
	if _dead:
		return false
	Net.hit_player(peer_id, attack_data)
	return true


func receive_parry(posture_damage: float) -> void:
	Net.to_owner(peer_id, "receive_parry", [posture_damage])


func add_skill_points(amount: int) -> void:
	Net.to_owner(peer_id, "add_skill_points", [amount])


func on_enemy_killed(enemy: Node) -> void:
	Net.to_owner(peer_id, "on_enemy_killed", [enemy])


func on_weapon_hit(enemy: Node2D, blocked: bool) -> void:
	Net.to_owner(peer_id, "on_weapon_hit", [enemy, blocked], String(get_meta("hit_element", "")))


func on_execution_of(enemy: Node) -> void:
	Net.to_owner(peer_id, "on_execution_of", [enemy])


## Лечение от союзника (Росток жизни Сольвейг и т.п.)
func heal(amount: float) -> void:
	Net.to_owner(peer_id, "heal", [amount])


## Эхо заклинаний (Net.echo) зовут у заклинателя тряску — у куклы её нет
func shake_camera(_strength: float, _duration := 0.18) -> void:
	pass


## Откуда у героя срываются заклинания — для эха лозы и т.п.
func _hand_point() -> Vector2:
	var dir := Vector2.LEFT if sprite != null and sprite.flip_h else Vector2.RIGHT
	return global_position + Vector2(0, -6) + dir * 8.0
