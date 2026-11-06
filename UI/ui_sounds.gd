extends RefCounted
## ui_sounds.gd — звуки интерфейса всей игры в одном месте: главное меню,
## инвентарь, магазин, древо навыков, костры.
##
## Живые записи без электроники — кожа, ткань, книга, дерево — из Kenney
## RPG Audio (CC0, см. Sound/UI_button/medieval/CREDITS.txt): обрезаны,
## смягчены (срезаны верха), выровнены по громкости. Общая громкость — шина
## "UI": она тише эффектов на BUS_DB и отправляет звук в шину эффектов —
## ползунок «Эффекты» действует и на неё. Шину создаёт GameSettings при
## запуске (ensure_bus).

## Наведение/перемещение по пунктам — тихий шорох кожаного кошеля
const MOVE := preload("res://Sound/UI_button/medieval/move_leather.wav")
## Выбор/подтверждение — книга, положенная на стол
const SELECT := preload("res://Sound/UI_button/medieval/select_book.wav")
## Назад — шорох ткани
const BACK := preload("res://Sound/UI_button/medieval/back_cloth.wav")
## Переключатель, ползунок — деревянный стук
const TOGGLE := preload("res://Sound/UI_button/medieval/toggle_knock.wav")
## Отказ (не хватает денег, Одра, места) — глухой удар двери
const ERROR := preload("res://Sound/UI_button/medieval/error_thud.wav")
## Открыть окно — перевёрнутая страница
const OPEN := preload("res://Sound/UI_button/medieval/open_page.wav")
## Закрыть окно — захлопнутая книга
const CLOSE := preload("res://Sound/UI_button/medieval/close_book.wav")
## Подобран предмет — кожаная сумка на земле
const PICKUP := preload("res://Sound/UI_button/medieval/pickup_pouch.wav")

const BUS := &"UI"
## Отправка — в шину эффектов (GameSettings.BUS_SFX)
const SEND := &"Combat"
## Насколько интерфейс тише полной громкости файла
const BUS_DB := -11.0


static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_volume_db(idx, BUS_DB)
	AudioServer.set_bus_send(idx, SEND if AudioServer.get_bus_index(SEND) >= 0 else &"Master")


## Шина для плеера интерфейса (Master, если UI ещё не создана)
static func bus() -> StringName:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
