// Linhas de velocidade radiais durante o turbo (RF-166).
shader_type canvas_item;

uniform float intensity = 0.0;
uniform float aspect = 1.777;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float a = atan(p.y, p.x);
	float r = length(p);
	float bins = 110.0;
	float t = (a + PI) / TAU * bins;
	float id = floor(t);
	float h = hash(id * 1.37 + floor(TIME * 14.0) * 17.0);
	float w = fract(t);
	float line = step(0.6, h) * smoothstep(0.32, 0.85, r) * smoothstep(0.0, 0.35, w) * smoothstep(1.0, 0.65, w);
	COLOR = vec4(1.0, 1.0, 1.0, line * intensity * 0.45);
}
