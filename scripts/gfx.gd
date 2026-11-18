extends RefCounted
## Gráficos (v0.9): texturas procedurais, céu, ambiente e partículas. Tudo gerado em código.

const SkyShader = preload("res://shaders/sky.gdshader")
const RainbowShader = preload("res://shaders/rainbow_box.gdshader")

static var _cache := {}


## RF-161: qualidade escolhida no menu (Game.graphics_high). Sem Game, ALTO.
static func high() -> bool:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var game: Node = (ml as SceneTree).root.get_node_or_null("Game")
		if game:
			return game.graphics_high
	return true


static func particle_scale() -> float:
	return 1.0 if high() else 0.5


# ---------------------------------------------------------------- texturas (RF-162)

static func noise_tex(key: String, freq: float, colors: Array, normal := false, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size := 256) -> Texture2D:
	var k := "%s:%s" % [key, normal]
	if _cache.has(k):
		return _cache[k]
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	else:
		var g := Gradient.new()
		g.set_color(0, colors[0])
		g.set_color(1, colors[colors.size() - 1])
		for i in range(1, colors.size() - 1):
			g.add_point(float(i) / (colors.size() - 1), colors[i])
		t.color_ramp = g
	t.generate_mipmaps = true
	_cache[k] = t
	return t


static func checker_tex(a: Color, b: Color, grout: Color, key := "checker") -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var c := a if ((x / 64) + (y / 64)) % 2 == 0 else b
			if x % 64 < 2 or y % 64 < 2:
				c = grout
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Material da pista (asfalto/zebra/muro): cor de vértice × granulado, com relevo.
static func track_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.92
	m.metallic_specular = 0.25
	m.albedo_texture = noise_tex("grain", 0.35, [Color(0.72, 0.72, 0.72), Color(0.92, 0.92, 0.92), Color(1, 1, 1)])
	m.normal_enabled = true
	m.normal_texture = noise_tex("grain", 0.35, [], true)
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Chão de cada tema: "grass" | "sand" | "tiles".
static func ground_material(kind: String, base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"tiles":
			m.albedo_texture = checker_tex(base.lightened(0.25), base.darkened(0.2), base.darkened(0.55))
			m.uv1_scale = Vector3(0.125, 0.125, 0.125)  # azulejos de 4 m
			m.roughness = 0.35
			m.metallic_specular = 0.7
		"sand":
			m.albedo_texture = noise_tex("sand", 0.05, [base.darkened(0.12), base, base.lightened(0.12)])
			m.normal_enabled = true
			m.normal_texture = noise_tex("sand", 0.05, [], true)
			m.normal_scale = 0.4
			m.uv1_scale = Vector3(0.05, 0.05, 0.05)
		_:
			m.albedo_texture = noise_tex("grass", 0.04, [base.darkened(0.25), base, base.lightened(0.18).lerp(Color(0.6, 0.65, 0.2), 0.2)])
			m.normal_enabled = true
			m.normal_texture = noise_tex("grass_n", 0.2, [], true)
			m.normal_scale = 0.35
			m.uv1_scale = Vector3(0.04, 0.04, 0.04)
	return m


# ---------------------------------------------------------------- céu e ambiente (RF-160/163)

static func environment(d: Dictionary, hq: bool) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SkyShader
	sm.set_shader_parameter("top_color", d["sky_top"])
	sm.set_shader_parameter("horizon_color", d["sky_horizon"])
	sm.set_shader_parameter("ground_color", (d["ground"] as Color).lerp(d["sky_horizon"], 0.3))
	sm.set_shader_parameter("cloud_color", d.get("cloud_color", Color(1, 1, 1)))
	sm.set_shader_parameter("cloud_amount", d.get("clouds", 0.5))
	sm.set_shader_parameter("stars", 1.0 if d.get("stars", false) else 0.0)
	sm.set_shader_parameter("sun_size", 300.0 if d.get("stars", false) else 700.0)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = d["ambient"]
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = d.get("exposure", 1.0)
	env.glow_enabled = hq
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.ssao_enabled = hq
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = d["sky_horizon"]
	env.fog_density = d.get("fog", 0.0012)
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	return env


static func rainbow_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RainbowShader
	return m


# ---------------------------------------------------------------- partículas (RF-165)

static func _soft_dot() -> Texture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	_cache["dot"] = t
	return t


static func _particle_mesh(additive: bool) -> QuadMesh:
	var key := "pmesh:%s" % additive
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _soft_dot()
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var q := QuadMesh.new()
	q.material = m
	_cache[key] = q
	return q


static func _fade(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g


static func _shrink() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.1))
	return c


