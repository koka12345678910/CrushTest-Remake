shader_type canvas_item;
render_mode unshaded;
// juice_overlay.gdshader — экранный слой "сочности" (VFX/juice.gd). Читает
// уже нарисованный кадр и на мгновения удара:
//   - flash — короткая вспышка (молния, добивание);
//   - vignette — тёмные края экрана, стягивают взгляд к центру;
//   - desat — кадр уходит в серость (замедление на последнем убийстве);
//   - aberration — цвета чуть расслаиваются от центра (миг сильного удара).
// Все величины 0 — слой прозрачен и ничего не меняет.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.8, 0.88, 1.0, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.0, 0.01, 1.0);
uniform float desat : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	// Расслоение — красный и синий каналы чуть разъезжаются от центра
	vec2 ab = c * aberration * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - ab).b;
	// Серость, кроме самых ярких точек (кровь, огонь, искры остаются цветными)
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	float keep = smoothstep(0.55, 0.9, max(col.r, max(col.g, col.b)) - l + l * 0.6);
	col = mix(col, vec3(l), desat * (1.0 - keep * 0.6));
	// Виньетка — по эллипсу экрана
	float v = smoothstep(0.35, 0.95, length(c * vec2(1.25, 1.0)) * 1.4);
	col = mix(col, vignette_color.rgb, v * vignette);
	col += flash_color.rgb * flash;
	COLOR = vec4(col, 1.0);
}
