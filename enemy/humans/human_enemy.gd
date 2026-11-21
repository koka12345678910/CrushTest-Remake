extends "res://enemy/enemy.gd"
## human_enemy.gd — общий класс врагов-людей (мечники, копейщики и т.д.).
##
## Вся боевая логика, реакции на удары героев, блок, парирование, стан и
## смерть — в enemy/enemy.gd. Здесь только то, что отличает конкретного врага
## и задаётся в инспекторе его сцены:
##   * какими атаками он бьёт (attack_pool) и в какой момент клипа засчитывается
##     удар у каждой (impact_fractions) — у выпада и у прыжка с рубящим момент
##     попадания разный, одно общее число давало бы урон "по воздуху";
##   * множитель урона по атакам (damage_mults).
##
## Анимации собирает tools/build_enemy_anims.gd. При старте враг проверяет,
## что все клипы, которые может запросить enemy.gd, на месте, — иначе спрайт
## застыл бы посреди боя без видимой причины.

## Атаки, из которых враг выбирает (имена клипов без направления)
@export var attack_pool: PackedStringArray = ["attack", "attack2", "attack3"]
## Доля длины клипа, на которой засчитывается удар. Чего нет — attack_impact_fraction
@export var impact_fractions := {}
## Множитель урона по атакам (1.0 — как attack_damage_min..max)
@export var damage_mults := {}

const REQUIRED_CLIPS := [
	"idle2", "walk", "run", "attack", "attack2", "attack3",
	"take_damage", "stagger", "stagger2", "stagger3",
	"block", "parry", "pummel", "die",
]
const _DIRS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]

var _default_impact := 0.55
var _damage_mult := 1.0


func _ready() -> void:
	super()
	_default_impact = attack_impact_fraction
	_check_clips()


func _pick_attack_anim() -> String:
	var pool: PackedStringArray = attack_pool if not attack_pool.is_empty() else PackedStringArray(["attack"])
	var pick: String = pool[randi() % pool.size()]
	attack_impact_fraction = float(impact_fractions.get(pick, _default_impact))
	_damage_mult = float(damage_mults.get(pick, 1.0))
	return pick


func get_attack_damage() -> int:
	return maxi(1, roundi(super() * _damage_mult))


func _check_clips() -> void:
	var player_node := get_node_or_null("EnemyAnim") as AnimationPlayer
	if player_node == null:
		return
	var missing: PackedStringArray = []
	for c in REQUIRED_CLIPS:
		for d in _DIRS:
			if not player_node.has_animation(c + "_" + d):
				missing.append(c)
				break
	if not missing.is_empty():
		push_warning("[%s] нет анимаций: %s — пересоберите tools/build_enemy_anims.gd" % [scene_file_path.get_file(), ", ".join(missing)])
