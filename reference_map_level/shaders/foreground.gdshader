shader_type canvas_item;
render_mode unshaded;
// Передний план (ветки, листва, верёвки между камерой и героем). Ночной
// CanvasModulate сюда не доходит (unshaded) — цвет задан здесь: почти чёрный
// силуэт и холодная лунная кромка с одной стороны, чтобы читалась форма листвы.
// В овале вокруг центра экрана, где стоит герой, слой прозрачен — героя он не
// закрывает. Узел — reference_map_level/scripts/foreground_layer.gd.

uniform float opacity = 0.78;
// Насколько темнее нарисованного (атлас уже тёмный)
uniform float darkness = 0.6;
uniform vec4 rim_color : source_color = vec4(0.2, 0.24, 0.34, 1.0);
// Сдвиг для кромки, тексели атласа
uniform float rim_px = 3.0;
// Радиусы чистой зоны в долях высоты экрана: внутри r0 — пусто, к r1 — полная
uniform float clear_r0 = 0.13;
uniform float clear_r1 = 0.3;
uniform vec2 clear_center = vec2(0.5, 0.52);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a2 = texture(TEXTURE, UV - vec2(rim_px) * TEXTURE_PIXEL_SIZE).a;
	float rim = clamp(tex.a - a2, 0.0, 1.0);
	vec3 col = tex.rgb * COLOR.rgb * darkness + rim_color.rgb * rim;
	vec2 d = SCREEN_UV - clear_center;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float clear = smoothstep(clear_r0, clear_r1, length(d));
	COLOR = vec4(col, tex.a * COLOR.a * opacity * clear);
}
