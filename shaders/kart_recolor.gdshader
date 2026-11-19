// RF-170: recolore o kart do Kenney na cor do piloto.
// RF-475: quais texels pintar vem de uma máscara pronta (tools/make_kart_mask.gd), e não de uma conta
// de saturação aqui: a carroceria é um branco levemente lilás que só o Forward+ (espaço linear)
// enxergava como cor; no Compatibility (navegador) o kart saía branco.
shader_type spatial;

uniform sampler2D tex : source_color, filter_nearest;   // paleta do Kenney
uniform sampler2D mask : filter_nearest;                 // 1 = carroceria (pinta), 0 = mantém
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float m = texture(mask, UV).r;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 rc = tint.rgb * (0.4 + 0.8 * l);
	ALBEDO = mix(c, rc, m);
	ROUGHNESS = mix(0.55, 0.28, m);
	METALLIC = 0.15 * m;
	SPECULAR = 0.6;
}
