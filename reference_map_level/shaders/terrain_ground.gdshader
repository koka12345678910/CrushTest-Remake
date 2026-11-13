shader_type canvas_item;
// Новая земля reference_map поверх старых тайлов (tools/build_terrain.gd).
//
// Слой рисует свои тайлы как раньше, но там, где в атласе была «листва» или
// грязь (маска атласа), цвет заменяется землёй из присланного набора,
// уложенной в мировых координатах: стыков клеток нет, рисунок един по всей
// карте. Мостовая, ямы, вода и прочее из атласа остаются.
//
// Пиксель-арт: всё считается на сетке «арт-пикселей» (pixel_size мировых px),
// плитки без сглаживания, с ограниченной палитрой (её делает build_terrain.gd),
// и вместо полупрозрачного смешивания каждый пиксель берёт цвет одной
// плитки — по «высоте» рисунка. Переходы трава/земля получаются рваными
// по пикселям, а не размытыми.
//
// Слои ground_layers: 0 грязь, 1 грязь с галькой, 2 грязь с камнями,
// 3 крупные камни, 4 редкая трава, 5 трава пятнами, 6 трава, 7/8 густая.

uniform sampler2DArray ground_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_medieval : filter_linear;
uniform sampler2D mask_reskin : filter_linear;
uniform sampler2D mask_canyon : filter_linear;
uniform sampler2D wear_map : filter_linear;
uniform vec4 wear_rect = vec4(-3520.0, -704.0, 8640.0, 5120.0);
// Тропинки (tools/forest_paths.gd): 1 — середина тропы
uniform sampler2D path_map : filter_linear;
uniform vec4 path_rect = vec4(-3520.0, -704.0, 8640.0, 5120.0);
// Размер арт-пикселя в мировых px: 0 — полная детализация без пиксельной
// сетки (плитки 256 px), 1 — пиксель-арт (плитки 112 px, build_terrain PIXEL_GROUND)
uniform float pixel_size = 0.0;
uniform float tile_world = 112.0;
uniform float brightness = 0.82;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
// +: больше травы, -: больше голой земли
uniform float grass_bias = 0.0;
// Тропа: насколько светлее земли вокруг и её оттенок
uniform float path_light = 0.38;
uniform vec3 path_tint : source_color = vec3(1.08, 0.96, 0.8);

varying vec2 world_pos;
varying vec4 vert_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vert_color = COLOR;
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

// «Высота» пикселя: трава и светлые камни сверху
float height_of(vec3 c) {
	return clamp(lum(c) * 1.4 + (c.g - c.b) * 2.0, 0.0, 1.0);
}

// Плитка без видимого повтора: треугольная сетка, в каждой вершине своя
// случайная подвижка плитки (на целое число пикселей); из трёх выборок
// берётся одна — где рисунок «выше». Цвет остаётся из палитры плитки.
vec4 hex_sample(vec2 uv, float layer, vec2 ddx, vec2 ddy) {
	vec2 g = uv * 2.2;
	vec2 s = vec2(g.x - 0.57735027 * g.y, 1.15470054 * g.y);
	vec2 base = floor(s);
	vec2 f = fract(s);
	float z = 1.0 - f.x - f.y;
	vec3 w;
	vec2 v1;
	vec2 v2;
	vec2 v3;
	if (z > 0.0) {
		w = vec3(z, f.y, f.x);
		v1 = base;
		v2 = base + vec2(0.0, 1.0);
		v3 = base + vec2(1.0, 0.0);
	} else {
		w = vec3(-z, 1.0 - f.y, 1.0 - f.x);
		v1 = base + vec2(1.0, 1.0);
		v2 = base + vec2(1.0, 0.0);
		v3 = base + vec2(0.0, 1.0);
	}
	float n = pixel_size > 0.0 ? tile_world / pixel_size : 65536.0;
	vec4 c1 = textureGrad(ground_layers, vec3(uv + floor(hash22(v1 + layer * 13.1) * n) / n, layer), ddx, ddy);
	vec4 c2 = textureGrad(ground_layers, vec3(uv + floor(hash22(v2 + layer * 13.1) * n) / n, layer), ddx, ddy);
	vec4 c3 = textureGrad(ground_layers, vec3(uv + floor(hash22(v3 + layer * 13.1) * n) / n, layer), ddx, ddy);
	vec3 h = vec3(lum(c1.rgb), lum(c2.rgb), lum(c3.rgb));
	w = w * (0.55 + h * 1.8);
	if (w.x >= w.y && w.x >= w.z) {
		return c1;
	}
	return w.y >= w.z ? c2 : c3;
}

// Выбор между двумя землями по высоте: на переходе трава прорастает
// сквозь грязь отдельными пикселями
vec4 hpick(vec4 a, vec4 b, float t) {
	float ha = height_of(a.rgb) + (1.0 - t);
	float hb = height_of(b.rgb) + t;
	return ha >= hb ? a : b;
}

