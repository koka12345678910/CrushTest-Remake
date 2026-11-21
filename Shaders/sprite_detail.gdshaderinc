// sprite_detail.gdshader — светотень и мрачная палитра на самой текстуре
// спрайта (Сигрид, Player_scene/sigrid_detail_material.tres). Исходные листы
// не меняются — всё считается попиксельно при отрисовке, на любом кадре любой
// анимации. Вокруг фигуры ничего не добавляется (никакого контура) — только
// внутри неё, как рисуют светотень в пиксель-арте:
//   - объём от формы: у края к свету — светлая зона в 1-3 пикселя, у края
//     от света — тень, с плавным спадом внутрь;
//   - рельеф: складки и выступы ткани освещаются по яркости относительно
//     соседей (что ярче соседа со стороны света — выступ, темнее — впадина);
//   - проработка: локальный контраст в двух масштабах (1 и 2 пикселя) —
//     проступают швы, ремни, складки ткани и потёртости кожи;
//   - углубления (складки, промежутки между ремнями) темнее;
//   - мрачная палитра: тёплые тона (светлая ткань, рыжая кожа) гасятся в
//     пепельно-бурые, полутона темнее, тени холодные, света лунные;
//   - ноги темнее головы (свет сверху).
// Запечённую полупрозрачную тень на земле не трогает: "телом" считается
// только почти непрозрачное (alpha >= body_alpha).

