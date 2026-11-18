// Rosto redondo para a interface (TextureRect).
shader_type canvas_item;

uniform vec4 ring : source_color = vec4(1.0);
uniform vec2 center = vec2(0.5, 0.45);
uniform float zoom = 0.62;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec4 c = texture(TEXTURE, center + d * zoom);
	float a = 1.0 - smoothstep(0.48, 0.5, r);
	COLOR = vec4(mix(c.rgb, ring.rgb, smoothstep(0.42, 0.45, r)), a);
}
