shader_type canvas_item;

// Скала с костром (bg_front.png): приглушённая ночь + живой свет огня.
//
// 1. Скала вне света костра темнее и чуть холоднее (dim, cold) — так огонь
//    становится единственным тёплым пятном, а пятно света читается.
// 2. Свет огня — отдельный источник, не только «раскачка» нарисованного:
//    - позиция light_pos чуть пляшет (MainMenu → MenuBackdrop: шум), радиус
//      и сила мерцают вместе с пламенем;
//    - рельеф берётся из самой картинки: яркость соседних пикселей = высота,
//      из перепада — нормаль. Грань камня, повёрнутая к огню, вспыхивает,
//      обратная остаётся в тени; при движении света блики ползут по камням;
//    - вверх (меч) свет уходит дальше, по земле — короче и мягче.
// 3. Нарисованный свет у кольца тоже дышит вместе с огнём (light).

uniform vec2 light_pos = vec2(0.785, 0.65);
// 1 — как нарисовано; 0.7..1.5 — мерцание и вспышки
uniform float light = 1.0;
// Радиус пятна света в долях высоты кадра
uniform float radius = 0.2;
uniform float aspect = 1.776;
// Яркость скалы там, куда огонь не достаёт
uniform float dim = 0.68;
// Холод в тени (лунный свет): 0 — без сдвига цвета
uniform float cold = 0.12;
// Сила рельефного света
uniform float relief = 1.0;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = (UV - light_pos) * vec2(aspect, 1.0);
	vec2 de = d;
	// Вверх свет уходит дальше, вниз — короче
	de.y *= d.y < 0.0 ? 0.6 : 1.15;
	float r2 = dot(de, de);
	float fall = exp(-r2 / (radius * radius));
	float core = exp(-r2 / (radius * radius * 0.22));

	// ── 1. Ночь: всё, куда огонь не достаёт, темнее и холоднее ──
	float l0 = lum(c.rgb);
	vec3 night = c.rgb * dim;
	night = mix(night, vec3(l0 * dim) * vec3(0.86, 0.92, 1.05), cold);
	// Нарисованный свет у костра сохраняем: там скала остаётся как была
	vec3 col = mix(night, c.rgb, smoothstep(0.0, 0.7, fall));

	// ── 3. Нарисованный свет дышит вместе с огнём ──
	float warmth = clamp((c.r - c.b) * 3.0, 0.0, 1.0);
	col *= 1.0 + (light - 1.0) * core * (0.6 + warmth * 0.9);

	// ── 2. Живой свет по рельефу ──
	vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
	float hl = lum(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb);
	float hr = lum(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb);
	float hu = lum(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb);
	float hd = lum(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb);
	vec3 n = normalize(vec3((hl - hr) * 3.0, (hu - hd) * 3.0, 1.0));
	// Направление на огонь (чуть сверху — огонь выше поверхности камней)
	vec3 to_fire = normalize(vec3(-d, 0.06));
	float lambert = max(dot(n, to_fire), 0.0);
	vec3 warm = vec3(1.0, 0.5, 0.18);
	// Освещаем сам цвет камня (тёмное остаётся тёмным), плюс блики граней
	col += c.rgb * warm * fall * light * (0.12 + 0.7 * lambert) * relief;
	col += warm * core * light * lambert * 0.05 * relief;

	COLOR = vec4(col, c.a);
}