uniform float body_alpha : hint_range(0.0, 1.0) = 0.9;
// Откуда падает свет (по экрану, y вниз): по умолчанию сверху-слева
uniform vec2 light_dir = vec2(-0.55, -0.85);
uniform vec4 shadow_tint : source_color = vec4(0.5, 0.52, 0.66, 1.0);
uniform vec4 light_tint : source_color = vec4(0.82, 0.9, 1.0, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.65;
uniform float light_strength : hint_range(0.0, 1.0) = 0.5;
// Сколько рельефа брать из яркости соседей (складки, швы)
uniform float relief : hint_range(0.0, 8.0) = 4.0;
uniform float crevice : hint_range(0.0, 1.0) = 0.42;
// Ширина ступени между тенью, полутоном и светом (меньше — резче ступени)
uniform float band_softness : hint_range(0.01, 0.5) = 0.12;
uniform float ground_shade : hint_range(0.0, 1.0) = 0.22;
// Резкость мелких деталей (соседи в 1 пиксель) и крупных (в 2 пикселя)
uniform float detail : hint_range(0.0, 2.0) = 0.6;
uniform float detail_wide : hint_range(0.0, 2.0) = 0.45;
uniform float contrast : hint_range(0.5, 2.0) = 1.12;
uniform float saturation : hint_range(0.0, 2.0) = 0.7;
// Насколько дополнительно гасить именно тёплые тона (бежевая ткань, рыжая
// кожа) — от них модель и выглядела "чистенькой" на ночном кладбище
uniform float warm_desaturation : hint_range(0.0, 1.0) = 0.55;
// Кривая яркости: > 1 — полутона темнее, при этом света остаются светом
uniform float value_gamma : hint_range(0.5, 2.5) = 1.18;
// Светлая ткань (бежевые штаны, рубаха) — приглушить в грязно-серую. Самые
// яркие пиксели (металл клинка, блики) не трогаем — им нужно светиться
uniform float cloth_dim : hint_range(0.0, 1.0) = 0.24;
uniform vec4 cloth_tint : source_color = vec4(0.86, 0.85, 0.8, 1.0);
// Самый тёмный цвет фигуры — подложка вместо чистого чёрного: впадины
// не должны читаться дырами или контуром
uniform vec4 shadow_floor : source_color = vec4(0.05, 0.055, 0.07, 1.0);
// Тонировка по яркости: тени — в холодную синеву, света — в лунный
uniform vec4 shadow_grade : source_color = vec4(0.72, 0.78, 0.92, 1.0);
uniform vec4 highlight_grade : source_color = vec4(0.97, 0.96, 0.92, 1.0);
// Общая яркость фигуры: светлая модель выделялась на тёмных ночных уровнях
uniform float brightness : hint_range(0.3, 1.5) = 0.96;
// Размер ячейки кадра в листе (кадры 128x128) — чтобы знать высоту внутри кадра
uniform float cell_px = 128.0;
// Перекраска вшитой в кадры магии (маг: ледяные эффекты Frost-листов) в его
// собственную палитру — как у огненного шара и выжигания (mage_fx.gd). Магия —
// яркое насыщенное бирюзовое (оттенок ~165..210°, яркость > ~0.5): по яркости
// она отделяется от тёмной сине-бирюзовой мантии того же оттенка. Почти белые
// следы взмахов слегка уходят в холодное ядро. Применяется ПОСЛЕ тонировки —
// магия светится, как его огонь, а не гаснет вместе с мантией.
// 0 — выключено (рыцарь, лучница), 1 — полностью
uniform float magic_recolor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 magic_core : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform vec4 magic_mid : source_color = vec4(0.42, 0.72, 1.0, 1.0);
uniform vec4 magic_edge : source_color = vec4(0.14, 0.32, 1.0, 1.0);

// Приглушить насыщенную охру (оттенок ~10..36°, насыщенность > ~0.35) в
// тёмное старое дерево: круглый рыжий щит скелета-щитовика на земле после
// смерти читался как монета. Бледную кость (насыщенность ~0.2) и красную
// ткань (~330°) не трогает. 0 — выключено (остальные персонажи)
uniform float ochre_mute : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ochre_tint : source_color = vec4(0.62, 0.58, 0.52, 1.0);

// Цвет вершины (modulate спрайта — вспышки урона, свечение навыков). В
// fragment COLOR уже умножен на текстуру, поэтому берём его из vertex
varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

#ifdef HERO_LIT
// ---- Герой под настоящим светом (reference_map_level/shaders/hero_lit) ----
// Тень, нарисованная художником под ногами, — чисто чёрная и полупрозрачная
// (контур тела тёмный, но не чисто чёрный и непрозрачный). Её вырезаем:
// тень героя даёт свет (reference_map_level/scripts/hero_light.gd)
bool baked_shadow(vec4 t) {
	return t.a < 0.985 && max(t.r, max(t.g, t.b)) < 0.02;
}

vec4 tex_at(sampler2D t, vec2 uv) {
	vec4 c = texture(t, uv);
	return baked_shadow(c) ? vec4(0.0) : c;
}

// Насколько сильно форма силуэта и складки гнут нормаль
uniform float shape_normal = 1.6;
uniform float relief_normal = 1.2;

float hero_a(sampler2D t, vec2 uv) {
	return tex_at(t, uv).a;
}

// Нормаль фигуры без карты нормалей: край силуэта смотрит наружу (по
// размытой маске в трёх масштабах — тело "пухлое", а не плоская вырезка),
// яркое внутри — выпуклее тёмного (складки, ремни, пластины). В формате
// карт нормалей карты (зелёный — вверх), Godot сам учитывает flip_h
vec3 hero_normal(sampler2D t, vec2 uv, vec2 px) {
	vec2 dirs[8] = {vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
			vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707)};
	vec2 g = vec2(0.0);
	float radii[3] = {1.5, 3.0, 5.5};
	float wts[3] = {0.5, 0.32, 0.22};
	for (int r = 0; r < 3; r++) {
		for (int i = 0; i < 8; i++) {
			g += dirs[i] * hero_a(t, uv + dirs[i] * px * radii[r]) * wts[r];
		}
	}
	// g — к телу (внутрь); нормаль края — наружу
	vec2 nxy = -g * shape_normal * 0.5;
	float lr = dot(tex_at(t, uv + vec2(px.x, 0.0)).rgb, vec3(0.333)) - dot(tex_at(t, uv - vec2(px.x, 0.0)).rgb, vec3(0.333));
	float ld = dot(tex_at(t, uv + vec2(0.0, px.y)).rgb, vec3(0.333)) - dot(tex_at(t, uv - vec2(0.0, px.y)).rgb, vec3(0.333));
	nxy -= vec2(lr, ld) * relief_normal;
	vec3 n = normalize(vec3(nxy, 1.0));
	return vec3(n.x * 0.5 + 0.5, -n.y * 0.5 + 0.5, n.z * 0.5 + 0.5);
}
#else
vec4 tex_at(sampler2D t, vec2 uv) {
	return texture(t, uv);
}
#endif

