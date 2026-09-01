extends RefCounted
## Восьмисекторные направления — общий словарь имён для всех персонажей.
##
## Подключается через preload-константу, а НЕ через class_name: глобальные
## классы попадают в кэш только после полного скана проекта редактором, и до
## того парсер валится с "Identifier not declared". preload-путь работает сразу
## и переживает любые перезапуски — так же подключены SettingsPanel в инвентаре
## и панели в главном меню.
##
## Имена секторов ("Down", "Up_Left" и т.д.) — это буквально суффиксы клипов
## анимации: Idle_Down, Attack_Up_Left, Backwards_Right. То есть эта функция
## задаёт контракт именования для ВСЕХ спрайт-листов проекта, и разъехаться
## копиям тут нельзя категорически: разные пороги у рыцаря и лучника означали
## бы, что на одном и том же вводе они смотрят в разные стороны.
##
## Только статические функции, состояния нет — создавать экземпляр незачем.

## Порог по оси: 0.3 вместо 0.5 намеренно расширяет диагонали. С 0.5 диагональ
## занимала бы узкий сектор и на джойстике в неё было бы трудно попасть
const AXIS_THRESHOLD := 0.3


## Вектор -> имя сектора. Пустая строка = вектор в пределах порога по обеим
## осям (почти ноль); вызывающий сам решает, что показывать в этом случае
static func from_vector(vec: Vector2) -> String:
	var dir := ""
	if vec.y < -AXIS_THRESHOLD:
		dir = "Up"
	elif vec.y > AXIS_THRESHOLD:
		dir = "Down"

	if vec.x < -AXIS_THRESHOLD:
		dir = "Left" if dir == "" else dir + "_Left"
	elif vec.x > AXIS_THRESHOLD:
		dir = "Right" if dir == "" else dir + "_Right"

	return dir


## Имя сектора -> единичный вектор. Диагонали нормализованы, поэтому рывок по
## диагонали не оказывается длиннее прямого
static func to_vector(dir: String) -> Vector2:
	match dir:
		"Up": return Vector2.UP
		"Down": return Vector2.DOWN
		"Left": return Vector2.LEFT
		"Right": return Vector2.RIGHT
		"Up_Left": return Vector2(-1, -1).normalized()
		"Up_Right": return Vector2(1, -1).normalized()
		"Down_Left": return Vector2(-1, 1).normalized()
		"Down_Right": return Vector2(1, 1).normalized()
	return Vector2.ZERO
