# res://systems/ability/ability.gd
class_name Ability
extends Resource

@export var ability_name: String = "Unnamed"
@export var icon: Texture2D
@export var cooldown_duration: float = 1.0
@export var description: String = ""
## Строка типа в карточке инвентаря ("Боевой навык", "Талисман" ...). Пусто —
## по-старому "Расходуемое" (все предметы рыцаря)
@export var item_type: String = ""
## Сколько штук можно держать в сумке. 0 — берётся из старой таблицы
## inventory_ui._get_max_count (предметы рыцаря)
@export var max_count: int = 0
## Пассивный предмет (талисманы лучницы): действует, пока лежит в сумке, в
## быстрый слот не кладётся и не тратится
@export var is_passive: bool = false

var _cooldown_timer: float = 0.0

## Иконки предметов (Shop/icons/icons_2/ — 1254 px) рисуются в ячейках по
## 60-120 px, а мипмапов у импорта нет — без уменьшения крупная картинка
## рябит и мылится. Уменьшаем один раз до ICON_SIZE (Lanczos, как иконки
## благословений в Player_scene/magic/spells.gd::_icon) и кешируем по пути:
## предметы создаются десятками (сумка, магазин, лут, сейв)
const ICON_SIZE := 256
## Какую долю ячейки занимает рисунок крупной иконки. В icons_2 рисунок идёт
## до самых краёв кадра (у старых 256-px иконок вокруг был тёмный отступ), и в
## ячейке они выглядели крупнее — оставляем прозрачные поля. Меньше — мельче
const ICON_FILL := 0.75
static var _icon_cache := {}


static func load_icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("[Ability] иконка не найдена: %s" % path)
		return null
	var tex: Texture2D = load(path)
	var img := tex.get_image() if tex else null
	if img == null or img.get_width() <= ICON_SIZE:
		_icon_cache[path] = tex
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var inner := roundi(ICON_SIZE * ICON_FILL)
	img.resize(inner, maxi(1, inner * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	# Рисунок по центру квадрата ICON_SIZE, вокруг — прозрачные поля
	var canvas := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var at := Vector2i((ICON_SIZE - img.get_width()) / 2, (ICON_SIZE - img.get_height()) / 2)
	canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	_icon_cache[path] = ImageTexture.create_from_image(canvas)
	return _icon_cache[path]


func is_ready() -> bool:
	return _cooldown_timer <= 0.0


func get_cooldown_progress() -> float:
	if cooldown_duration <= 0.0:
		return 1.0
	return 1.0 - (_cooldown_timer / cooldown_duration)


func use(player: Node) -> bool:
	if not is_ready():
		return false
	_cooldown_timer = cooldown_duration
	_execute(player)
	return true


# Override in subclasses
func _execute(_player: Node) -> void:
	pass


func tick(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func reset_cooldown() -> void:
	_cooldown_timer = 0.0
