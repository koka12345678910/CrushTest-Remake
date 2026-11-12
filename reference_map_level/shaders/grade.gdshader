shader_type canvas_item;
// Muted, dirty grade: pulls colours towards ash and rust, keeps fire-bright warm accents, darkens the edges.
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float desaturate = 0.38;
uniform vec3 tint = vec3(0.96, 0.92, 0.86);
uniform float vignette = 0.75;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float warm_bright = smoothstep(0.45, 0.8, l) * step(c.b * 1.6, c.r);
	c = mix(c, vec3(l), desaturate * (1.0 - warm_bright));
	c *= tint;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 1.3;
	COLOR = vec4(c, 1.0);
}
