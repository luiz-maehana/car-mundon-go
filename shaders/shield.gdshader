// RF-203: bolha do escudo — transparente no meio, brilho só na borda (fresnel).
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	ALBEDO = vec3(1.0, 0.78, 0.25) * f * 1.3 * pulse;
	ALPHA = f;
}
