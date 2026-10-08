shader_type canvas_item;
render_mode blend_add, unshaded;
// Импульс мага (Attack_3_): ударная волна-кольцо, расходящаяся от мага.
// Рисуется на квадрате (UV 0..1, центр — маг). progress 0..1 — насколько
// разошлась волна, fade 1..0 — угасание. Край кольца рваный (шум по углу),
// внутри — мягкое свечение, которое тает быстрее самого кольца.

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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;          // -1..1, центр в маге
	float r = length(p);
	float ang = atan(p.y, p.x);
	// Рваный край: радиус кольца чуть гуляет по углу
	float spread = dissipate * progress;
	float wob = (noise(vec2(ang * 3.0 + seed, TIME * 4.0)) - 0.5) * (0.08 + 0.1 * spread);
	float front = progress * 0.95 + wob;
	float d = abs(r - front);
	// Рассеивание: кольцо расплывается шире...
	float width = ring_width * (1.0 + 2.2 * spread);
	float ring = 1.0 - smoothstep(0.0, width, d);
	// Прожилки энергии по кольцу; при рассеивании кольцо рвётся на клочья
	float streak = noise(vec2(ang * 9.0 + seed * 2.0, r * 12.0 - TIME * 6.0));
	ring *= mix(0.55 + 0.45 * streak, smoothstep(0.3, 0.8, streak), spread);
	// ...и тает к краю своего пути
	ring *= 1.0 - spread * 0.85;
	// Внутреннее свечение за фронтом — гаснет к концу волны
	float inner = (1.0 - smoothstep(0.0, front, r)) * (1.0 - progress) * 0.55;
	float a = (ring + inner) * fade * intensity;
	a *= 1.0 - smoothstep(0.95, 1.0, r);   // не вылезаем за квадрат
	vec3 col = mix(color_edge.rgb, color_core.rgb, clamp(ring * 0.8 + inner, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
