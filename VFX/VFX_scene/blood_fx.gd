extends RefCounted
## blood_fx.gd — процедурная кровь от ударов (заменила спрайтовую blood_vfx.tscn
## на попаданиях). Только статические функции — подключается как
## const BloodFx := preload("res://VFX/VFX_scene/blood_fx.gd")
##
## Каждый удар — свои брызги (blood_spray.gd): капли летят по настоящей дуге
## с высотой, падают на землю и оставляют пятна (blood_decals.gd), которые
## подсыхают и со временем исчезают. Разные удары брызжут по-разному (Kind),
## а всё остальное — число и размер капель, разброс, струя, туман, форма
## пятен — каждый раз случайное, поэтому двух одинаковых ударов не бывает.

const BloodSpray := preload("res://VFX/VFX_scene/blood_spray.gd")
const BloodDecals := preload("res://VFX/VFX_scene/blood_decals.gd")

## SLASH — рубящий: веер капель, заваленный в одну сторону, часто струя.
## PIERCE — стрела: узкий быстрый конус от стрелка + немного назад из раны.
## BLUNT — тупой: короткий широкий выброс и туман.
## BLAST — магия: брызги во все стороны, кровь темнее (обожжённая), больше тумана.
## DRIP — кровотечение: пара капель просто стекает вниз, без брызг
enum Kind { SLASH, PIERCE, BLUNT, BLAST, DRIP }

## Земля в 3/4 виде: всё, что лежит на ней или движется по ней "вглубь",
## видно короче по вертикали
const DEPTH := 0.62


## victim — раненый, source — кто ударил (от него летят брызги и по нему
## понятно, чем ударили), power — сила (0.5 — царапина, 2+ — смертельный удар)
static func hit(victim: Node2D, source: Node2D = null, power := 1.0, kind := -1) -> void:
	if not is_instance_valid(victim) or not victim.is_inside_tree():
		return
	if kind < 0:
		kind = kind_from(source)
	var dir := Vector2.ZERO
	if is_instance_valid(source) and source != victim:
		dir = source.global_position.direction_to(victim.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var feet := ground_offset(victim)
	var spray: Node2D = BloodSpray.new()
	# Высота раны над землёй — примерно грудь: чуть ниже центра фигуры
	spray.setup(decals(victim.get_tree()), dir, power, kind, maxf(feet.y, 10.0) * randf_range(0.75, 1.1) + 4.0)
	# Позиция — до add_child: _ready брызг уже считает от неё главное пятно
	spray.position = victim.global_position + feet
	_root(victim.get_tree()).add_child(spray)


## Лужа под павшим: растекается пару секунд и сохнет дольше обычных пятен
static func death_pool(victim: Node2D, delay := 0.35) -> void:
	if not is_instance_valid(victim) or not victim.is_inside_tree():
		return
	var tree := victim.get_tree()
	var at := victim.global_position + ground_offset(victim)
	var size := 54.0 * _sprite_scale(victim) * randf_range(0.85, 1.2)
	tree.create_timer(delay).timeout.connect(func():
		decals(tree).pool(at + Vector2(randf_range(-4, 4), randf_range(-2, 2)), size))


## Чем ударили — по тому, кто ударил
static func kind_from(source: Node) -> int:
	if not is_instance_valid(source):
		return Kind.SLASH
	if source.is_in_group("ranged_player"):
		return Kind.PIERCE
	if source.is_in_group("caster_player"):
		return Kind.BLAST
	return Kind.SLASH


## Сила брызг по урону: amount — урон, max_hp — запас здоровья раненого,
## killed — удар добил
static func power_for(amount: float, max_hp: float, killed := false) -> float:
	var p := 0.7 + 1.1 * clampf(amount / maxf(max_hp, 1.0), 0.0, 1.0)
	if killed:
		p += 0.6
	return clampf(p, 0.6, 2.4)


## Узел пятен на текущем уровне — один на сцену, создаётся при первой крови
static func decals(tree: SceneTree) -> Node2D:
	var root := _root(tree)
	var n := root.get_node_or_null("BloodDecals") as Node2D
	if n == null:
		n = BloodDecals.new()
		n.name = "BloodDecals"
		root.add_child(n)
	return n


## Точка под ногами относительно узла персонажа. Все персонажи — 3D-рендеры
## 128x128 с корнем модели в центре кадра, ноги на 27 px кадра ниже центра
## (замерено на маге, см. mage.gd::FEET_PX)
static func ground_offset(victim: Node2D) -> Vector2:
	var spr := _sprite(victim)
	if spr == null:
		return Vector2(0, 16)
	return spr.position + Vector2(0, 27) * spr.scale


static func _sprite(victim: Node2D) -> Node2D:
	for c in victim.get_children():
		if c is AnimatedSprite2D:
			return c
	return null


static func _sprite_scale(victim: Node2D) -> float:
	var spr := _sprite(victim)
	return spr.scale.y / 0.77 if spr else 1.0


static func _root(tree: SceneTree) -> Node:
	return tree.current_scene if tree.current_scene else tree.root
