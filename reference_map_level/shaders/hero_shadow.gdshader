shader_type canvas_item;
render_mode unshaded;
// Тень героя от источника света (reference_map, scripts/hero_light.gd).
// Рисуется текущий кадр героя, положенный на землю от огня: ноги на месте,
// голова — дальше от огня. У ног тень плотная и резкая, к макушке шире
// размыта и бледнее (полутень, как от настоящего огня). Нарисованная
// художником тень в кадре не участвует.
// Альфа вершины — плотность тени (сколько света даёт этот источник).

// Кадр в атласе (UV): xy — угол, zw — размер
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// Строка ног и высота фигуры — доли кадра
uniform float feet_v = 0.85;
uniform float body_h = 0.45;
// Размытие у макушки, тексели
uniform float blur = 2.6;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.02, 1.0);

varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

float body_a(sampler2D tx, vec2 uv) {
	vec4 c = texture(tx, uv);
	bool baked = c.a < 0.985 && max(c.r, max(c.g, c.b)) < 0.02;
	return baked ? 0.0 : c.a;
}

void fragment() {
	float v = (UV.y - region.y) / max(region.w, 1e-6);
	float t = clamp((feet_v - v) / max(body_h, 1e-3), 0.0, 1.0);
	vec2 px = TEXTURE_PIXEL_SIZE * (0.7 + blur * t);
	float a = body_a(TEXTURE, UV) * 0.2;
	a += (body_a(TEXTURE, UV + vec2(px.x, 0.0)) + body_a(TEXTURE, UV - vec2(px.x, 0.0))
		+ body_a(TEXTURE, UV + vec2(0.0, px.y)) + body_a(TEXTURE, UV - vec2(0.0, px.y))) * 0.12;
	a += (body_a(TEXTURE, UV + px * 1.4) + body_a(TEXTURE, UV - px * 1.4)
		+ body_a(TEXTURE, UV + vec2(px.x, -px.y) * 1.4) + body_a(TEXTURE, UV + vec2(-px.x, px.y) * 1.4)) * 0.08;
	a = clamp(a, 0.0, 1.0);
	// К макушке тень бледнее: свет огибает фигуру
	a *= mix(1.0, 0.45, t);
	COLOR = vec4(tint.rgb, a * v_col.a);
}
