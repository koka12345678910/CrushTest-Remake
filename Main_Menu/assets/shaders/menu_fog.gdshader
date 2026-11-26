shader_type canvas_item;

// Облака и дымка, проплывающие между горами (bg_mid.png) и скалой с костром
// (bg_front.png). Рисуется на прямоугольнике размером с весь кадр фона.
//
// Всё строится из двух бесшовных шумовых текстур (MenuBackdrop.gd): крупной
// «облачной» и мелкой «детальной». Процедурного шума с sin-хэшем нет — он
// даёт сетку и полосы и дорог на слабом ноутбуке.
//
// Три слоя, сзади вперёд:
//   1. море тумана в долине — низко, широко, медленно;
//   2. облачные гряды — плывут поперёк гор быстрее; форма «течёт» за счёт
//      искажения координат (domain warp), края рваные из-за детального шума;
//      гряды приходят и уходят — по ширине кадра бежит маска облачности;
//   3. тонкие космы — самые быстрые и прозрачные.
// Освещение облаков: луна слева сверху. Плотность сравнивается с соседней
// точкой в сторону луны — где облако «кончается» к луне, край светлый, а
// толща в тени чуть темнее. Так у облаков появляется объём и светлые
// верхушки, без тяжёлых тёмных пятен. У костра облака теплеют.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;
// Освещённая сторона облака (лунный свет) и сторона в тени
// Палитра — из неба и дымки у горизонта (сине-сланцевая), чтобы облака
// были частью сцены: прежние светлые серо-лиловые смотрелись наклеенными
uniform vec3 cloud_light : source_color = vec3(0.45, 0.51, 0.57);
uniform vec3 cloud_shade : source_color = vec3(0.19, 0.24, 0.29);
uniform float density = 0.92;
// Скорость течения гряд (доли текстуры в секунду); остальное — от неё
uniform float speed = 0.016;
// Откуда светит луна (направление на экране, y вниз)
uniform vec2 moon_dir = vec2(-0.55, -0.85);
uniform vec2 fire_uv = vec2(0.785, 0.65);
uniform float fire_light = 1.0;
uniform float aspect = 1.776;
// 0 — НИЗКОЕ качество: без искажения, без освещения и косм
uniform int quality = 2;

float warped(vec2 q, float t, float warp_k, float seed) {
	vec2 w = vec2(0.0);
	if (quality > 0) {
		w.x = texture(noise_tex, q * 0.45 + vec2(t * 0.5, seed)).r - 0.5;
		w.y = texture(noise_tex, q * 0.45 + vec2(seed + 0.31, t * 0.3)).r - 0.5;
	}
	return texture(noise_tex, q + w * warp_k + vec2(t, seed * 1.7)).r;
}

// Облачность здесь и сейчас: гряды приходят и уходят. Это СДВИГ порога, а
// не прозрачность — облако становится меньше или больше, но край остаётся
// чётким (умножение на маску делало облака полупрозрачными и мыльными)
float coverage(vec2 p, float t) {
	float pres = texture(noise_tex, vec2(p.x * 0.22 + t * 0.9, 0.81)).r;
	return (pres - 0.4) * 0.5;
}

