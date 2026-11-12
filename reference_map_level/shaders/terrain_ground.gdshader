shader_type canvas_item;
// Новая земля reference_map поверх старых тайлов (tools/build_terrain.gd).
//
// Слой рисует свои тайлы как раньше, но там, где в атласе была «листва» или
// грязь (маска атласа), цвет заменяется землёй из присланного набора,
// уложенной в мировых координатах: стыков клеток нет, рисунок един по всей
// карте. Мостовая, ямы, вода и прочее из атласа остаются.
//
// Слои ground_layers: 0 грязь, 1 грязь с галькой, 2 грязь с камнями,
// 3 крупные камни, 4 редкая трава, 5 трава пятнами, 6 трава, 7/8 густая.

uniform sampler2DArray ground_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_medieval : filter_linear;
uniform sampler2D mask_reskin : filter_linear;
uniform sampler2D mask_canyon : filter_linear;
uniform sampler2D wear_map : filter_linear;
uniform vec4 wear_rect = vec4(-3520.0, -704.0, 8640.0, 5120.0);
// Сколько мировых px занимает одна плитка набора
uniform float tile_world = 112.0;
uniform float brightness = 0.82;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
// +: больше травы, -: больше голой земли
uniform float grass_bias = 0.0;

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

// «Высота» тексела для смешивания: трава и светлые камни сверху
float height_of(vec3 c) {
	return clamp(lum(c) * 1.4 + (c.g - c.b) * 2.0, 0.0, 1.0);
}

// Плитка без видимого повтора: треугольная сетка, в каждой вершине своя
// случайная подвижка плитки, три выборки смешиваются по весам с упором
// на более яркий рисунок (травинка поверх травинки, а не двоение).
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
	vec4 c1 = textureGrad(ground_layers, vec3(uv + hash22(v1 + layer * 13.1), layer), ddx, ddy);
	vec4 c2 = textureGrad(ground_layers, vec3(uv + hash22(v2 + layer * 13.1), layer), ddx, ddy);
	vec4 c3 = textureGrad(ground_layers, vec3(uv + hash22(v3 + layer * 13.1), layer), ddx, ddy);
	vec3 h = vec3(lum(c1.rgb), lum(c2.rgb), lum(c3.rgb));
	w = w * (0.55 + h * 1.8);
	w = pow(w, vec3(10.0));
	w /= (w.x + w.y + w.z);
	return c1 * w.x + c2 * w.y + c3 * w.z;
}

// Смесь двух земель по высоте: на переходе трава прорастает сквозь грязь
vec4 hblend(vec4 a, vec4 b, float t) {
	float ha = height_of(a.rgb) + (1.0 - t);
	float hb = height_of(b.rgb) + t;
	float m = max(ha, hb) - 0.12;
	float wa = max(ha - m, 0.0);
	float wb = max(hb - m, 0.0);
	return (a * wa + b * wb) / (wa + wb);
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
			d = hblend(hex_sample(uv, 0.0, ddx, ddy), hex_sample(uv, 1.0, ddx, ddy), t);
		}
		if (rocky > 0.01) {
			d = hblend(d, hex_sample(uv, 2.0, ddx, ddy), rocky);
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
		return hblend(hex_sample(uv, 7.0, ddx, ddy), hex_sample(uv, 8.0, ddx, ddy), t);
	}
	return hex_sample(uv, float(lv + 3), ddx, ddy);
}

void fragment() {
	vec4 orig = COLOR;
	vec2 uv = world_pos / tile_world;
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);

	vec2 ts = 1.0 / TEXTURE_PIXEL_SIZE;
	float m = 0.0;
	if (abs(ts.x - 1024.0) < 0.5 && abs(ts.y - 8192.0) < 0.5) {
		m = texture(mask_medieval, UV).r;
	} else if (abs(ts.x - 4096.0) < 0.5 && abs(ts.y - 7424.0) < 0.5) {
		m = texture(mask_reskin, UV).r;
	} else if (abs(ts.x - 3008.0) < 0.5 && abs(ts.y - 4736.0) < 0.5) {
		m = texture(mask_canyon, UV).r;
	}

	if (m > 0.004) {
		// R — вытоптанность, G/B/A — запечённые шумы (см. build_terrain.gd, шаг wear)
		vec4 wm = texture(wear_map, (world_pos - wear_rect.xy) / wear_rect.zw);
		float wear = wm.r;
		float n1 = wm.g;
		float n2 = wm.b;
		float n3 = wm.a;
		// Трава: крупные пятна шумом, у дорог и домов — вытоптано
		float g = clamp((n1 - 0.5) * 2.4 + 0.62 + grass_bias - wear * 1.15, 0.0, 1.0);
		float rocky = smoothstep(0.5, 0.85, wear) * smoothstep(0.5, 0.72, n3) * 0.85;
		float L = g * 4.0;
		int i0 = int(min(floor(L), 3.0));
		float t = L - float(i0);
		vec4 terr;
		if (t < 0.02) {
			terr = level_color(i0, uv, ddx, ddy, n2, rocky);
		} else if (t > 0.98) {
			terr = level_color(i0 + 1, uv, ddx, ddy, n2, rocky);
		} else {
			terr = hblend(level_color(i0, uv, ddx, ddy, n2, rocky),
					level_color(i0 + 1, uv, ddx, ddy, n2, rocky), t);
		}
		// Лёгкая неровность освещения крупными пятнами, чтобы поле не было плоским
		float shade = 0.88 + 0.24 * n3;
		vec3 c = terr.rgb * tint * brightness * shade * vert_color.rgb;
		COLOR.rgb = mix(orig.rgb, c, m);
	}
}
