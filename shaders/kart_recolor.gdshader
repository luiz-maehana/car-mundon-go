// RF-170: recolore o kart do Kenney na cor do piloto.
// Pinta só os texels saturados da paleta (a carroceria colorida); branco/cinza ficam como estão.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float m = smoothstep(0.18, 0.32, sat);
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 rc = tint.rgb * (0.4 + 0.8 * l);
	ALBEDO = mix(c, rc, m);
	ROUGHNESS = mix(0.55, 0.28, m);
	METALLIC = 0.15 * m;
	SPECULAR = 0.6;
}
