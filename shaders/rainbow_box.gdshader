// Caixa de item com brilho arco-íris (RF-168). Valores > 1 acendem o bloom.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;

void fragment() {
	vec3 hue = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + TIME * 0.35 + (UV.x + UV.y) * 0.5));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(hue * 0.9, vec3(1.6), fres * 0.7);
	ALPHA = 0.55 + fres * 0.45;
}
