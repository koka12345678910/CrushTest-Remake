shader_type canvas_item;

// Небо главного меню (Main_Menu/art/bg_sky.png). Облака живут сами по себе,
// горы и скала перед ними неподвижны:
//   - картинка чуть увеличена и очень медленно покачивается (запас по краям
//     sway — края листа никогда не видны);
//   - по облакам ползут мягкие пятна света и тени (шумовая текстура), будто
//     облачные массы смещаются;
//   - flash — молния где-то в облаках: свет рассеивается внутри них,
//     сильнее у прорехи с луной (слева вверху) и у самих облаков, а не
//     ровной заливкой.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// Амплитуда покачивания в долях кадра (и запас увеличения под неё)
uniform float sway = 0.014;
// Сила «ползущих» пятен света/тени
uniform float drift_shade = 0.16;
uniform float flash = 0.0;
// Прореха с луной на bg_sky.png — оттуда молния светит ярче
uniform vec2 moon = vec2(0.12, 0.12);
uniform float aspect = 1.776;

void fragment() {
	float t = TIME;
	vec2 uv = (UV - 0.5) * (1.0 - 2.0 * sway) + 0.5;
	uv += vec2(sin(t * 0.021) * sway, sin(t * 0.013 + 1.3) * sway * 0.35);
	vec4 col = texture(TEXTURE, uv);

	// Облачные массы смещаются: два слоя шума, вытянутые по горизонтали
	vec2 p = vec2(UV.x * aspect, UV.y);
	float n1 = texture(noise_tex, p * vec2(0.45, 0.9) + vec2(t * 0.004, 0.0)).r;
	float n2 = texture(noise_tex, p * vec2(0.9, 1.7) + vec2(-t * 0.0065, t * 0.0012) + 0.37).r;
	float shade = (n1 * 0.6 + n2 * 0.4) - 0.5;
	col.rgb *= 1.0 + shade * drift_shade * 2.0;

	if (flash > 0.0) {
		float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
		float near_moon = 1.0 - smoothstep(0.0, 0.9, length((UV - moon) * vec2(aspect * 0.6, 1.0)));
		float cloud = 0.35 + lum * 2.2;
		col.rgb += flash * vec3(0.55, 0.6, 0.74) * cloud * (0.25 + 0.75 * near_moon);
	}
	COLOR = col;
}
