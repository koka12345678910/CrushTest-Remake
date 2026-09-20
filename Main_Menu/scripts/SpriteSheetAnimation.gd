extends TextureRect
## SpriteSheetAnimation.gd
## Проигрывает один ряд спрайт-листа как зацикленную анимацию.
##
## Нужен там, где хочется показать анимацию персонажа вне геймплея (экран
## выбора героя). Инстансить ради этого саму сцену персонажа нельзя: она
## тянет за собой камеру, HUD-слои, коллизии и скрипт, который лезет в
## группу "player" и обрабатывает ввод — в меню это всё лишнее. Поэтому
## крутим кадры руками через AtlasTexture, как и портрет в Characters

var _atlas: AtlasTexture
var _frame_size := Vector2(128, 128)
var _row_y := 0.0
var _frames := 1
var _frame_time := 0.1
var _elapsed := 0.0
var _frame := 0


func _ready() -> void:
	# Персонажи — пиксель-арт: линейная фильтрация мылит их в кашу
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## row_y/frame_size берутся из Characters.portrait_region — там уже описан
## нужный ряд листа (Idle_Down) и размер кадра
func setup(sheet: Texture2D, row_y: float, frame_size: Vector2, frame_time: float) -> void:
	if sheet == null or frame_size.x <= 0.0:
		return
	_row_y = row_y
	_frame_size = frame_size
	_frame_time = maxf(frame_time, 0.01)
	_frames = maxi(int(sheet.get_width() / frame_size.x), 1)
	_frame = 0
	_elapsed = 0.0

	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	texture = _atlas
	_apply_frame()


func _process(delta: float) -> void:
	# Панель не удаляется при закрытии, а просто прячется — без этой проверки
	# кадры крутились бы вхолостую всё время, пока игрок в меню
	if _atlas == null or not is_visible_in_tree():
		return
	_elapsed += delta
	while _elapsed >= _frame_time:
		_elapsed -= _frame_time
		_frame = (_frame + 1) % _frames
		_apply_frame()


func _apply_frame() -> void:
	_atlas.region = Rect2(
		_frame * _frame_size.x, _row_y, _frame_size.x, _frame_size.y)
