// Rosto redondo sempre virado pra câmera (funciona por câmera na tela dividida).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D face : source_color, filter_linear_mipmap;
uniform vec4 ring : source_color = vec4(1.0);
uniform vec2 center = vec2(0.5, 0.45);
uniform float zoom = 0.62;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	if (r > 0.5) {
		discard;
	}
	vec3 c = texture(face, center + d * zoom).rgb;
	ALBEDO = mix(c, ring.rgb, smoothstep(0.42, 0.44, r));
}
