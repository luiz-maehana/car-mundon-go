// Céu procedural (RF-163): gradiente, sol/lua com halo, nuvens fbm animadas e estrelas.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.25, 0.5, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.82, 0.95);
uniform vec3 ground_color : source_color = vec3(0.3, 0.4, 0.3);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float cloud_amount = 0.5;
uniform float stars = 0.0;
uniform float sun_size = 700.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(s, sun_size) * 6.0 + pow(s, 12.0) * 0.18);
	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.08) * 0.9 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv);
		float c = smoothstep(0.62 - cloud_amount * 0.3, 0.92 - cloud_amount * 0.2, n);
		vec3 lit = cloud_color * (0.85 + 0.25 * fbm(uv * 1.7 + 3.0));
		col = mix(col, lit, c * clamp(h * 6.0, 0.0, 1.0) * 0.9);
		if (stars > 0.5) {
			vec2 g = floor(d.xz / (h + 0.25) * 260.0);
			float r = hash(g);
			float tw = 0.6 + 0.4 * sin(TIME * 3.0 + r * 50.0);
			col += vec3(step(0.9965, r)) * clamp(h * 3.0, 0.0, 1.0) * tw * 1.4;
		}
	}
	COLOR = col;
}
