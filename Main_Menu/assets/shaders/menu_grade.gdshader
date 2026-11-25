shader_type canvas_item;

// Цветокоррекция главного меню в духе souls-like: картинка не «красивая», а
// атмосферная. Берёт уже нарисованный кадр (фон + дождь) и:
//   - гасит цвет и яркость, оставляя тёплым только огонь;
//   - кладёт холодный тон в тени;
//   - пускает медленный туман по низу кадра;
//   - затемняет «колодец» под меню, чтобы текст читался на любом фоне;
//   - тяжёлая виньетка и плёночное зерно.
// Стоит первым в EffectsLayer: угли и вспышка молнии рисуются уже поверх
// и остаются яркими — это источники света, их глушить нельзя.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// 0 — исходный цвет, 1 — ч/б
uniform float desat : hint_range(0.0, 1.0) = 0.6;
uniform float exposure : hint_range(0.0, 2.0) = 0.78;
// Тон теней (холодный) и светов (тёплый)
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.84, 1.0);
uniform vec3 light_tint : source_color = vec3(1.0, 0.94, 0.86);
// Огонь сохраняет часть цвета: доля «тёплого» пикселя, не тронутая desat
uniform float keep_fire : hint_range(0.0, 1.0) = 0.65;
uniform float vignette : hint_range(0.0, 1.0) = 0.8;
uniform float grain : hint_range(0.0, 0.2) = 0.03;
// Туман: сила и цвет; use_fog = false на НИЗКОМ пресете графики
uniform bool use_fog = true;
uniform float fog : hint_range(0.0, 1.0) = 0.55;
uniform vec3 fog_color : source_color = vec3(0.5, 0.55, 0.62);
// Колодец темноты под меню (координаты экрана 0..1)
uniform vec2 well_center = vec2(0.5, 0.66);
uniform vec2 well_size = vec2(0.34, 0.3);
uniform float well_dark : hint_range(0.0, 1.0) = 0.45;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 c = texture(screen_tex, uv).rgb;

	// Цвет: огонь (красное заметно больше синего) держит насыщенность
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float fire = smoothstep(0.04, 0.22, c.r - c.b) * smoothstep(0.08, 0.3, lum);
	float sat = mix(1.0 - desat, 1.0, fire * keep_fire);
	c = mix(vec3(lum), c, sat);
	// Холод в тенях, тепло в светах (split toning)
	c *= mix(shadow_tint, light_tint, smoothstep(0.05, 0.5, lum));
	c *= exposure;

	// Туман: два слоя шума, плывут в разные стороны, гуще у земли
	if (use_fog) {
		vec2 p = vec2(uv.x * aspect, uv.y);
		float f1 = fbm(p * 2.2 + vec2(TIME * 0.018, -TIME * 0.004));
		float f2 = fbm(p * 4.1 + vec2(-TIME * 0.011, TIME * 0.006));
		float f = smoothstep(0.35, 0.85, f1 * 0.65 + f2 * 0.45);
		float ground = smoothstep(0.3, 0.95, uv.y);
		c = mix(c, fog_color * 0.22, f * ground * fog);
	}

	// Колодец под меню: мягкое пятно темноты
	vec2 w = (uv - well_center) / well_size;
	c *= 1.0 - well_dark * (1.0 - smoothstep(0.2, 1.0, length(w)));

	// Виньетка: края почти в чёрное
	vec2 q = (uv - 0.5) * vec2(aspect * 0.62, 1.0);
	c *= mix(1.0 - vignette, 1.0, smoothstep(0.78, 0.18, length(q)));

	// Зерно — не статичное, «живёт» каждый кадр
	c += (hash(floor(uv / SCREEN_PIXEL_SIZE) + fract(TIME * 7.13) * 97.0) - 0.5) * grain;

	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
