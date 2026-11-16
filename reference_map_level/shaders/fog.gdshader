shader_type canvas_item;
// Ground fog: two drifting noise layers. pixel > 0 — pixel-art look (sampled on
// a pixel grid and quantised to a few levels); pixel = 0 — smooth (immersion.gd
// switches the map fog to smooth at runtime).
uniform sampler2D noise_a : repeat_enable, filter_linear;
uniform sampler2D noise_b : repeat_enable, filter_linear;
uniform sampler2D mask : filter_linear;
uniform vec4 fog_color : source_color = vec4(0.58, 0.58, 0.60, 1.0);
uniform float density = 0.3;
uniform vec2 world_size = vec2(1024.0, 1024.0);
uniform float pixel = 4.0;

void fragment() {
	vec2 wp = UV * world_size;
	if (pixel > 0.5) {
		wp = floor(wp / pixel) * pixel;
	}
	vec2 uv1 = wp / 1100.0 + vec2(TIME * 0.0045, TIME * 0.0015);
	vec2 uv2 = wp / 420.0 - vec2(TIME * 0.003, -TIME * 0.002);
	float n = texture(noise_a, uv1).r * 0.7 + texture(noise_b, uv2).r * 0.3;
	float a = smoothstep(0.38, 0.82, n);
	if (pixel > 0.5) {
		a = floor(a * 5.0) / 5.0;
	} else {
		// Как ступени выше в среднем: слабые места чистые, без сплошной дымки
		a = max(a - 0.15, 0.0) * 1.15;
	}
	a *= density * texture(mask, UV).r;
	COLOR = vec4(fog_color.rgb, a);
}
