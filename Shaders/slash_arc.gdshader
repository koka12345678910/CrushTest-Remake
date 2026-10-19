shader_type canvas_item;
render_mode blend_add, unshaded;
// Дуга клинка рыцаря (VFX/VFX_scene/knight_slash.gd). Квадрат, центр — грудь
// рыцаря; по вертикали узел сплюснут — взмах идёт вокруг тела в 3/4 виде.
// По дуге от a_from к a_to бежит "голова" взмаха (progress), за ней тянется
// хвост: у головы полоса широкая и яркая, к хвосту сужается, уходит чуть
// внутрь и тает. Вдоль полосы — тонкие концентрические штрихи движения и
// яркая кромка лезвия по внешнему краю.

uniform vec4 color_core : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform vec4 color_edge : source_color = vec4(0.55, 0.68, 0.95, 1.0);
uniform float a_from = -1.4;
uniform float a_to = 1.4;
uniform float progress : hint_range(0.0, 1.0) = 0.5;
// Длина хвоста — доля всей дуги
uniform float tail = 0.55;
// Радиус середины полосы и её ширина — в долях половины квадрата
uniform float r_mid = 0.78;
uniform float width = 0.16;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float intensity = 1.0;
uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n * 91.345 + seed * 13.7) * 47453.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);

	float span = abs(a_to - a_from);
	float dirs = sign(a_to - a_from);
	// Насколько точка продвинулась по дуге от a_from (0..1, дальше — вне дуги)
	float d = mod((ang - a_from) * dirs + 12.56637, 6.28318);
	float u = d / max(span, 0.001);

	float head = progress * (1.0 + tail);
	float k = (u - (head - tail)) / tail;
	// Голова не обрывается прямой линией — мягко гаснет чуть впереди
	float head_soft = 1.0 - smoothstep(1.0, 1.0 + 0.05 / max(tail, 0.01), k);
	float on_arc = step(0.0, k) * head_soft * step(u, 1.0);
	k = clamp(k, 0.0, 1.0);

	// У головы полоса шире, хвост сужается и уходит чуть внутрь
	float w = width * mix(0.12, 1.0, pow(k, 0.7));
	float rc = r_mid - (1.0 - k) * width * 0.6;
	float dr = r - rc;
	// Внешний край — острый (лезвие), внутренний — мягкий
	float band = dr > 0.0 ? 1.0 - smoothstep(w * 0.25, w * 0.5, dr) : 1.0 - smoothstep(0.0, w, -dr);

	// Яркая кромка у внешнего края, сильнее у головы
	float edge = exp(-pow((dr - w * 0.32) / (w * 0.12 + 0.004), 2.0)) * pow(k, 1.5);

	// Штрихи движения: концентрические полосы, местами прерываются
	float stripe = 0.82 + 0.18 * sin(r * 160.0 + hash(floor(r * 40.0)) * 6.28);
	float broken = 0.88 + 0.12 * step(0.35, hash(floor(u * 24.0) + floor(r * 30.0) * 7.0));
	// Мягкое свечение вокруг полосы — дуга не плоская, а светится
	float glow = exp(-pow(dr / (w * 1.1 + 0.01), 2.0)) * 0.3 * k * (1.0 - smoothstep(0.88, 1.0, r));

	float a = band * pow(k, 1.1) * stripe * broken + edge * 1.4 + glow;
	// Кончики дуги не обрываются резко
	a *= smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.94, 1.0, u));
	a *= on_arc * fade * intensity;

	vec3 col = mix(color_edge.rgb, color_core.rgb, clamp(pow(k, 1.4) * 0.9 + edge, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
