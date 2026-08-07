shader_type canvas_item;

// Красная виньетка по краям экрана — вспыхивает при получении урона
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.55, 0.0, 0.0, 1.0);
uniform float radius : hint_range(0.0, 1.5) = 0.6;
uniform float softness : hint_range(0.01, 1.5) = 0.65;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// коррекция аспекта, чтобы виньетка была круглой, а не овальной
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(uv);
	float vignette = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * vignette * strength);
}
