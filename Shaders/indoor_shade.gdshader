shader_type canvas_item;
render_mode unshaded;
// Затемнение "улицы", пока игрок внутри дома (Levels/house_interior.gd).
// Рисуется большим полигоном поверх всего мира; в прямоугольниках комнат
// (мировые координаты) — прозрачная "дыра" с мягким краем, так что сам
// интерьер и игрок в нём остаются светлыми, а всё снаружи уходит в темноту.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shade_color : source_color = vec4(0.0, 0.0, 0.015, 1.0);
// Комнаты: xy — левый верхний угол, zw — размер. Используются первые rect_count
uniform vec4 rect0;
uniform vec4 rect1;
uniform vec4 rect2;
uniform vec4 rect3;
uniform int rect_count = 0;
// Ширина мягкого перехода на границе комнаты, px мира
uniform float feather = 10.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Расстояние со знаком до прямоугольника: < 0 внутри, > 0 снаружи
float sd_box(vec2 p, vec4 r) {
	vec2 d = abs(p - (r.xy + r.zw * 0.5)) - r.zw * 0.5;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	float d = 1e6;
	if (rect_count > 0) d = min(d, sd_box(world_pos, rect0));
	if (rect_count > 1) d = min(d, sd_box(world_pos, rect1));
	if (rect_count > 2) d = min(d, sd_box(world_pos, rect2));
	if (rect_count > 3) d = min(d, sd_box(world_pos, rect3));
	// Переход центрирован на внешней грани стены: стена чуть притемнена,
	// а трава сразу за ней уже в тени — без светлой "каймы" вокруг дома
	float a = smoothstep(-feather * 0.5, feather * 0.5, d) * amount;
	COLOR = vec4(shade_color.rgb, a);
}
