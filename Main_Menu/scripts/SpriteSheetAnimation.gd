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
var _origin := Vector2.ZERO
var _frame_size := Vector2(128, 128)
var _columns := 1
var _frames := 1
var _frame_time := 0.1
var _elapsed := 0.0
var _frame := 0


func _ready() -> void:
	# Пиксель-арт (персонажи) и высокое разрешение (лого) одинаково не любят
	# линейную фильтрацию — она либо мылит пиксели, либо смазывает мелкую
	# гравировку на лого
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Один ряд листа — row_y/frame_size берутся из Characters.portrait_region,
## там уже описан нужный ряд (Idle_Down) и размер кадра
func setup(sheet: Texture2D, row_y: float, frame_size: Vector2, frame_time: float) -> void:
	if sheet == null or frame_size.x <= 0.0:
		return
	var columns := maxi(int(sheet.get_width() / frame_size.x), 1)
	_start(sheet, Vector2(0.0, row_y), frame_size, columns, columns, frame_time)


## Сетка columns×rows — кадры идут слева направо, сверху вниз, как в
## TLO_anim.png (мерцающий лого-лист). Размер кадра высчитывается из
## размера листа, а не задаётся руками — сетка всегда ровная
func setup_grid(sheet: Texture2D, columns: int, rows: int, frame_time: float) -> void:
	if sheet == null or columns <= 0 or rows <= 0:
		return
	var frame_size := Vector2(
		sheet.get_width() / float(columns), sheet.get_height() / float(rows))
	_start(sheet, Vector2.ZERO, frame_size, columns, columns * rows, frame_time)


func _start(sheet: Texture2D, origin: Vector2, frame_size: Vector2,
		columns: int, frames: int, frame_time: float) -> void:
	_origin = origin
	_frame_size = frame_size
	_columns = columns
	_frames = frames
	_frame_time = maxf(frame_time, 0.01)
	_frame = 0
	_elapsed = 0.0

	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	texture = _atlas
	_apply_frame()


func _process(delta: float) -> void:
	# Панель/меню не удаляются при закрытии, а просто прячутся — без этой
	# проверки кадры крутились бы вхолостую всё время, даже когда не видно
	if _atlas == null or not is_visible_in_tree():
		return
	_elapsed += delta
	while _elapsed >= _frame_time:
		_elapsed -= _frame_time
		_frame = (_frame + 1) % _frames
		_apply_frame()


func _apply_frame() -> void:
	var col := _frame % _columns
	var row := _frame / _columns
	_atlas.region = Rect2(
		_origin.x + col * _frame_size.x,
		_origin.y + row * _frame_size.y,
		_frame_size.x, _frame_size.y)
