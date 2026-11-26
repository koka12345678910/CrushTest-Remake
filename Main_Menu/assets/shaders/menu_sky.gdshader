shader_type canvas_item;

// Небо главного меню (Main_Menu/art/bg_sky.png). Облака плывут, горы и
// скала перед ними неподвижны:
//   - облака ДРЕЙФУЮТ по горизонтали без конца: текстура неба не бесшовная,
//     поэтому у слоя повтор «зеркалом» (texture_repeat = MIRROR в
//     MenuBackdrop.gd) — за правым краем идёт отражённая копия, шва нет;
//   - по вертикали — лёгкое покачивание (картинка чуть увеличена под него);
//   - по облакам ползут мягкие пятна света и тени (шумовая текстура);
//   - у горизонта (за хребтами) — светлая дымка: в жизни небо у земли
//     светлее, и дальние горы растворяются в нём; тёмное небо за светлыми
//     хребтами делало горы вклеенными (тот же цвет — haze_color в menu_mid);
//   - flash — молния где-то в облаках.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// Скорость дрейфа облаков (доли ширины неба в секунду)
uniform float drift = 0.0035;
// Амплитуда вертикального покачивания (и запас увеличения под неё)
uniform float sway = 0.012;
// Сила «ползущих» пятен света/тени
uniform float drift_shade = 0.16;
// Дымка у горизонта: цвет, высота (доли кадра), толщина, сила
uniform vec3 horizon_color : source_color = vec3(0.3, 0.35, 0.4);
uniform float horizon_y = 0.43;
uniform float horizon_width = 0.11;
uniform float horizon_strength = 0.75;
uniform float flash = 0.0;
// Прореха с луной — оттуда молния светит ярче (экранные координаты слоя)
uniform vec2 moon = vec2(0.12, 0.12);
uniform float aspect = 1.776;

void fragment() {
	float t = TIME;
	// По горизонтали — бесконечный дрейф (зеркальный повтор), по вертикали —
	// чуть увеличено и покачивается
	vec2 uv = UV;
	uv.y = (uv.y - 0.5) * (1.0 - 2.0 * sway) + 0.5 + sin(t * 0.013 + 1.3) * sway * 0.5;
	uv.x += t * drift;
	vec4 col = texture(TEXTURE, uv);

	// Облачные массы клубятся: два слоя шума, вытянутые по горизонтали
	vec2 p = vec2(UV.x * aspect, UV.y);
	float n1 = texture(noise_tex, p * vec2(0.45, 0.9) + vec2(t * 0.006, 0.0)).r;
	float n2 = texture(noise_tex, p * vec2(0.9, 1.7) + vec2(-t * 0.0065, t * 0.0012) + 0.37).r;
	float shade = (n1 * 0.6 + n2 * 0.4) - 0.5;
	col.rgb *= 1.0 + shade * drift_shade * 2.0;

	// Дымка у горизонта: светлая полоса за хребтами, вверх мягко гаснет,
	// вниз (за горами) держится — горы закрывают её сами
	float above = (horizon_y - UV.y) / horizon_width;
	float band = UV.y > horizon_y ? 1.0 : exp(-above * above);
	col.rgb = mix(col.rgb, horizon_color, band * horizon_strength);

	if (flash > 0.0) {
		float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
		float near_moon = 1.0 - smoothstep(0.0, 0.9, length((UV - moon) * vec2(aspect * 0.6, 1.0)));
		float cloud = 0.35 + lum * 2.2;
		col.rgb += flash * vec3(0.55, 0.6, 0.74) * cloud * (0.25 + 0.75 * near_moon);
	}
	COLOR = col;
}
