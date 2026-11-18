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

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Uma camada de estrelas: célula 3D na direção do olhar, estrela em posição aleatória
// dentro da célula e só em parte das células (a chance varia pelo céu).
float star_layer(vec3 sd, float scale, float base_chance, float density, float size) {
	vec3 p = sd * scale;
	vec3 cell = floor(p);
	vec3 f = fract(p);
	if (hash3(cell) > base_chance * density) {
		return 0.0;
	}
	vec3 c = vec3(hash3(cell + 1.7), hash3(cell + 3.1), hash3(cell + 5.3)) * 0.7 + 0.15;
	float dist = length(f - c);
	float b = pow(hash3(cell + 9.1), 4.0);  // quase todas fracas, poucas fortes
	float tw = 1.0;
	if (hash3(cell + 12.7) > 0.8) {         // só ~20% piscam
		tw = 0.55 + 0.45 * sin(TIME * (2.0 + hash3(cell + 4.4) * 3.0) + hash3(cell) * 40.0);
	}
	return smoothstep(size, 0.0, dist) * (0.25 + 2.2 * b) * tw;
}

vec3 star_field(vec3 sd, float h) {
	// aglomerados e vazios + uma faixa de "via láctea"
	float clumps = smoothstep(0.35, 0.8, fbm(sd.xz * 2.2 + sd.y * 1.3 + 7.0));
	float band = exp(-pow(dot(sd, normalize(vec3(0.55, 0.35, 0.76))) * 4.5, 2.0));
	float density = 0.25 + 0.75 * clumps + 0.9 * band;
	float st = star_layer(sd, 90.0, 0.035, density, 0.16);
	st += star_layer(sd, 210.0, 0.03, density, 0.12) * 0.6;
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.8), hash3(floor(sd * 90.0) + 2.2));
	vec3 milky = vec3(0.025, 0.022, 0.045) * band * (0.5 + 0.5 * fbm(sd.xz * 9.0 + 3.0));
	return (tint * st + milky) * smoothstep(0.0, 0.25, h);
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
	// estrelas atrás das nuvens
	if (stars > 0.5 && h > 0.0) {
		col += star_field(normalize(d), h);
	}
	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.08) * 0.9 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv);
		float c = smoothstep(0.62 - cloud_amount * 0.3, 0.92 - cloud_amount * 0.2, n);
		vec3 lit = cloud_color * (0.85 + 0.25 * fbm(uv * 1.7 + 3.0));
		col = mix(col, lit, c * clamp(h * 6.0, 0.0, 1.0) * 0.9);
	}
	COLOR = col;
}
