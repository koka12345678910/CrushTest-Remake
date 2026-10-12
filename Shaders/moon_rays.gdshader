shader_type canvas_item;
render_mode blend_add, unshaded;
// Лунные лучи: косые столбы бледного света в сыром ночном воздухе.
// Рисуется на прямоугольном спрайте (UV 0..1): верх — "источник" (за краем
// карты), к земле луч тает, края по бокам очень мягкие. Внутри — несколько
// размытых столбов разной ширины, плотность воздуха вдоль луча неровная
// (дымка), а весь луч медленно "дышит" — луну то затягивает облаком, то
// открывает. Наклон задаётся поворотом узла, а не шейдером.

uniform vec4 ray_color : source_color = vec4(0.66, 0.78, 0.95, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.2;
// Сколько столбов поперёк луча
uniform float ray_count = 4.0;
uniform float speed = 0.06;
// Разный сид — разные узоры у соседних лучей
uniform float seed = 0.0;
// С какой доли длины луч начинает таять к земле (верх — за краем карты, там он
// сплошной). len_scale растягивает "пыль" и дымку под длину луча
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
	// Столбы: шум по X (поперёк луча) и по времени. Широкий мягкий порог —
	// столбы перетекают друг в друга, а не режутся полосами
	float n1 = noise(vec2(uv.x * ray_count + seed, TIME * speed));
	float n2 = noise(vec2(uv.x * ray_count * 2.3 + seed * 3.1, TIME * speed * 1.6 + 4.0));
	float shafts = smoothstep(0.2, 0.95, n1 * 0.75 + n2 * 0.25);
	// Дымка: плотность воздуха вдоль луча неровная и медленно плывёт — без неё
	// луч выглядит как идеальная линейка
	float haze = 0.55 + 0.45 * noise(vec2(uv.x * 3.0 + seed * 1.3, uv.y * 4.0 * len_scale - TIME * 0.05));
	// Облака на луне: весь луч то слабеет, то разгорается
	float breathe = mix(0.4, 1.0, smoothstep(0.25, 0.75, noise(vec2(seed * 2.7, TIME * 0.035))));
	// Редкие пылинки/капли, поймавшие свет
	float dust = smoothstep(0.94, 1.0, noise(vec2(uv.x * 60.0 + seed, uv.y * 40.0 * len_scale - TIME * 0.5))) * 0.35;
	float vfade = smoothstep(0.0, 0.03, uv.y) * (1.0 - smoothstep(fade_start, 1.0, uv.y));
	// Края гаснут по кривой ~ гауссиане: границы луча не читаются
	float x = uv.x * 2.0 - 1.0;
	float hfade = exp(-x * x * 2.5) * (1.0 - smoothstep(0.85, 1.0, abs(x)));
	float a = (shafts * haze + dust * shafts) * breathe * vfade * hfade * intensity;
	COLOR = vec4(ray_color.rgb, a);
}
