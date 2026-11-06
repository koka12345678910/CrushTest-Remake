shader_type canvas_item;
// Истощение Сигрид: кровь стучит в висках. По краям экрана — тёмно-багровая
// виньетка и сеть вен; на каждый удар сердца (beat 0..1, его считает
// UI/sigrid_exhaust.gd по звуку сердцебиения) вены набухают и светлеют,
// виньетка подступает к центру, картинка чуть стягивается внутрь.
// Вены — по текстуре клеточного шума (vein_tex: края ячеек = тонкие линии),
// не по fract(sin()) — тот на видеокарте пользователя давал квадраты.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D vein_tex : repeat_enable, filter_linear;
uniform sampler2D warp_tex : repeat_enable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float beat : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;
uniform vec4 shade_color : source_color = vec4(0.10, 0.0, 0.015, 1.0);
uniform vec4 vein_color : source_color = vec4(0.34, 0.02, 0.04, 1.0);
uniform vec4 vein_pulse_color : source_color = vec4(0.62, 0.05, 0.06, 1.0);
uniform float vein_scale = 1.0;
uniform float vein_width = 3.2;
uniform float squeeze = 0.006;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	c.x *= aspect;
	// 0 в центре, ~1 в углах
	float d = length(c) / length(vec2(0.5 * aspect, 0.5));
	float s = strength;

	// Стягивание к центру на ударе — сильнее у краёв
	vec2 suv = uv - (uv - 0.5) * squeeze * beat * s * (0.4 + d);
	vec3 col = texture(screen_tex, suv).rgb;

	// Тёмная багровая рамка; на ударе подступает ближе к центру
	float inner = 0.62 - 0.08 * beat;
	float edge = smoothstep(inner, 1.05, d);
	col = mix(col, shade_color.rgb, edge * s * (0.72 + 0.23 * beat));
	// Чуть обесцветить и притемнить всю картинку — мир «плывёт»
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g) * 0.85, 0.22 * s);

	// Вены тянутся от краёв к центру: линии уровня мягкого шума в полярных
	// координатах, сжатого по углу и растянутого по радиусу — так изолинии
	// идут почти радиально, изгибаются и сами ветвятся. Угол умножается на
	// целое — шов atan на стыке не виден (текстура бесшовная)
	float ang = atan(c.y, c.x) / 6.2831853 + 0.5;
	// Тот же угол со швом на другой стороне (справа, а не слева). Значения
	// шума по обоим совпадают (сдвиг на целое число периодов), но производные
	// fwidth на шве ломаются — берём их с того угла, где шва сейчас нет.
	// Иначе слева по центру рисовалась прямая черта
	float ang2 = fract(ang + 0.5) - 0.5;
	// Докуда вены доходят: в покое — только у краёв, на ударе — чуть глубже
	float reach = smoothstep(0.5 - 0.07 * beat, 0.97, d);
	// Толщина в ПИКСЕЛЯХ (через fwidth): линия уровня везде одной ширины и
	// не расплывается в пятна там, где шум почти плоский. К центру тоньше
	float px = vein_width * (0.45 + 0.55 * reach) * (1.0 + 0.5 * beat);
	// Стволы (изгиб — тоже целым числом периодов по углу, без шва)
	float r1 = d * vein_scale * 0.5;
	float bend = (texture(vein_tex, vec2(ang * 4.0, r1) + 0.21).r - 0.5) * 0.12;
	float bend2 = (texture(vein_tex, vec2(ang2 * 4.0, r1) + 0.21).r - 0.5) * 0.12;
	float n1 = texture(warp_tex, vec2(ang * 7.0 + bend, r1)).r;
	float n1b = texture(warp_tex, vec2(ang2 * 7.0 + bend2, r1)).r;
	float d1 = abs(n1 - 0.5) / max(min(fwidth(n1), fwidth(n1b)), 0.0001);
	float trunk = 1.0 - smoothstep(px * 0.5, px, d1);
	// Ветки — тоньше, гуще и только у самого края
	float r2 = d * vein_scale * 1.3 + 0.37;
	float n2 = texture(warp_tex, vec2(ang * 17.0 + 0.37, r2)).r;
	float n2b = texture(warp_tex, vec2(ang2 * 17.0 + 0.37, r2)).r;
	float d2 = abs(n2 - 0.5) / max(min(fwidth(n2), fwidth(n2b)), 0.0001);
	float twig = (1.0 - smoothstep(px * 0.3, px * 0.6, d2)) * smoothstep(0.75, 1.0, d);
	float vein = max(trunk, twig * 0.85) * reach;
	vec3 vc = mix(vein_color.rgb, vein_pulse_color.rgb, beat);
	col = mix(col, vc, clamp(vein * s * (0.75 + 0.25 * beat), 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
