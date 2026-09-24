shader_type canvas_item;
// hud_worn.gdshader
// "Поношенность" для HUD: весь интерфейс рисуется примитивами (_draw) и
// выглядит слишком чисто, как векторный. Шейдер поверх любого цвета кладёт
// грязь пятнами, потускнение золота (патину), мелкие царапины, сколы краски
// и зерно. Текстуры не нужны — шум процедурный.
//
// Узор считается от позиции на канвасе HUD (1920×1080), а не от UV: у
// примитивов _draw() осмысленных UV нет, а так каждый элемент получает свой
// рисунок и тот не "плывёт" при изменении размера окна.
// Настраивается в UI/hud_worn_material.tres

uniform float pattern_scale = 1.0;
// Тёмные пятна грязи/копоти
uniform float grime_strength : hint_range(0.0, 1.0) = 0.42;
// Потускневшее, "окислившееся" золото — уходит в серо-бурый
uniform float tarnish_strength : hint_range(0.0, 1.0) = 0.3;
// Тонкие светлые царапины
uniform float scratch_strength : hint_range(0.0, 1.0) = 0.4;
// Сколы: участки, где краска/позолота стёрлась до тёмного металла
uniform float chip_amount : hint_range(0.0, 0.5) = 0.08;
uniform vec3 chip_color : source_color = vec3(0.1, 0.075, 0.06);
// Мелкое зерно, как у кожи/старого металла
uniform float grain_strength : hint_range(0.0, 0.3) = 0.07;

varying vec2 canvas_pos;

void vertex() {
	canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	p = mod(p, 289.0);
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
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
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// Царапины: шум, сильно растянутый вдоль одной оси, даёт тонкие штрихи.
// Три семейства под разными углами, собраны в кучки низкочастотной маской —
// чтобы царапины были местами, а не ровной штриховкой по всему HUD
float scratches(vec2 p) {
	float s = 0.0;
	for (int k = 0; k < 3; k++) {
		float ang = 0.5 + float(k) * 2.1;
		vec2 q = vec2(cos(ang) * p.x - sin(ang) * p.y, sin(ang) * p.x + cos(ang) * p.y);
		float streak = vnoise(vec2(q.x * 0.018, q.y * 0.9) + float(k) * 13.7);
		float cluster = smoothstep(0.5, 0.75, vnoise(p * 0.02 + float(k) * 5.3));
		s = max(s, smoothstep(0.9, 0.98, streak) * cluster);
	}
	return s;
}

void fragment() {
	vec4 c = COLOR;
	vec2 p = canvas_pos * pattern_scale;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));

	float patches = fbm(p * 0.035);
	float fine = fbm(p * 0.45);

	// Грязь: тёмные пятна, внутри тоже неровные
	c.rgb *= 1.0 - grime_strength * smoothstep(0.42, 0.8, patches) * (0.55 + 0.45 * fine);

	// Патина: в своих пятнах цвет теряет насыщенность и буреет
	float tarnish = smoothstep(0.38, 0.72, fbm(p * 0.05 + 31.7));
	vec3 dull = vec3(lum) * vec3(0.9, 0.8, 0.66);
	c.rgb = mix(c.rgb, dull, tarnish_strength * tarnish);

	// Сколы: позолота/краска стёрлась до тёмного металла. Дыр в альфе не
	// делаем — у полосок заливка и подложка в одном месте, и дыра прошла бы
	// насквозь до травы уровня
	float chip_n = fbm(p * 0.09 + 71.3) * 0.5 + fbm(p * 0.3 + 5.1) * 0.5;
	float chip = smoothstep(0.7 - chip_amount, 0.72 - chip_amount, chip_n)
		* smoothstep(0.08, 0.25, lum);
	c.rgb = mix(c.rgb, chip_color, chip * 0.7);

	// Царапины светлеют сильнее на ярком металле, на тёмной подложке — едва
	c.rgb += scratches(p) * scratch_strength * (0.12 + 0.45 * lum);

	c.rgb += (fine - 0.5) * grain_strength;
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), c.a);
}
