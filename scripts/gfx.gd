extends RefCounted
## Gráficos (v0.9): texturas procedurais, céu, ambiente e partículas. Tudo gerado em código.

const SkyShader = preload("res://shaders/sky.gdshader")
const RainbowShader = preload("res://shaders/rainbow_box.gdshader")

static var _cache := {}


static func _game() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("Game")
	return null


## Valor de configuração (RF-180); sem o autoload Game, o padrão.
static func setting(key: String, fallback = null):
	var game := _game()
	if game:
		return game.settings.get(key, fallback)
	return fallback


## RF-182: 0 = BAIXO, 1 = MÉDIO, 2 = ALTO.
static func quality() -> int:
	return int(setting("quality", 2))


static func high() -> bool:
	return quality() == 2


static func particle_scale() -> float:
	return 1.0 if setting("particles_full", true) else 0.4


static func msaa_for(q: int) -> Viewport.MSAA:
	return [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(q, 0, 2)]



# ---------------------------------------------------------------- detalhe das malhas (RF-478)

## As primitivas do Godot nascem com 64 segmentos (esfera 4224 triângulos, toro 4096): com centenas
## na pista eram milhões de triângulos por quadro e o celular travava. Esta função passa por tudo que
## foi montado e baixa o detalhe pelo tamanho (pequeno = 12 lados, grande = até 32). Malha
## compartilhada é ajustada uma vez só; quem já pediu menos segmentos fica como está.
static func simplify_meshes(root: Node) -> int:
	var seen := {}
	var saved := 0
	for n in root.find_children("*", "", true, false):
		var m: Mesh = null
		if n is MeshInstance3D:
			m = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			m = n.multimesh.mesh
		elif n is CPUParticles3D:
			m = n.mesh
		if m is PrimitiveMesh and not seen.has(m):
			seen[m] = true
			saved += _simplify(m)
	return saved


