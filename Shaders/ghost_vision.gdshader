shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 3.0) = 1.6;
uniform vec4 tint : source_color = vec4(0.85, 0.1, 0.08, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.2;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	float gray = dot(scene.rgb, vec3(0.299, 0.587, 0.114));
	gray = clamp((gray - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 mono = mix(vec3(gray), tint.rgb * gray, tint_amount);

	vec2 uv = SCREEN_UV - 0.5;
	float vignette = 1.0 - smoothstep(0.3, 0.75, length(uv) * vignette_strength);
	vec3 result = mono * mix(0.6, 1.0, vignette);

	vec3 final_color = mix(scene.rgb, result, intensity);
	final_color = mix(final_color, vec3(1.0), flash);
	COLOR = vec4(final_color, 1.0);
}
