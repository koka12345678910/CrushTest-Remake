shader_type canvas_item;
// weather_fog.gdshader — туман погоды (Levels/weather.gd). Прямоугольник во
// весь вид камеры, но узор — в координатах мира: клубы тумана лежат на земле
// и медленно плывут по ветру, а не ездят вместе с экраном. Два слоя шума
// разного размера и скорости — туман не выглядит одной плёнкой.
// Лампы его не освещают (light_mask = 0 — иначе ложатся тени окклюдеров),
// но цвет мира он получает: ночью туман тёмный, днём белёсый.
//
// Сдвиг по ветру считает скрипт (drift_a/drift_b) и заворачивает его на
// период шума — шум бесшовный, поэтому туман плывёт бесконечно без рывков
// (TIME раз в час сбрасывается — от него сдвиг прыгал бы).

// Сила тумана 0..1 — её плавно меняет погода
uniform float density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.78, 0.8, 0.82, 1.0);
// Размер клубов, пикселей мира (второй слой — мельче, scale * 0.45)
uniform float scale = 420.0;
// Сдвиг слоёв по ветру, пикселей мира
uniform vec2 drift_a = vec2(0.0);
uniform vec2 drift_b = vec2(0.0);
uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_half = vec2(320.0, 180.0);
// Насколько туман редеет у центра вида (там герой и бой)
uniform float clear_center : hint_range(0.0, 1.0) = 0.4;

// Период шума в клетках — тот же PERIOD в Levels/weather.gd
const float PERIOD = 32.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Хэш без sin(): на части видеокарт sin больших чисел неточен, и шум
// рассыпается на прямоугольные пятна
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Бесшовный шум: клетки решётки повторяются через per
float noise(vec2 p, float per) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(mod(i, per));
	float b = hash(mod(i + vec2(1.0, 0.0), per));
	float c = hash(mod(i + vec2(0.0, 1.0), per));
	float d = hash(mod(i + vec2(1.0, 1.0), per));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	float per = PERIOD;
	for (int i = 0; i < 4; i++) {
		v += noise(p, per) * a;
		p = p * 2.0 + vec2(17.0, 9.0);
		per *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = (world - drift_a) / scale;
	vec2 q = (world - drift_b) / (scale * 0.45) + vec2(11.0, 7.0);
	float n = fbm(p) * 0.65 + fbm(q) * 0.35;
	// Ровная дымка + клубы поверх неё
	float a = 0.35 + 0.65 * smoothstep(0.3, 0.75, n);
	float d = length((world - cam_pos) / view_half);
	a *= mix(1.0 - clear_center, 1.0, smoothstep(0.1, 0.9, d));
	// COLOR на входе = modulate узла: через него дом гасит туман под крышей
	vec4 m = COLOR;
	COLOR = vec4(fog_color.rgb * m.rgb, a * density * 0.7 * m.a);
}
