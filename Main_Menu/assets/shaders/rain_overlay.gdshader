// rain_overlay.gdshader
// Шейдер дождя на весь экран — более кинематографичный вариант
// чем частицы. Можно использовать вместо GPUParticles2D
// или вместе с ним для большей плотности.
//
// Использование: назначь на ColorRect на весь экран,
// установи modulate.a = 0.3–0.5

shader_type canvas_item;

uniform float speed : hint_range(0.2, 3.0) = 1.0;
uniform float density : hint_range(0.1, 2.0) = 0.8;
uniform float angle : hint_range(-0.5, 0.5) = -0.15;
uniform vec4 rain_color : source_color = vec4(0.65, 0.72, 0.85, 1.0);
uniform float drop_length : hint_range(0.01, 0.2) = 0.06;
uniform float drop_width : hint_range(0.001, 0.02) = 0.004;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 screen_uv = uv;

	// Сдвиг UV с учётом наклона дождя
	uv.x += uv.y * angle;

	// Разбиваем экран на колонки
	float col_count = 60.0 * density;
	float col = floor(uv.x * col_count);
	float col_uv = fract(uv.x * col_count);

	// Каждая колонка имеет свою скорость и смещение
	float col_rand = rand(vec2(col, 0.0));
	float col_speed = speed * (0.6 + col_rand * 0.8);
	float col_offset = rand(vec2(col, 1.0));

	// Движение вниз по времени
	float t = TIME * col_speed + col_offset * 10.0;
	float drop_y = fract(t);

	// Позиция капли в колонке
	float drop_row = floor(t);
	float drop_x_offset = rand(vec2(col, drop_row + 3.0)) - 0.5;

	// Проверяем попадание пикселя в каплю
	float dx = abs(col_uv - 0.5 + drop_x_offset * 0.3);
	float dy = screen_uv.y - drop_y;

	// Капля: узкая по X, вытянутая по Y
	float in_drop = step(dx, drop_width) * step(dy, 0.0) * step(-drop_length, dy);

	// Мерцание яркости
	float brightness = 0.6 + rand(vec2(col, floor(t * 3.0))) * 0.4;

	vec4 col_color = rain_color * in_drop * brightness;

	// Второй слой — более мелкие редкие капли на дальнем плане
	float col2 = floor(uv.x * col_count * 1.7 + 0.5);
	float t2 = TIME * speed * 0.5 + rand(vec2(col2, 0.0)) * 8.0;
	float drop_y2 = fract(t2);
	float dx2 = abs(fract(uv.x * col_count * 1.7) - 0.5);
	float in_drop2 = step(dx2, drop_width * 0.6) * step(screen_uv.y - drop_y2, 0.0)
		* step(-(drop_length * 0.5), screen_uv.y - drop_y2);

	col_color += rain_color * in_drop2 * 0.35;

	COLOR = col_color;
}