float body(sampler2D t, vec2 uv) {
	return step(body_alpha, tex_at(t, uv).a);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

// Насколько пиксель — вшитая магия (0..1) и чем её заменить (палитра мага).
// Возвращает vec4(цвет, вес)
vec4 magic_of(vec3 c) {
	vec3 hsv = rgb2hsv(c);
	float hue = hsv.x * 360.0;
	float hue_m = smoothstep(150.0, 168.0, hue) * (1.0 - smoothstep(203.0, 216.0, hue));
	float m = hue_m * smoothstep(0.45, 0.62, hsv.z) * smoothstep(0.16, 0.36, hsv.y);
	// Светлота решает, где на "огне" пиксель: тёмный край — глубокий синий,
	// середина — голубой, самое яркое — почти белое ядро
	float l = (max(c.r, max(c.g, c.b)) + min(c.r, min(c.g, c.b))) * 0.5;
	vec3 ramp = l < 0.6 ? mix(magic_edge.rgb, magic_mid.rgb, smoothstep(0.28, 0.6, l))
			: mix(magic_mid.rgb, magic_core.rgb, smoothstep(0.6, 0.92, l));
	// Чуть ярче исходного — магия светится, как огонь мага
	vec3 target = ramp * hsv.z * 1.15;
	// Почти белые следы — лишь чуть холоднее, к ядру
	float white = smoothstep(0.72, 0.9, hsv.z) * (1.0 - smoothstep(0.08, 0.22, hsv.y)) * (1.0 - m);
	target = mix(target, magic_core.rgb * hsv.z, white / max(m + white, 1e-4));
	return vec4(target, max(m, white * 0.5));
}

// Среднее по телу в кольце радиуса r пикселей (пустоту вокруг не считаем —
// иначе край фигуры темнел бы и читался как контур)
vec3 ring_avg(sampler2D t, vec2 uv, vec2 px, float r, vec3 fallback) {
	vec2 offs[8] = {vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
			vec2(0.7, 0.7), vec2(-0.7, 0.7), vec2(0.7, -0.7), vec2(-0.7, -0.7)};
	vec3 sum = vec3(0.0);
	float cnt = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 n = tex_at(t, uv + offs[i] * px * r);
		float b = step(body_alpha, n.a);
		sum += n.rgb * b;
		cnt += b;
	}
	return cnt > 0.0 ? sum / cnt : fallback;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = tex_at(TEXTURE, UV);
	vec4 result = tex;
	vec4 magic = magic_recolor > 0.0 ? magic_of(tex.rgb) : vec4(0.0);
	if (tex.a >= body_alpha) {
		vec3 c = tex.rgb;
		if (ochre_mute > 0.0) {
			vec3 hsv = rgb2hsv(c);
			float hue = hsv.x * 360.0;
			float om = smoothstep(6.0, 12.0, hue) * (1.0 - smoothstep(34.0, 40.0, hue))
					* smoothstep(0.3, 0.42, hsv.y);
			c = mix(c, vec3(lum(c)) * ochre_tint.rgb * 1.25, om * ochre_mute);
		}
		float h = lum(c);
		vec2 l = normalize(light_dir);

		// Проработка: локальный контраст в двух масштабах
		vec3 avg = ring_avg(TEXTURE, UV, px, 1.0, c);
		vec3 avg_wide = ring_avg(TEXTURE, UV, px, 2.0, c);
		c += (c - avg) * detail + (c - avg_wide) * detail_wide;

		// Объём от силуэта: сколько пустоты в 1..3 пикселях к свету и от света
		float toward = 0.0;
		float away = 0.0;
		for (int i = 1; i <= 3; i++) {
			float w = 1.0 - float(i - 1) * 0.3;
			toward += (1.0 - body(TEXTURE, UV + l * px * float(i))) * w;
			away += (1.0 - body(TEXTURE, UV - l * px * float(i))) * w;
		}
		toward = clamp(toward / 1.4, 0.0, 1.0);
		away = clamp(away / 1.4, 0.0, 1.0);

		// Рельеф из яркости: сосед со стороны света темнее — значит, этот
		// пиксель на выступе, повёрнутом к свету; ярче — во впадине
		vec4 nl = tex_at(TEXTURE, UV + l * px);
		vec4 nd = tex_at(TEXTURE, UV - l * px);
		float slope = 0.0;
		if (nl.a >= body_alpha && nd.a >= body_alpha) {
			slope = clamp((lum(nd.rgb) - lum(nl.rgb)) * relief, -1.0, 1.0);
		}

		// Итоговая освещённость: -1 — тень, 0 — полутон, 1 — свет
		float light = toward * 0.9 - away + slope * 0.6;
		float shadow_w = smoothstep(-0.25, -0.25 - band_softness, light);
		float light_w = smoothstep(0.3, 0.3 + band_softness, light);

		// Впадины (пиксель темнее своих соседей) — ещё глубже
		float ao = min(clamp((lum(avg) - h) * 4.0 + (lum(avg_wide) - h) * 2.0, 0.0, 1.0) * crevice, 0.4);

		vec3 shaded = c * shadow_tint.rgb;
		vec3 lit = c * 1.15 + light_tint.rgb * 0.06;
		c = mix(c, shaded, shadow_w * shadow_strength);
		c = mix(c, lit, light_w * light_strength);
		c *= 1.0 - ao;

		// Ноги темнее головы
		vec2 local = fract(UV / (px * cell_px));
		c *= 1.0 - ground_shade * smoothstep(0.45, 0.78, local.y);

		// Мрачная палитра: сначала общая насыщенность, потом отдельно гасим
		// тёплое (красное заметно больше синего)
		// Металл (клинок, наконечники) холодный — его ниже не приглушаем как ткань
		float cloth_warm = smoothstep(-0.01, 0.05, c.r - c.b);
		float lm = lum(c);
		c = mix(vec3(lm), c, saturation);
		float warmth = clamp((c.r - c.b) * 2.5, 0.0, 1.0);
		c = mix(c, vec3(lum(c)), warmth * warm_desaturation);

		// Светлая ткань: яркая, но не металлическая — темнеет и сереет
		float lc = lum(c);
		float cloth = smoothstep(0.32, 0.6, lc) * (1.0 - smoothstep(0.8, 0.95, lc)) * cloth_warm;
		c = mix(c, c * cloth_tint.rgb * (1.0 - cloth_dim), cloth);

		// Полутона вниз по кривой, тонировка теней и светов
		c = pow(max(c, vec3(0.0)), vec3(value_gamma));
		float lg = lum(c);
		c *= mix(shadow_grade.rgb, highlight_grade.rgb, smoothstep(0.04, 0.55, lg));

		c = (c - 0.5) * contrast + 0.5;
		c *= brightness;
		c = max(c, shadow_floor.rgb);
		result = vec4(clamp(c, 0.0, 1.0), tex.a);
	}
	// Вшитая магия — в палитру мага, поверх тонировки (и на полупрозрачном,
	// вне "тела": шипы и осколки часто полупрозрачные)
	result.rgb = mix(result.rgb, magic.rgb, magic.a * magic_recolor);
	COLOR = result * modulate_color;
#ifdef HERO_LIT
	if (tex.a > 0.0) {
		NORMAL_MAP = hero_normal(TEXTURE, UV, px);
	}
#endif
}
