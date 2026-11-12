shader_type canvas_item;
// Pixel-art ground fog: two drifting noise layers, sampled on a 4px grid and quantised to a few levels.
uniform sampler2D noise_a : repeat_enable, filter_nearest;
uniform sampler2D noise_b : repeat_enable, filter_nearest;
uniform sampler2D mask : filter_linear;
uniform vec4 fog_color : source_color = vec4(0.58, 0.58, 0.60, 1.0);
uniform float density = 0.3;
uniform vec2 world_size = vec2(1024.0, 1024.0);
uniform float pixel = 4.0;

void fragment() {
	vec2 wp = floor(UV * world_size / pixel) * pixel;
	vec2 uv1 = wp / 1100.0 + vec2(TIME * 0.0045, TIME * 0.0015);
	vec2 uv2 = wp / 420.0 - vec2(TIME * 0.003, -TIME * 0.002);
	float n = texture(noise_a, uv1).r * 0.7 + texture(noise_b, uv2).r * 0.3;
	float a = smoothstep(0.38, 0.82, n);
	a = floor(a * 5.0) / 5.0 * density;
	a *= texture(mask, UV).r;
	COLOR = vec4(fog_color.rgb, a);
}
