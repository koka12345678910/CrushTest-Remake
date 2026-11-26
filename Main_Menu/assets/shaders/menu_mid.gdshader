shader_type canvas_item;

// Горы главного меню (bg_mid.png): резкость и локальный контраст.
// Слой ~1670 px растягивается на экран, и мелкая детализация — лес на
// склонах, скальные выходы, гребни — расплывалась: горы выглядели мыльными.
//   - sharpen: нерезкая маска на 1 пиксель — возвращает мелкую детализацию;
//   - clarity: контраст на радиусе в несколько пикселей — склоны и гребни
//     снова читаются объёмом, а не ровной заливкой;
//   - у края хребта (рядом прозрачное небо) резкость гасится — иначе по
//     линии гор пошла бы тёмная/светлая кайма.
// Дальние хребты (выше) обрабатываются слабее — там дымка нужна для глубины.

// Воздушная перспектива: дальние хребты (верх слоя) растворяются в дымке
// у горизонта того же цвета, что небо за ними (menu_sky: horizon_haze).
// Без этого светлые резкие гребни на тёмном небе выглядели вклеенными
uniform vec3 haze_color : source_color = vec3(0.3, 0.35, 0.4);
uniform float haze_far = 0.55;
// Где кончаются дальние хребты и начинаются ближние склоны (доли высоты)
uniform float haze_top = 0.34;
uniform float haze_bottom = 0.62;
uniform float sharpen : hint_range(0.0, 3.0) = 1.1;
uniform float clarity : hint_range(0.0, 1.5) = 0.35;
// Радиус «ясности» в пикселях текстуры
uniform float clarity_px = 4.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);

	// Ближнее размытие (крест на 1 px)
	vec4 n1 = texture(TEXTURE, UV + vec2(px.x, 0.0));
	vec4 n2 = texture(TEXTURE, UV - vec2(px.x, 0.0));
	vec4 n3 = texture(TEXTURE, UV + vec2(0.0, px.y));
	vec4 n4 = texture(TEXTURE, UV - vec2(0.0, px.y));
	vec3 near_blur = (n1.rgb + n2.rgb + n3.rgb + n4.rgb) * 0.25;

	// Широкое размытие (8 точек на радиусе clarity_px)
	vec2 r = px * clarity_px;
	vec4 w1 = texture(TEXTURE, UV + vec2(r.x, 0.0));
	vec4 w2 = texture(TEXTURE, UV - vec2(r.x, 0.0));
	vec4 w3 = texture(TEXTURE, UV + vec2(0.0, r.y));
	vec4 w4 = texture(TEXTURE, UV - vec2(0.0, r.y));
	vec4 w5 = texture(TEXTURE, UV + r * 0.7);
	vec4 w6 = texture(TEXTURE, UV - r * 0.7);
	vec4 w7 = texture(TEXTURE, UV + vec2(r.x, -r.y) * 0.7);
	vec4 w8 = texture(TEXTURE, UV + vec2(-r.x, r.y) * 0.7);
	vec3 wide_blur = (w1.rgb + w2.rgb + w3.rgb + w4.rgb + w5.rgb + w6.rgb + w7.rgb + w8.rgb) * 0.125;

	// У края хребта соседи прозрачные — там не трогаем
	float a_near = min(min(n1.a, n2.a), min(n3.a, n4.a));
	float a_wide = min(min(min(w1.a, w2.a), min(w3.a, w4.a)), min(min(w5.a, w6.a), min(w7.a, w8.a)));
	float edge_k = smoothstep(0.85, 1.0, a_near);
	float wide_k = smoothstep(0.85, 1.0, a_wide);
	// Дальние хребты (верх слоя) — слабее, ближние склоны (низ) — сильнее
	float depth_k = mix(0.45, 1.0, smoothstep(0.35, 0.75, UV.y));

	vec3 col = c.rgb;
	col += (c.rgb - near_blur) * sharpen * edge_k * depth_k;
	col += (c.rgb - wide_blur) * clarity * wide_k * depth_k;
	// Воздушная перспектива: чем дальше хребет (выше), тем ближе к дымке
	float far = 1.0 - smoothstep(haze_top, haze_bottom, UV.y);
	col = mix(col, haze_color, far * far * haze_far);

	// COLOR на входе уже = текстура × modulate, поэтому не умножаем повторно
	COLOR = vec4(clamp(col, 0.0, 1.0), c.a);
}
