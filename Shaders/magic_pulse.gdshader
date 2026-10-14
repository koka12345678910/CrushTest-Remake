shader_type canvas_item;
render_mode blend_add, unshaded;
// Импульс мага (Attack_3_): ударная волна-кольцо, расходящаяся от мага.
// Рисуется на квадрате (UV 0..1, центр — маг). progress 0..1 — насколько
// разошлась волна, fade 1..0 — угасание. Край кольца рваный, внутри — мягкое
// свечение, которое тает быстрее самого кольца.
//
// Шум — из готовой бесшовной текстуры (noise_tex, её делает
// Player_scene/mage_fx.gd), а не из формулы с sin(): самодельный шум давал на
// видеокарте разрывы по границам своих ячеек, и клочья волны обрывались
// прямыми линиями.

uniform vec4 color_core : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float ring_width = 0.12;
uniform float intensity = 1.5;
uniform float seed = 0.0;
// 0 — волна держит форму до конца; 1 — по мере расхождения расплывается
// (кольцо шире и рванее) и тает (дальняя волна Attack_3_)
uniform float dissipate : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

float tn(vec2 uv) {
	return texture(noise_tex, uv).r;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;          // -1..1, центр в маге
	float r = length(p);
	vec2 dir = r > 0.0001 ? p / r : vec2(1.0, 0.0);
	float spread = dissipate * progress;
	// Рваный край: радиус кольца чуть гуляет по углу. Шум берём по точке на
	// окружности (cos, sin), а не по самому углу — у угла есть скачок слева
	float wob = (tn(dir * 0.35 + vec2(seed * 0.13, TIME * 0.22)) - 0.5) * (0.1 + 0.12 * spread);
	float front = progress * 0.95 + wob;
	float d = abs(r - front);
	// Рассеивание: кольцо расплывается шире...
	float width = ring_width * (1.0 + 2.2 * spread);
	float ring = 1.0 - smoothstep(0.0, width, d);
	// Прожилки энергии по кольцу; при рассеивании кольцо рвётся на клочья.
	// Две октавы со сдвигом и лёгким искажением — клочья округлые
	vec2 q = p * 0.75 + vec2(seed * 0.11, -seed * 0.07);
	vec2 warp = vec2(tn(q * 0.6 + TIME * 0.05), tn(q.yx * 0.6 - TIME * 0.04)) - 0.5;
	float streak = tn(q + warp * 0.35 + vec2(TIME * 0.06, 0.0)) * 0.65
			+ tn(q * 2.1 - warp * 0.25 + vec2(0.37, TIME * 0.09)) * 0.35;
	ring *= mix(0.55 + 0.45 * streak, smoothstep(0.3, 0.8, streak), spread);
	// ...и тает к краю своего пути
	ring *= 1.0 - spread * 0.85;
	// Внутреннее свечение за фронтом — гаснет к концу волны
	float inner = (1.0 - smoothstep(0.0, front, r)) * (1.0 - progress) * 0.3;
	float a = (ring + inner) * fade * intensity;
	a *= 1.0 - smoothstep(0.95, 1.0, r);   // не вылезаем за квадрат
	vec3 col = mix(color_edge.rgb, color_core.rgb, clamp(ring * 0.8 + inner, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
