shader_type canvas_item;
// Клубящийся туман по маске: пропасть, вода, болото. Два слоя шума ползут в
// разные стороны, на стыке — медленные завихрения. Маска — мягкая картинка
// поверх прямоугольника area (мировые px). Узлы — immersion.gd (_build_mist).

uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D mask : filter_linear;
uniform vec4 area = vec4(0.0, 0.0, 1024.0, 1024.0);
uniform vec4 mist_color : source_color = vec4(0.62, 0.66, 0.72, 1.0);
uniform float density = 0.5;
// Размер клубов (мировые px) и скорость
uniform float scale = 520.0;
uniform vec2 drift = vec2(7.0, -2.0);
// Порог и мягкость: выше порог — больше просветов
uniform float threshold = 0.42;
uniform float softness = 0.3;
// Ровная дымка под клубами (доля), чтобы между ними не зияло
uniform float base = 0.0;
// Вытянутость клубов: меньше по x — длинные горизонтальные пряди
uniform vec2 stretch = vec2(0.65, 1.35);

// Глубина: 1 — на уровне земли, меньше — слой ниже и при беге отстаёт.
// cam_pos каждый кадр пишет immersion.gd
uniform float parallax = 1.0;
uniform vec2 cam_pos = vec2(0.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 muv = (world_pos - area.xy) / area.zw;
	float m = texture(mask, muv).r;
	if (m < 0.003) {
		discard;
	}
	float t = TIME;
	vec2 deep = cam_pos + (world_pos - cam_pos) / parallax;
	vec2 p = deep / scale * stretch;
	// Завихрение: второй слой сдвигает выборку первого
	vec2 warp = vec2(texture(noise, p * 0.7 + vec2(t * 0.011, -t * 0.007)).r,
		texture(noise, p * 0.7 + vec2(0.5, 0.3) - vec2(t * 0.009, t * 0.012)).r) - 0.5;
	float n1 = texture(noise, p + warp * 0.6 + drift * t / scale).r;
	float n2 = texture(noise, p * 2.3 - drift * t * 1.6 / scale + vec2(0.21, 0.67)).r;
	float n = n1 * 0.7 + n2 * 0.3;
	float a = mix(base, 1.0, smoothstep(threshold - softness * 0.5, threshold + softness * 0.5, n));
	COLOR = vec4(mist_color.rgb, a * m * density * mist_color.a);
}
