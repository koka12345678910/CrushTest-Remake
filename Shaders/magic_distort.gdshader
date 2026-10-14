shader_type canvas_item;
render_mode unshaded;
// Искажение воздуха по фронту ударной волны (импульс мага, взрыв шара):
// картинка под гребнем чуть выпирает наружу, как линза. Читает уже
// нарисованный кадр (screen texture), поэтому рисуется поверх мира.
// Квадрат, центр — точка удара; по вертикали узел может быть сплюснут.
//
// Выборка — без мипмапов (иначе подставлялся размытый и потемневший кадр и
// по кругу шла тёмная полоса), прозрачность — по профилю гребня: края слоя
// незаметно сливаются с исходной картинкой.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float width = 0.12;
// Сила сдвига в долях экрана
uniform float strength = 0.01;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float front = progress * 0.95;
	float d = r - front;
	// Гладкий горб: максимум на гребне, плавно в ноль по обе стороны
	float ring = 1.0 - smoothstep(0.0, width, abs(d));
	ring = ring * ring * (3.0 - 2.0 * ring);
	ring *= 1.0 - smoothstep(0.9, 1.0, r);
	vec2 dir = r > 0.001 ? p / r : vec2(0.0);
	vec2 off = dir * ring * strength * fade;
	vec3 col = texture(screen_tex, SCREEN_UV - off).rgb;
	// Лёгкий холодный отсвет на самом гребне
	col += vec3(0.04, 0.08, 0.18) * ring * fade;
	COLOR = vec4(col, ring * fade);
}
