shader_type canvas_item;
// RF-340: fundo do menu — a arte da abertura desfocada, puxada pro azul-noite,
// com listras diagonais que andam devagar e vinheta nas bordas.

uniform float blur = 3.0;
uniform float dim = 0.5;
uniform vec3 tint : source_color = vec3(0.07, 0.08, 0.2);
uniform float aspect = 1.7778;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	vec3 c = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * px * 2.0).rgb;
		}
	}
	c /= 25.0;
	vec3 col = mix(c, tint, 0.5) * dim;
	float s = step(0.5, fract((UV.x * aspect + UV.y) * 7.0 - TIME * 0.12));
	col += vec3(1.0, 0.82, 0.3) * s * 0.022;
	float v = smoothstep(0.95, 0.25, distance(UV, vec2(0.5)));
	col *= mix(0.45, 1.0, v);
	COLOR = vec4(col, 1.0);
}
