extends RefCounted
## spells.gd — каталог заклинаний рыцаря: имя -> готовое заклинание. Им же
## пользуются лут (находка "благословение") и сохранения (книга заклинаний
## пишется в сейв по именам и восстанавливается отсюда).
##   const Spells := preload("res://Player_scene/magic/spells.gd")
##   var s := Spells.make("Благословение Тора")
##
## Иконки: PNG по пути из "icon" (большие — уменьшаются при загрузке, см.
## _icon). Пока файла нет, рисуется заглушка-круг цвета стихии

const BlessingScript := preload("res://Player_scene/magic/blessing.gd")

const DATA := {
	"Благословение Тора": {
		"element": "lightning",
		"odr_cost": 40.0,
		"duration": 30.0,
		"color": Color(1.0, 0.9, 0.55),
		"icon": "res://blessing_for_warrior/Мифический молот грома в руническом медальоне.png",
		"description": "Молния Тора бьёт в поднятый меч.\n30 сек: удары сильнее бьют по концентрации\nи перескакивают разрядом на соседнего врага.",
		## Предание — для панели находки (Levels/loot/loot_ui.gd)
		"lore": "Тор, сын Одина, — защитник Мидгарда от великанов. Гром — стук колёс его колесницы, молния — след брошенного Мьёльнира, что всегда возвращается в руку хозяина. Воины молились ему перед битвой: тот, кто поднял меч во имя Аса, не боится грозы.",
	},
	"Благословение Сурта": {
		"element": "fire",
		"odr_cost": 35.0,
		"duration": 30.0,
		"color": Color(1.0, 0.55, 0.2),
		"icon": "res://blessing_for_warrior/Раскалённый меч в руническом кольце.png",
		"description": "Огонь Муспельхейма вырывается из-под земли и охватывает клинок.\nОгненное кольцо поджигает и отталкивает тех, кто рядом.\n30 сек: удары поджигают врагов.",
		"lore": "Сурт — огненный великан, страж Муспельхейма. В Рагнарёк он пройдёт по радужному мосту с мечом ярче солнца, и пламя его поглотит все девять миров. Просить у него благословения — значит взять взаймы у самого конца света.",
	},
}

## Иконки рисуются в слоте ~60 px: исходник 1254 px без мипмапов рябил бы
## при уменьшении — поэтому один раз сглаженно ужимаем до ICON_SIZE
const ICON_SIZE := 256

static var _placeholders := {}
static var _icons := {}


static func exists(spell_name: String) -> bool:
	return DATA.has(spell_name)


static func make(spell_name: String) -> Ability:
	if not DATA.has(spell_name):
		return null
	var d: Dictionary = DATA[spell_name]
	var s = BlessingScript.new()
	s.ability_name = spell_name
	s.item_type = "Благословение"
	s.max_count = 1
	s.description = d["description"]
	s.cooldown_duration = 1.5
	s.element = d["element"]
	s.odr_cost = d["odr_cost"]
	s.duration = d["duration"]
	s.color = d["color"]
	s.icon = _icon(spell_name, d)
	return s


static func _icon(spell_name: String, d: Dictionary) -> Texture2D:
	if _icons.has(spell_name):
		return _icons[spell_name]
	if ResourceLoader.exists(d["icon"]):
		var tex: Texture2D = load(d["icon"])
		var img := tex.get_image()
		if img == null or img.get_width() <= ICON_SIZE:
			_icons[spell_name] = tex
			return tex
		if img.is_compressed():
			img.decompress()
		img.resize(ICON_SIZE, ICON_SIZE * img.get_height() / img.get_width(), Image.INTERPOLATE_LANCZOS)
		_icons[spell_name] = ImageTexture.create_from_image(img)
		return _icons[spell_name]
	if not _placeholders.has(spell_name):
		var c: Color = d["color"]
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), c.lightened(0.2), c.darkened(0.45),
				Color(0.55, 0.45, 0.3), Color(0.55, 0.45, 0.3, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_placeholders[spell_name] = t
	return _placeholders[spell_name]
