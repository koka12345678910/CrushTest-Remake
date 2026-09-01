extends "res://Main_Menu/scripts/MenuPanel.gd"
## CharacterSelectPanel.gd — выбор персонажа при создании нового прохождения.
##
## Список карточек берётся из реестра Characters, а не задан здесь: добавишь
## четвёртого героя в Characters.DATA/ORDER — карточка появится сама, ширина
## поделится поровну (карточки растягиваются по size_flags).
##
## Панель НИЧЕГО не сохраняет — только сообщает выбор сигналом. Слот заводит
## MainMenu.gd через SaveManager.create_slot(), и именно там character_id
## записывается в сейв один-единственный раз.

signal character_chosen(id: String)

var _selected_id := ""
var _cards := {}          # id -> PanelContainer
var _start_btn: Button


func _get_title() -> String:
	return "ВЫБОР ГЕРОЯ"


func open() -> void:
	# Каждое открытие начинаем с чистого листа: выбор прошлого раза мог быть
	# отменён кнопкой "назад", и подсвечивать его как актуальный — враньё
	_selected_id = ""
	super.open()


func _build_content(parent: VBoxContainer) -> void:
	_cards.clear()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	for id in Characters.ORDER:
		var card := _build_card(id)
		row.add_child(card)
		_cards[id] = card

	_add_rule(parent, 18)

	# Предупреждение о необратимости — главное, что игрок должен понять на этом
	# экране: сменить героя внутри сейва потом будет нельзя
	var warn := _make_label(
		"Герой выбирается один раз и на всё прохождение. Сменить его можно только в новом сохранении.",
		20, COLOR_DIM)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(warn)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 64)
	parent.add_child(buttons)

	_start_btn = _make_text_button("НАЧАТЬ ПУТЬ", 30)
	_start_btn.pressed.connect(_on_start)
	buttons.add_child(_start_btn)

	var back := _make_text_button("НАЗАД", 30)
	back.pressed.connect(func(): _play(SOUND_CHOICE); close())
	buttons.add_child(back)

	_refresh_selection()


func _build_card(id: String) -> PanelContainer:
	var data := Characters.get_data(id)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent): _on_card_input(ev, id))
	card.mouse_entered.connect(func(): _on_card_hover(id, true))
	card.mouse_exited.connect(func(): _on_card_hover(id, false))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	# --- Портрет ---
	# Портрет забирает себе всю свободную высоту карточки (EXPAND_FILL). Иначе
	# он оставался бы 190px, а низ карточки зиял пустотой — на широком экране
	# это самое заметное, что есть на экране выбора
	var portrait := Characters.get_portrait(id)
	if portrait:
		var tex := TextureRect.new()
		tex.texture = portrait
		tex.custom_minimum_size = Vector2(0, 190)
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Персонажи — пиксель-арт: линейная фильтрация мылит их в кашу
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(tex)
	else:
		# Спрайт-лист не найден — держим высоту, чтобы карточки не разъехались
		var stub := Control.new()
		stub.custom_minimum_size = Vector2(0, 190)
		stub.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(stub)

	var name_lbl := _make_label(data.get("name", "?"), 34, Characters.get_color(id))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)

	var tag_lbl := _make_label(data.get("tagline", ""), 21, COLOR_TEXT)
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag_lbl)

	var desc := _make_label(data.get("description", ""), 18, COLOR_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	return card


# state: "normal" / "hover" / "selected"
func _card_style(id: String, state: String) -> StyleBoxFlat:
	var accent := Characters.get_color(id)
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(3)
	s.set_border_width_all(2)
	match state:
		"selected":
			s.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.9)
			s.border_color = accent
			s.set_border_width_all(3)
		"hover":
			s.bg_color = Color(0.12, 0.10, 0.08, 0.75)
			s.border_color = Color(accent.r, accent.g, accent.b, 0.75)
		_:
			s.bg_color = Color(0.07, 0.065, 0.06, 0.55)
			s.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	return s


func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_id == id:
			# Повторный клик по уже выбранному = подтверждение. Двойной путь к
			# старту (клик по карточке и кнопка внизу) — так привычнее
			_on_start()
			return
		_selected_id = id
		_play(SOUND_CHOICE)
		_refresh_selection()


func _on_card_hover(id: String, entered: bool) -> void:
	if id == _selected_id or not _cards.has(id):
		return
	var card: PanelContainer = _cards[id]
	card.add_theme_stylebox_override("panel", _card_style(id, "hover" if entered else "normal"))


func _refresh_selection() -> void:
	for id in _cards:
		var card: PanelContainer = _cards[id]
		card.add_theme_stylebox_override(
			"panel", _card_style(id, "selected" if id == _selected_id else "normal"))

	if is_instance_valid(_start_btn):
		var ready_to_go := _selected_id != ""
		_start_btn.add_theme_color_override(
			"font_color", COLOR_BRIGHT if ready_to_go else COLOR_DIM)


func _on_start() -> void:
	if _selected_id == "":
		# Ничего не выбрано — отказ должен быть слышен, иначе кнопка выглядит
		# сломанной
		_play(SOUND_DENIED)
		return
	_play(SOUND_ACCEPT)
	character_chosen.emit(_selected_id)