## RF-479: junta as peças paradas de um modelo feito de primitivas (o camundongo piloto tinha 28
## malhas = 28 desenhos e 33 nós andando junto com o kart) numa malha só, com a cor de cada peça
## na cor do vértice. Sobra um desenho por "jeito" de material: fosco, brilhante, sem luz e
## transparente. Os nomes das peças ficam em meta("parts") (os testes conferem o visual por eles).
static func merge_meshes(root: Node3D) -> MeshInstance3D:
	var parts := []
	var groups := {}   # jeito -> {v, n, c, i, mat}
	for n in root.find_children("*", "", true, false):
		if not String(n.name).begins_with("@"):
			parts.append(String(n.name))
		if not (n is MeshInstance3D) or n.mesh == null:
			continue
		var mi := n as MeshInstance3D
		if mi.mesh is PrimitiveMesh:
			_simplify(mi.mesh)
		var xf := mi.transform
		var p := mi.get_parent()
		while p != root and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as StandardMaterial3D
			if m == null:
				continue
			var kind := "transp" if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else ("unshaded" if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else ("shiny" if m.roughness < 0.5 else "matte"))
			if not groups.has(kind):
				groups[kind] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array(), "mat": m}
			var g: Dictionary = groups[kind]
			var a := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var base: int = (g["v"] as PackedVector3Array).size()
			for vi in verts.size():
				g["v"].append(xf * verts[vi])
				g["n"].append((nb * norms[vi]).normalized() if vi < norms.size() else Vector3.UP)
				g["c"].append(m.albedo_color)
			var idx = a[Mesh.ARRAY_INDEX]
			if idx == null or (idx as PackedInt32Array).is_empty():
				for vi in verts.size():
					g["i"].append(base + vi)
			else:
				for ii in (idx as PackedInt32Array):
					g["i"].append(base + ii)
	var am := ArrayMesh.new()
	for kind in groups:
		var g: Dictionary = groups[kind]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_COLOR] = g["c"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var src: StandardMaterial3D = g["mat"]
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = src.roughness
		mat.shading_mode = src.shading_mode
		mat.transparency = src.transparency
		am.surface_set_material(am.get_surface_count() - 1, mat)
	# os nós vazios (Head, orelhas, grupos) também saem: só fica a malha juntada
	for c in root.get_children():
		root.remove_child(c)
		c.free()
	var out := MeshInstance3D.new()
	out.name = "MergedMesh"
	out.mesh = am
	root.add_child(out)
	root.set_meta("parts", parts)
	return out


static func sides_for(size: float) -> int:
	if size < 0.5:
		return 12
	if size < 2.0:
		return 16
	if size < 6.0:
		return 24
	return 32


static func _simplify(m: PrimitiveMesh) -> int:
	var before := 0
	if m is SphereMesh:
		var s := sides_for(m.radius)
		before = m.radial_segments * m.rings
		m.radial_segments = mini(m.radial_segments, s)
		m.rings = mini(m.rings, s / 2)
		return before - m.radial_segments * m.rings
	if m is CapsuleMesh:
		var s := sides_for(m.radius)
		before = m.radial_segments * m.rings
		m.radial_segments = mini(m.radial_segments, s)
		m.rings = mini(m.rings, 4)
		return before - m.radial_segments * m.rings
	if m is CylinderMesh:
		var s := sides_for(maxf(m.top_radius, m.bottom_radius))
		before = m.radial_segments * m.rings
		m.radial_segments = mini(m.radial_segments, s)
		m.rings = mini(m.rings, 1)
		return before - m.radial_segments * m.rings
	if m is TorusMesh:
		before = m.rings * m.ring_segments
		m.rings = mini(m.rings, sides_for(m.outer_radius) + 4)
		m.ring_segments = mini(m.ring_segments, 8)
		return before - m.rings * m.ring_segments
	return 0

## Liga/desliga bloom e SSAO de um Environment conforme a qualidade.
static func apply_quality(env: Environment, q: int) -> void:
	env.glow_enabled = q >= 1
	env.ssao_enabled = q >= 2


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
		"wood":  # RF-273: mesa de madeira (veio esticado numa direção)
			m.albedo_texture = noise_tex("wood", 0.06, [base.darkened(0.3), base, base.lightened(0.12), base.darkened(0.12)])
			m.uv1_scale = Vector3(0.004, 0.004, 0.06)
			m.roughness = 0.75
		"metal":  # RF-274: chapas de 8 m
			m.albedo_texture = checker_tex(base.lightened(0.12), base.darkened(0.05), base.darkened(0.45))
			m.uv1_scale = Vector3(0.0625, 0.0625, 0.0625)
			m.roughness = 0.45
			m.metallic = 0.55
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

static func environment(d: Dictionary, q: int) -> Environment:
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
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.ssao_enabled = q >= 2
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


# ---------------------------------------------------------------- modelos do Kenney (v0.10)

static func aabb_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse() if n.is_inside_tree() else Transform3D()
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := _rel_transform(n, mi)
		var b: AABB = t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _rel_transform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D()
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Instancia um modelo e escala pra que a maior dimensão (ou a altura, se by_height)
## fique com `size` metros; a base fica em y = 0 e o centro em x/z = 0.
static func prop(path: String, size: float, by_height := false) -> Node3D:
	var scene: PackedScene = load(path)
	var inner: Node3D = scene.instantiate()
	rebrand(inner)
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.add_child(inner)
	var box := aabb_of(holder)
	var dim := box.size.y if by_height else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := size / maxf(dim, 0.001)
	inner.scale = Vector3.ONE * s
	var c := box.get_center()
	inner.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)
	return holder


## RF-175: a marca fictícia do Racing Kit ("TANKCO") vira ZAWSZE, a marca do jogo.
const BRAND_TEX := "res://assets/brand/zawsze_banner.png"


static func rebrand(n: Node) -> int:
	var changed := 0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m is BaseMaterial3D and m.resource_name.to_lower().contains("tankco"):
				var nm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				nm.albedo_texture = load(BRAND_TEX)
				nm.resource_name = "zawsze"
				mi.set_surface_override_material(s, nm)
				changed += 1
	return changed
