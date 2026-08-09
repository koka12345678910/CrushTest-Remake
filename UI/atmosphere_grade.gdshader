shader_type canvas_item;

// Общая цветокоррекция уровня: частичная десатурация + контраст + холодный
// тон в тенях + виньетка по краям экрана. Работает поверх ВСЕЙ сцены —
// читает уже отрисованный кадр через screen_texture и перерисовывает его
// гаммированным. Сидит НИЖЕ (CanvasLayer.layer = 0) любых HUD-слоёв игрока,
// поэтому здоровье/стамину/быстрый слот не трогает — только мир.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float desaturation : hint_range(0.0, 1.0) = 0.35;
uniform float contrast : hint_range(0.5, 2.0) = 1.15;
uniform vec3 shadow_tint : source_color = vec3(0.82, 0.88, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.7;
uniform float vignette_softness : hint_range(0.01, 1.5) = 0.55;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;

	// Частичная десатурация — не полный ч/б, просто убираем часть "мультяшной"
	// сочности зелени/цвета, оставляя сцену узнаваемой
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturation);

	// Контраст вокруг серой точки — углубляет тени, поднимает света
	col = (col - 0.5) * contrast + 0.5;

	// Холодный тон в тенях: тёмные участки чуть смещаются к синему, а не
	// остаются нейтрально-серыми — классический приём "ночного" грейдинга
	col *= mix(shadow_tint, vec3(1.0), luma);

	// Виньетка — коррекция аспекта, чтобы круг был кругом, а не овалом
	vec2 uv = SCREEN_UV - vec2(0.5);
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(uv);
	float vig = 1.0 - smoothstep(vignette_radius - vignette_softness, vignette_radius, dist);
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
