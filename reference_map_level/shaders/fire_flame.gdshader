shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
// Процедурное пламя (reference_map, scripts/fire_fx.gd). Ни одной текстуры.
//
// Модель: над "топливом" (полоса у основания шириной base_width) стоит
// столб горячего газа. Его высота вдоль x меняется медленным шумом — так
// получаются несколько верхушек-языков, которые растут, сливаются и
// опадают. Внутри столба течёт вверх поле шума, закрученное само в себе
// (domain warp): оно рвёт кромку на языки, а у верхушки отрывает клочья,
// которые улетают и гаснут. Из поля берутся:
//   температура → цвет чёрного тела: полупрозрачная тёмно-красная кромка
//     (светящийся газ), оранжевое тело, жёлтое и почти белое ядро у топлива;
//   копоть — над огнём тёмные клубы (premultiplied alpha: огонь светит
//     аддитивно, дым в том же проходе затемняет фон);
//   ореол — воздух вокруг пламени светится.
// unshaded: ночной CanvasModulate огонь не гасит, он сам источник света.
//
// Параметры каждого огня — в цвете вершин (FireFX рисует квад с ним):
//   r — сид, g — сила ядра (0..1), b — наклон (0.5 — прямо),
//   a — вспышка (0.5 — норма, больше — огонь выше и ярче).
// Квад: низ — основание огня (UV.y = 1).

uniform float rise = 1.9;          // скорость подъёма (размеров шума в секунду)
uniform float tongues = 3.0;       // сколько верхушек поперёк квада
uniform float grain = 3.2;         // частота шума внутри огня
uniform float base_width = 0.34;   // полуширина топлива, доля квада
uniform float reach = 0.8;         // средняя высота огня, доля квада
uniform float warp = 1.0;          // насколько закручено пламя
uniform float ragged = 1.0;        // насколько рвётся кромка
uniform float brightness = 1.2;
uniform float heat_gain = 1.3;     // доля огня, раскалённая до жёлтого и белого
uniform float halo = 0.22;         // свечение воздуха вокруг
uniform float soot = 0.55;         // копоть над огнём
uniform float flicker_speed = 1.0;
uniform float base_rag = 0.04;      // рваное основание (пожар — огонь из обломков, не из чаши)

varying vec4 v_data;

void vertex() {
	v_data = COLOR;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Градиентный шум, примерно -1..1
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(dot(hash2(i), f), dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
			mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
				dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y) * 1.6;
}

// Октавы с поворотом — без сетчатых артефактов
float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		s += a * gnoise(p);
		p = r * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

// Цвет раскалённого газа по температуре 0..1
vec3 blackbody(float k) {
	vec3 c = vec3(0.42, 0.04, 0.01);
	c = mix(c, vec3(0.9, 0.16, 0.02), smoothstep(0.05, 0.25, k));
	c = mix(c, vec3(1.0, 0.42, 0.07), smoothstep(0.2, 0.45, k));
	c = mix(c, vec3(1.0, 0.66, 0.2), smoothstep(0.42, 0.66, k));
	c = mix(c, vec3(1.0, 0.86, 0.5), smoothstep(0.62, 0.84, k));
	c = mix(c, vec3(1.0, 0.97, 0.86), smoothstep(0.82, 1.0, k));
	return c;
}

