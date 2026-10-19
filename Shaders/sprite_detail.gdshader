shader_type canvas_item;
// sprite_detail.gdshader — светотень на самой текстуре спрайта (Сигрид,
// Player_scene/sigrid_detail_material.tres). Исходные листы не меняются —
// всё считается попиксельно при отрисовке, на любом кадре любой анимации.
// Вокруг фигуры ничего не добавляется — только внутри неё, как рисуют
// светотень в пиксель-арте:
//   - объём от формы: у края к свету — светлая зона в 1-3 пикселя, у края
//     от света — тень, с плавным спадом внутрь;
//   - рельеф: складки и выступы ткани освещаются по яркости относительно
//     соседей (что ярче соседа со стороны света — выступ, темнее — впадина);
//   - углубления (складки, промежутки между ремнями) темнее;
//   - тени цветные — холоднее и чуть в фиолет, света — лунные; тени и света
//     ложатся ступенями, а не плавной заливкой;
//   - ноги темнее головы (свет сверху), мелкие детали резче.
// Запечённую полупрозрачную тень на земле не трогает: "телом" считается
// только почти непрозрачное (alpha >= body_alpha).

uniform float body_alpha : hint_range(0.0, 1.0) = 0.9;
// Откуда падает свет (по экрану, y вниз): по умолчанию сверху-слева
uniform vec2 light_dir = vec2(-0.55, -0.85);
uniform vec4 shadow_tint : source_color = vec4(0.6, 0.58, 0.78, 1.0);
uniform vec4 light_tint : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.55;
uniform float light_strength : hint_range(0.0, 1.0) = 0.45;
// Сколько рельефа брать из яркости соседей (складки, швы)
uniform float relief : hint_range(0.0, 8.0) = 3.0;
uniform float crevice : hint_range(0.0, 1.0) = 0.35;
// Ширина ступени между тенью, полутоном и светом (меньше — резче ступени)
uniform float band_softness : hint_range(0.01, 0.5) = 0.12;
uniform float ground_shade : hint_range(0.0, 1.0) = 0.16;
uniform float detail : hint_range(0.0, 2.0) = 0.5;
uniform float contrast : hint_range(0.5, 2.0) = 1.05;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;
// Общая яркость фигуры: светлая модель выделялась на тёмных ночных уровнях
uniform float brightness : hint_range(0.3, 1.5) = 0.8;
// Размер ячейки кадра в листе (кадры 128x128) — чтобы знать высоту внутри кадра
uniform float cell_px = 128.0;

// Цвет вершины (modulate спрайта — вспышки урона, свечение навыков). В
// fragment COLOR уже умножен на текстуру, поэтому берём его из vertex
varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

float body(sampler2D t, vec2 uv) {
	return step(body_alpha, texture(t, uv).a);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	vec4 result = tex;
	if (tex.a >= body_alpha) {
		vec3 c = tex.rgb;
		float h = lum(c);
		vec2 l = normalize(light_dir);

		// Соседи по телу: среднее (для резкости и впадин)
		vec3 sum = vec3(0.0);
		float cnt = 0.0;
		vec2 offs[4] = {vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y)};
		for (int i = 0; i < 4; i++) {
			vec4 n = texture(TEXTURE, UV + offs[i]);
			float b = step(body_alpha, n.a);
			sum += n.rgb * b;
			cnt += b;
		}
		vec3 avg = cnt > 0.0 ? sum / cnt : c;
		c += (c - avg) * detail;

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
		vec4 nl = texture(TEXTURE, UV + l * px);
		vec4 nd = texture(TEXTURE, UV - l * px);
		float slope = 0.0;
		if (nl.a >= body_alpha && nd.a >= body_alpha) {
			slope = clamp((lum(nd.rgb) - lum(nl.rgb)) * relief, -1.0, 1.0);
		}

		// Итоговая освещённость: -1 — тень, 0 — полутон, 1 — свет
		float light = toward * 0.9 - away + slope * 0.6;
		float shadow_w = smoothstep(-0.25, -0.25 - band_softness, light);
		float light_w = smoothstep(0.3, 0.3 + band_softness, light);

		// Впадины (пиксель темнее своих соседей) — ещё глубже
		float ao = clamp((lum(avg) - h) * 4.0, 0.0, 1.0) * crevice;

		vec3 shaded = c * shadow_tint.rgb;
		vec3 lit = c * 1.18 + light_tint.rgb * 0.07;
		c = mix(c, shaded, shadow_w * shadow_strength);
		c = mix(c, lit, light_w * light_strength);
		c *= 1.0 - ao;

		// Ноги темнее головы
		vec2 local = fract(UV / (px * cell_px));
		c *= 1.0 - ground_shade * smoothstep(0.45, 0.78, local.y);

		float lm = lum(c);
		c = mix(vec3(lm), c, saturation);
		c = (c - 0.5) * contrast + 0.5;
		c *= brightness;
		result = vec4(clamp(c, 0.0, 1.0), tex.a);
	}
	COLOR = result * modulate_color;
}