vec4 level_color(int lv, vec2 uv, vec2 ddx, vec2 ddy, float nv, float rocky) {
	if (lv <= 0) {
		float t = smoothstep(0.4, 0.6, nv);
		vec4 d;
		if (t < 0.01) {
			d = hex_sample(uv, 0.0, ddx, ddy);
		} else if (t > 0.99) {
			d = hex_sample(uv, 1.0, ddx, ddy);
		} else {
			d = hpick(hex_sample(uv, 0.0, ddx, ddy), hex_sample(uv, 1.0, ddx, ddy), t);
		}
		if (rocky > 0.01) {
			d = hpick(d, hex_sample(uv, 2.0, ddx, ddy), rocky);
		}
		return d;
	}
	if (lv >= 4) {
		float t = smoothstep(0.4, 0.6, nv);
		if (t < 0.01) {
			return hex_sample(uv, 7.0, ddx, ddy);
		} else if (t > 0.99) {
			return hex_sample(uv, 8.0, ddx, ddy);
		}
		return hpick(hex_sample(uv, 7.0, ddx, ddy), hex_sample(uv, 8.0, ddx, ddy), t);
	}
	return hex_sample(uv, float(lv + 3), ddx, ddy);
}

void fragment() {
	vec4 orig = COLOR;
	// Центр арт-пикселя: всё ниже одинаково для всех точек экрана внутри него
	vec2 wp = pixel_size > 0.0 ? (floor(world_pos / pixel_size) + 0.5) * pixel_size : world_pos;
	vec2 uv = wp / tile_world;
	// Производные — по непрерывным координатам (у ступенчатых они рваные)
	vec2 ddx = dFdx(world_pos / tile_world);
	vec2 ddy = dFdy(world_pos / tile_world);

	// Тропа: R — тропа, G — «вне города», B — узкая старая каменная дорожка
	// в лесу (тоже становится земляной тропой). Край рваный по пикселям
	vec3 pm = texture(path_map, (wp - path_rect.xy) / path_rect.zw).rgb;
	float p = max(pm.r, pm.b);
	float jag = hash22(floor(world_pos) * 0.731 + 5.3).x - 0.5;
	float on_path = step(0.5, p + jag * 0.45);
	// Кромка тропы: узкая полоса вокруг неё — темнее (читается и издалека)
	float rim = step(0.22, p + jag * 0.45) * (1.0 - on_path);

	vec2 ts = 1.0 / TEXTURE_PIXEL_SIZE;
	float m = 0.0;
	if (abs(ts.x - 1024.0) < 0.5 && abs(ts.y - 8192.0) < 0.5) {
		m = texture(mask_medieval, UV).r;
	} else if (abs(ts.x - 4096.0) < 0.5 && abs(ts.y - 7424.0) < 0.5) {
		m = texture(mask_reskin, UV).r;
		// Старые каменные дорожки в лесу (мостовая — ряды клеток 48..71 и юг 184+
		// атласа) под тропой становятся землёй; в городе камень остаётся
		// Юг (184+) — только найденные узкие дорожки (B): вдоль провала
		// маршруты идут рядом с его каменной кромкой, её не трогаем
		float row = UV.y * 7424.0 / 32.0;
		float trail = step(0.22, pm.b + jag * 0.45);
		bool cobble_row = row >= 48.0 && row < 72.0;
		bool south_row = row >= 184.0;
		if (pm.g > 0.5 && lum(orig.rgb) > 0.09
				&& ((cobble_row && on_path + rim > 0.5) || (south_row && trail > 0.5))) {
			m = 1.0;
		}
	} else if (abs(ts.x - 3008.0) < 0.5 && abs(ts.y - 4736.0) < 0.5) {
		m = texture(mask_canyon, UV).r;
	}

	if (m > 0.5) {
		// R — вытоптанность, G/B/A — запечённые шумы (см. build_terrain.gd, шаг wear)
		vec4 wm = texture(wear_map, (wp - wear_rect.xy) / wear_rect.zw);
		float wear = wm.r;
		float n1 = wm.g;
		float n2 = wm.b;
		float n3 = wm.a;
		// Трава: крупные пятна шумом, у дорог, домов и на тропах — вытоптано
		float g = clamp((n1 - 0.5) * 2.4 + 0.62 + grass_bias - wear * 1.15 - p * 0.9, 0.0, 1.0);
		g *= 1.0 - on_path;
		float rocky = smoothstep(0.5, 0.85, wear) * smoothstep(0.5, 0.72, n3) * 0.85;
		rocky *= 1.0 - on_path * 0.7;
		float L = g * 4.0;
		int i0 = int(min(floor(L), 3.0));
		float t = L - float(i0);
		vec4 terr;
		if (t < 0.02) {
			terr = level_color(i0, uv, ddx, ddy, n2, rocky);
		} else if (t > 0.98) {
			terr = level_color(i0 + 1, uv, ddx, ddy, n2, rocky);
		} else {
			terr = hpick(level_color(i0, uv, ddx, ddy, n2, rocky),
					level_color(i0 + 1, uv, ddx, ddy, n2, rocky), t);
		}
		// Неровность освещения крупными пятнами. Тропа — светлая тёплая
		// утоптанная земля, кромка вокруг — темнее: дорожка видна издалека
		float shade = (0.88 + 0.24 * n3) * (1.0 + on_path * path_light) * (1.0 - rim * 0.22);
		vec3 tone = mix(tint, path_tint, on_path);
		COLOR.rgb = terr.rgb * tone * brightness * shade * vert_color.rgb;
	}
}
