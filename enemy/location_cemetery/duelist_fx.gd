extends RefCounted
## duelist_fx.gd — эффекты боя скелета-ловкача (skeleton_enemy.gd, combat_fx).
## Только статические функции:
##   const DuelistFx := preload("res://enemy/location_cemetery/duelist_fx.gd")
##
## Те же кирпичики, что у рыцаря (VFX/VFX_scene/knight_fx.gd: дуги клинка,
## рубка сверху, искры, блики), но кромка не тёплая сталь, а бледная
## призрачная бирюза — удар нежити читается иначе, чем удар героя.

const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")

## Кромка дуг и шлейфа — бледная бирюза (холодная, "мёртвая")
const GHOST := Color(0.5, 1.0, 0.86)
const GHOST_CORE := Color(0.82, 1.0, 0.95)
## Грудь и глаза скелета относительно узла (фигура мельче рыцаря)
const CHEST := Vector2(0, -4)
const EYES := Vector2(0, -10)
## Скелет меньше рыцаря — дуги ужаты
const ARC_SCALE := 0.82


## Дуга клинка под взмах: attack — снизу вверх, attack2 — широкий обратный,
## attack3 — рубка сверху, run_attack — удар с разбега. power > 1 — ответ
## после парирования (ярче, с искрами)
static func swing(enemy: Node2D, anim_name: String, facing: Vector2, power := 1.0) -> void:
	if not is_instance_valid(enemy):
		return
	if anim_name == "attack3":
		KnightFx.chop(enemy, facing, 28.0 * ARC_SCALE, 0.13, 1.1 * power, CHEST, GHOST)
		return
	var kind: int = KnightFx.Swing.RISING
	match anim_name:
		"attack2":
			kind = KnightFx.Swing.SWEEP
		"run_attack":
			kind = KnightFx.Swing.RUN
	var p := KnightFx.preset(kind, facing)
	var heavy := kind == KnightFx.Swing.RUN or power > 1.0
	KnightFx.arc(enemy, p.from, p.to, p.radius * ARC_SCALE, p.width, p.dur, p.power * power, CHEST, false, heavy, GHOST)


## Перед ударом в глазницах вспыхивает бирюза — предупреждение, чтобы
## было что читать (успеть парировать / отскочить)
static func eye_glint(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var h := MageFx.holder(enemy.get_tree(), enemy.global_position + EYES, 0.35, 13)
	h.reparent(enemy)
	# Мелко и коротко: блеск глаз, а не светящаяся голова
	MageFx.flash(h, 5.0, 0.18, GHOST_CORE)
	MageFx.light_pulse(h, 16.0, 0.35, 0.22, GHOST)


## Призрачный силуэт на месте ловкача — шлейф рывка и переката. Копия
## текущего кадра, прибавляет свет и гаснет
static func ghost(enemy: Node2D, alpha := 0.32, life := 0.24) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var sp: AnimatedSprite2D = enemy.get_node_or_null("AnimatedSprite2D")
	if sp == null or sp.sprite_frames == null or not sp.sprite_frames.has_animation(sp.animation):
		return
	var g := Sprite2D.new()
	g.texture = sp.sprite_frames.get_frame_texture(sp.animation, sp.frame)
	g.material = MageFx.add_material()
	g.texture_filter = sp.texture_filter
	g.scale = sp.scale
	g.flip_h = sp.flip_h
	g.modulate = Color(GHOST, alpha)
	enemy.get_parent().add_child(g)
	g.global_position = sp.global_position
	# Позади живого ловкача, а не поверх
	g.z_index = enemy.z_index - 1
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, life)
	t.tween_callback(g.queue_free)


## Пыль из-под ног: толчок рывка, начало и конец переката. dir — куда
## движется ловкач (пыль летит назад)
static func dust(enemy: Node2D, dir: Vector2, amount := 5) -> void:
	if not is_instance_valid(enemy):
		return
	var feet := enemy.global_position + Vector2(0, 24) - dir * 4.0
	var h := MageFx.holder(enemy.get_tree(), feet, 0.9, 6)
	MageFx.smoke(h, amount, 7.0, 13.0, 0.55)


## Клинок поднят навстречу удару — блик на лезвии со стороны противника
static func parry_ready(enemy: Node2D, to_foe: Vector2) -> void:
	if not is_instance_valid(enemy):
		return
	var at := enemy.global_position + CHEST + to_foe * 10.0 + Vector2(0, -4)
	var h := MageFx.holder(enemy.get_tree(), at, 0.4, 13)
	var g := KnightFx._glint(h, 34.0, 0.0, 0.18, GHOST_CORE)
	g.rotation = to_foe.angle() + PI * 0.5


## Удар пойман клинком — к обычной вспышке парирования (KnightFx.parry)
## добавляется призрачное кольцо: видно, что парировал именно скелет
static func parry_caught(enemy: Node2D, to_foe: Vector2) -> void:
	if not is_instance_valid(enemy):
		return
	var at := enemy.global_position + CHEST + to_foe * 18.0
	var h := MageFx.holder(enemy.get_tree(), at, 0.6, 13)
	KnightFx._ring(h, 5.0, 34.0, 1.6, 0.26, Color(GHOST, 0.8))
	MageFx.light_pulse(h, 50.0, 1.0, 0.3, GHOST)
