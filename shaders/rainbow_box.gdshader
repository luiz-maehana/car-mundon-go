// Caixa de item com brilho arco-íris (RF-168). Valores > 1 acendem o bloom.
// RF-486: o "?" vem pintado em cada face (antes era um Label3D por caixa = 2 desenhos a mais).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D q_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float box_size = 1.4;

varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX / box_size;
	lnrm = NORMAL;
}

void fragment() {
	vec3 hue = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + TIME * 0.35 + (UV.x + UV.y) * 0.5));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 col = mix(hue * 0.9, vec3(1.6), fres * 0.7);
	float a = 0.55 + fres * 0.45;
	// UV da face pela posição local: nas laterais o "?" fica sempre em pé e sem espelhar
	vec3 an = abs(lnrm);
	vec2 fuv;
	if (an.y > 0.5) {
		fuv = vec2(0.5 + lpos.x, 0.5 + lpos.z * sign(lnrm.y));
	} else if (an.x > 0.5) {
		fuv = vec2(0.5 - lpos.z * sign(lnrm.x), 0.5 - lpos.y);
	} else {
		fuv = vec2(0.5 + lpos.x * sign(lnrm.z), 0.5 - lpos.y);
	}
	vec4 q = texture(q_tex, (fuv - 0.5) * 1.25 + 0.5);
	q.a *= step(abs(fuv.x - 0.5), 0.4) * step(abs(fuv.y - 0.5), 0.4);
	ALBEDO = mix(col, q.rgb * 1.3, q.a);
	ALPHA = mix(a, 1.0, q.a);
}
