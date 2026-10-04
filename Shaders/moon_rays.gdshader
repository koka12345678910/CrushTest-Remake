shader_type canvas_item;
render_mode blend_add, unshaded;
// Лунные лучи: косые полосы бледного света, падающие сквозь туман.
// Рисуется на прямоугольном спрайте (UV 0..1): верх — "источник" (луч
// ярче), к низу луч тает, края по бокам мягкие. Полосы разной ширины
// медленно плывут и мерцают — свет пробивается сквозь листву/облака.
// Наклон задаётся поворотом узла, а не шейдером.

uniform vec4 ray_color : source_color = vec4(0.66, 0.78, 0.95, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.32;
// Сколько полос поперёк луча
uniform float ray_count = 6.0;
uniform float speed = 0.12;
// Разный сид — разные узоры у соседних лучей
uniform float seed = 0.0;
// С какой доли длины луч начинает таять к земле (верх — за краем карты, там он
// сплошной). len_scale растягивает "пыль" под длину луча
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;
uniform float len_scale = 1.0;

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
	vec2 uv = UV;
	// Полосы: шум только по X (поперёк луча) и по времени — вдоль луча
	// полоса непрерывна, поэтому читается как столб света
	float n1 = noise(vec2(uv.x * ray_count + seed, TIME * speed));
	float n2 = noise(vec2(uv.x * ray_count * 2.6 + seed * 3.1, TIME * speed * 1.7 + 4.0));
	float shafts = smoothstep(0.38, 0.85, n1 * 0.7 + n2 * 0.3);
	// Лёгкая "пыль" в луче
	float dust = smoothstep(0.93, 1.0, noise(vec2(uv.x * 60.0 + seed, uv.y * 40.0 * len_scale - TIME * 0.6))) * 0.5;
	float vfade = smoothstep(0.0, 0.03, uv.y) * (1.0 - smoothstep(fade_start, 1.0, uv.y));
	float hfade = smoothstep(0.0, 0.22, uv.x) * (1.0 - smoothstep(0.78, 1.0, uv.x));
	float a = (shafts + dust * shafts) * vfade * hfade * intensity;
	COLOR = vec4(ray_color.rgb, a);
}