void fragment() {
	float seed = v_data.r * 97.0;
	float core_k = v_data.g;
	float lean = (v_data.b - 0.5) * 2.0;
	float fl = clamp(v_data.a * 2.0, 0.4, 1.8);   // 1 — обычный огонь
	float t = TIME * flicker_speed + seed * 7.31;

	float h = 1.0 - UV.y;                       // 0 основание … 1 верх квада
	float x = UV.x - 0.5;
	// Наклон и покачивание растут к верху — основание держится за топливо
	float sway = gnoise(vec2(t * 0.4, seed)) * 0.06 + gnoise(vec2(t * 1.3, seed + 3.0)) * 0.02;
	x -= (sway + lean * 0.14) * h * h;

	// Поле шума течёт вверх; по вертикали вытянуто — огонь в струях
	vec2 q = vec2(x * grain * 2.3, h * grain * 0.85);
	vec2 qs = q - vec2(0.0, t * rise);
	vec2 w = vec2(fbm(qs * 0.5 + vec2(seed, 0.0), 3), fbm(qs * 0.5 + vec2(5.2, seed + 1.3), 3));
	float n = fbm(qs + w * warp, 5);                 // -1..1
	float nf = gnoise(qs * 3.3 + w * 2.0);           // мелкая рябь кромки

	// Струи газа гнут x: языки виляют, а не стоят свечками
	float xw = x + n * 0.05 * h * ragged;

	// Топливо: плоская полоса с мягкими краями
	float fuel = 1.0 - smoothstep(base_width * 0.45, base_width, abs(xw));
	// Высота столба вдоль x: несколько верхушек, медленно меняются
	float tips = gnoise(vec2(xw * tongues * 2.0 + seed, t * 0.55)) * 0.55
			+ gnoise(vec2(xw * tongues * 4.6 - seed, t * 1.1 + 7.0)) * 0.3
			+ gnoise(vec2(xw * tongues * 9.0 + seed * 2.0, t * 1.9 + 3.0)) * 0.12;
	float edge_drop = smoothstep(0.0, base_width, abs(xw));   // к краям ниже
	float col_h = reach * fl * (0.72 + tips * 0.75) * (1.0 - edge_drop * edge_drop * 0.6);
	col_h = max(col_h, 0.05);
	float hh = h / col_h;                                     // 0..1 внутри столба

	// Температура: топливо × спад вверх, кромку рвёт шум (сильнее к верху)
	float heat = fuel * (1.0 - hh);
	heat += n * ragged * (0.22 + 0.42 * hh) * fuel;
	heat += nf * 0.06 * (0.3 + min(hh, 1.0)) * fuel;
	// Отрывающиеся клочья над столбом: верх поля шума без топлива
	float lick = smoothstep(0.42, 0.8, n) * smoothstep(1.3, 1.0, hh) * smoothstep(0.88, 1.02, hh);
	lick *= fuel * fuel * (1.0 - edge_drop);
	heat = max(heat, lick * 0.62 * ragged);
	// Скруглённое основание
	float bn = gnoise(vec2(xw * 9.0 + seed, t * 0.7)) * 0.5 + 0.5;
	heat *= smoothstep(0.0, 0.05 + bn * base_rag, h);
	heat = clamp(heat * heat_gain, 0.0, 1.0);

	// Ядро: у топлива по центру — почти белое
	float corek = (1.0 - smoothstep(0.0, 0.55, hh)) * (1.0 - smoothstep(0.0, base_width * 0.7, abs(xw))) * core_k;
	float k = clamp(heat * (0.82 + 0.08 * fl) + corek * 0.22 * smoothstep(0.3, 0.7, heat), 0.0, 1.0);

	// Яркость: кромка — полупрозрачный тёмно-красный газ, тело — плотное
	float dens = smoothstep(0.0, 0.16, heat) * mix(0.3, 1.0, smoothstep(0.1, 0.45, heat));
	vec3 fire = blackbody(k) * dens * brightness;
	// Мягкий потолок: перегретый канал не "срезается" в другой оттенок
	fire = fire / max(1.0, max(fire.r, max(fire.g, fire.b)));

	// Ореол: свечение воздуха вокруг столба
	float soft = 1.0 - smoothstep(0.0, base_width * 1.9, abs(x));
	float hal = soft * (1.0 - smoothstep(0.0, col_h * 1.3, h)) * smoothstep(0.0, 0.08, h);
	fire += vec3(1.0, 0.33, 0.07) * hal * hal * halo * (1.0 - dens) * fl;

	// Копоть: над огнём клочья того же поля, расходятся шире
	float sn = fbm(q * 0.7 - vec2(0.0, t * rise * 0.4) + w * 0.7, 4);
	float sm_w = base_width * 1.1 + (h - col_h) * 0.35;
	float smk = (1.0 - smoothstep(0.0, sm_w, abs(x))) * smoothstep(0.7, 1.15, hh) * (1.0 - smoothstep(0.85, 1.0, h));
	smk *= smoothstep(-0.05, 0.45, sn) * soot * (1.0 - dens);
	vec3 smoke_col = mix(vec3(0.2, 0.07, 0.02), vec3(0.02, 0.018, 0.022), smoothstep(1.0, 1.4, hh));

	// Края квада всегда пустые
	float frame = smoothstep(0.0, 0.14, UV.x) * smoothstep(0.0, 0.14, 1.0 - UV.x) * smoothstep(0.0, 0.04, UV.y);
	fire *= frame;
	smk *= frame;
	COLOR = vec4(fire + smoke_col * smk, smk * 0.8);
}
