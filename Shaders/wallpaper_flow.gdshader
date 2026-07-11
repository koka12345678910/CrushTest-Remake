shader_type canvas_item;

// Непрерывное "дыхание" картинки — лёгкое жидкое искажение, как в живых
// обоях Wallpaper Engine. Плюс параллакс-смещение от мыши (задаётся из кода).

uniform float warp_strength : hint_range(0.0, 0.05) = 0.006;
uniform float warp_speed : hint_range(0.0, 2.0) = 0.35;
uniform vec2 parallax_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * warp_speed;

	vec2 warp;
	warp.x = sin(uv.y * 6.0 + t) * warp_strength
		+ sin(uv.y * 13.0 - t * 1.7) * warp_strength * 0.5;
	warp.y = cos(uv.x * 7.0 + t * 1.3) * warp_strength
		+ cos(uv.x * 11.0 - t * 0.8) * warp_strength * 0.5;

	uv += warp;
	uv += parallax_offset;

	COLOR = texture(TEXTURE, uv);
}