// ПЛАВНОЕ поле плотности гряды в точке p (координаты кадра с учётом
// формата), bias — сдвиг облачности (по высоте и по маске coverage).
// Порог (где облако начинается) берётся снаружи; освещение считается по
// этому плавному полю — так свет и тень идут через всё облако, а не только
// по его кромке (иначе облака выходили плоскими пятнами)
float dens(vec2 p, float t, float bias) {
	// Пласты, вытянутые по горизонтали, как облака над долиной
	vec2 q = p * vec2(0.36, 1.5);
	float base = warped(q, t, 0.45, 0.13) + bias;
	// Край выедает мелкий шум: чем ближе к краю (base меньше), тем сильнее.
	// Середина остаётся плотной, кромка — рваной
	float det = texture(detail_tex, p * vec2(2.2, 5.0) + vec2(t * 1.4, 0.2)).r;
	return base - (1.0 - clamp(base, 0.0, 1.0)) * (det - 0.3) * 0.55;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = TIME * speed;

	// ── 1. Море тумана в долине ──
	float sea_band = smoothstep(0.5, 0.78, uv.y);
	float sea = 0.0;
	if (sea_band > 0.001) {
		sea = texture(noise_tex, p * vec2(0.3, 1.0) + vec2(t * 0.35, 0.57)).r;
		sea = smoothstep(0.3, 0.7, sea) * sea_band;
	}

	// ── 2. Облачные гряды поперёк гор ──
	// Живут на высоте хребтов и ниже: выше хребта облачность резко падает
	// (тоже сдвигом порога, не прозрачностью)
	float b = 0.0;
	float lit = 0.5;
	float belly = 0.0;
	float core = 0.0;
	float lumps = 0.0;
	if (uv.y > 0.3) {
		float bias = coverage(p, t)
			- (1.0 - smoothstep(0.33, 0.46, uv.y)) * 0.6
			- smoothstep(0.88, 1.0, uv.y) * 0.3;
		float d = dens(p, t, bias);
		// Край определённый, но не вырезанный ножницами
		b = smoothstep(0.46, 0.64, d);
		core = smoothstep(0.6, 0.9, d);
		if (quality > 0 && b > 0.01) {
			// Свет луны по всему облаку: сторона к луне светлее, от луны — темнее
			vec2 off = normalize(moon_dir) * vec2(0.035, 0.05);
			float toward = dens(p + off, t, bias);
			lit = clamp(0.5 + (d - toward) * 3.5, 0.0, 1.0);
			// Брюхо: ниже облако редеет — там тень
			float below = dens(p + vec2(0.0, 0.045), t, bias);
			belly = clamp((d - below) * 3.0, 0.0, 1.0);
			// Клубы: мелкий рельеф поверхности, у каждого клуба свой свет и
			// тень (bump по детальному шуму в сторону луны). Это и даёт
			// облаку детальность — без него заливка внутри ровная
			vec2 bp = p * vec2(3.2, 6.5) + vec2(t * 1.4, 0.6);
			vec2 boff = normalize(moon_dir) * 0.012;
			float h0 = texture(detail_tex, bp).r;
			float h1 = texture(detail_tex, bp + boff).r;
			lumps = clamp((h0 - h1) * 9.0, -1.0, 1.0) * (0.4 + 0.6 * core);
		}
	}

	// ── 3. Тонкие космы ──
	float w = 0.0;
	if (quality > 0) {
		float wb = smoothstep(0.36, 0.56, uv.y) * (1.0 - smoothstep(0.9, 1.0, uv.y));
		if (wb > 0.001) {
			float wn = warped(p * vec2(1.1, 4.2), t * 2.2, 0.9, 0.71);
			w = smoothstep(0.55, 0.8, wn) * wb;
		}
	}

	// Море в долине — лёгкое: горы на слое чистые, их рельеф должен читаться
	// сквозь дымку
	// Гряды плотные: тонкая кромка чуть просвечивает, толща — почти нет
	float ba = b * mix(0.72, 0.95, core);
	float a = clamp(sea * 0.2 + ba + w * 0.35, 0.0, 1.0) * density;
	// Цвет: море и космы — ровная лунная дымка, гряды — объёмные: сторона к
	// луне светлее, тёмное брюхо снизу, тонкая кромка серебрится, толща гуще
	vec3 haze = mix(cloud_shade, cloud_light, 0.5);
	vec3 bank_col = mix(cloud_shade, cloud_light, lit);
	bank_col *= 1.0 - 0.38 * belly;
	bank_col *= 1.0 + lumps * 0.32;
	// Толща облака ловит больше лунного света, тонкая кромка чуть темнее и
	// просвечивает (тёмная середина читалась как дыра в облаке)
	bank_col = mix(bank_col * 0.94, bank_col * 1.08, core);
	float bw = ba / max(sea * 0.2 + ba + w * 0.35, 0.0001);
	vec3 col = mix(haze, bank_col, clamp(bw, 0.0, 1.0));
	// Тепло костра в облаках рядом с ним
	float fd = length((uv - fire_uv) * vec2(aspect, 1.0));
	col += vec3(0.5, 0.23, 0.07) * fire_light * exp(-fd * fd * 18.0) * 0.5;
	COLOR = vec4(col, clamp(a, 0.0, 0.95));
}
