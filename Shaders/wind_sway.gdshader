shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 20.0) = 3.0;
uniform float speed : hint_range(0.0, 10.0) = 2.0;
uniform float wind_dir : hint_range(-1.0, 1.0) = 1.0;
uniform float variation : hint_range(0.0, 1.0) = 0.02;

void vertex() {
	float phase = TIME * speed + (VERTEX.x + VERTEX.y) * variation;
	float sway = sin(phase) * amplitude * (1.0 - UV.y);
	VERTEX.x += sway * wind_dir;
}
