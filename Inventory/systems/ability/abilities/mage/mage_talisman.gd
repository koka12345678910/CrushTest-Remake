extends Ability
## Общая база талисманов мага. Как у лучницы (huginn_feather_ability.gd):
## пассивный предмет — надевается во вкладке "Талисманы" (TalismanSystem),
## сам эффект живёт в Player_scene/mage.gd и проверяет has_talisman(имя).
##
## Иконка: PNG по пути icon_path — положите файл, подхватится само. Пока
## файла нет, рисуется заглушка-медальон цвета талисмана.

static var _placeholders := {}


func _setup(talisman_name: String, desc: String, icon_path: String, col: Color) -> void:
	ability_name = talisman_name
	item_type = "Талисман  •  пассивный"
	is_passive = true
	max_count = 1
	cooldown_duration = 0.0
	description = desc
	icon = load(icon_path) if ResourceLoader.exists(icon_path) else _placeholder(talisman_name, col)


static func _placeholder(key: String, col: Color) -> Texture2D:
	if not _placeholders.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), col.lightened(0.2), col.darkened(0.45),
				Color(0.55, 0.45, 0.3), Color(0.55, 0.45, 0.3, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_placeholders[key] = t
	return _placeholders[key]