static func _grow() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	return c


## kind: sparks | flame | dust | smoke | stars | landing | confetti
static func particles(kind: String, tint := Color.WHITE) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emitting = false
	var amount := 24
	match kind:
		"sparks":
			amount = 26
			p.mesh = _particle_mesh(true)
			p.lifetime = 0.35
			p.direction = Vector3(0, 0.6, 1)
			p.spread = 35.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 7.0
			p.gravity = Vector3(0, -12, 0)
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.22
			p.scale_amount_curve = _shrink()
		"flame":
			amount = 34
			p.mesh = _particle_mesh(true)
			p.lifetime = 0.22
			p.direction = Vector3(0, 0, 1)
			p.spread = 12.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.55
			p.scale_amount_curve = _shrink()
			var g := Gradient.new()
			g.set_color(0, Color(1.6, 1.4, 0.6, 1))
			g.add_point(0.4, Color(1.4, 0.55, 0.1, 0.9))
			g.set_color(g.get_point_count() - 1, Color(0.6, 0.1, 0.05, 0))
			p.color_ramp = g
		"dust":
			amount = 22
			p.mesh = _particle_mesh(false)
			p.lifetime = 0.9
			p.direction = Vector3(0, 1, 0.6)
			p.spread = 50.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, 0.5, 0)
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.1
			p.scale_amount_curve = _grow()
			p.color_ramp = _fade(Color(tint.r, tint.g, tint.b, 0.55))
		"smoke":
			amount = 18
			p.mesh = _particle_mesh(false)
			p.one_shot = true
			p.explosiveness = 0.9
			p.lifetime = 1.0
			p.direction = Vector3(0, 1, 0)
			p.spread = 70.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.5
			p.gravity = Vector3(0, 1.0, 0)
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.3
			p.scale_amount_curve = _grow()
			p.color_ramp = _fade(Color(0.35, 0.35, 0.38, 0.75))
		"stars":
			amount = 10
			p.mesh = _particle_mesh(true)
			p.one_shot = true
			p.explosiveness = 1.0
			p.lifetime = 0.7
			p.direction = Vector3(0, 1, 0)
			p.spread = 90.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 5.0
			p.gravity = Vector3(0, -6, 0)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.4
			p.color_ramp = _fade(Color(1.6, 1.4, 0.4, 1))
		"landing":
			amount = 20
			p.mesh = _particle_mesh(false)
			p.one_shot = true
			p.explosiveness = 1.0
			p.lifetime = 0.6
			p.direction = Vector3(0, 0.2, 0)
			p.spread = 180.0
			p.flatness = 0.9
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 5.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.0
			p.scale_amount_curve = _grow()
			p.color_ramp = _fade(Color(tint.r, tint.g, tint.b, 0.6))
		"confetti":
			amount = 120
			p.mesh = _particle_mesh(false)
			p.one_shot = true
			p.explosiveness = 0.85
			p.lifetime = 2.6
			p.direction = Vector3(0, 1, 0)
			p.spread = 45.0
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 13.0
			p.gravity = Vector3(0, -7, 0)
			p.damping_min = 1.5
			p.damping_max = 3.0
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.28
			var g := Gradient.new()
			g.set_color(0, Color(1, 0.3, 0.3))
			g.add_point(0.25, Color(1, 0.85, 0.2))
			g.add_point(0.5, Color(0.3, 0.9, 0.4))
			g.add_point(0.75, Color(0.3, 0.6, 1.0))
			g.set_color(g.get_point_count() - 1, Color(0.9, 0.4, 1.0))
			p.color_initial_ramp = g
	p.amount = maxi(4, int(amount * particle_scale()))
	return p
