extends SceneTree
## RF-206: tira "fotos" dos modelos 3D dos itens pra usar como ícone no HUD.
## Rode COM janela: godot --path . --script tools/render_icons.gd
## Saída: assets/icons/<item>.png (256x256, fundo transparente). Depois: godot --headless --path . --import

const HazardModels = preload("res://scripts/hazard_models.gd")
const Gfx = preload("res://scripts/gfx.gd")
const SIZE := 256


func _initialize() -> void:
	_run.call_deferred()


func _model(kind: String) -> Node3D:
	match kind:
		"turbo":
			var r := HazardModels.rocket()
			r.rotation = Vector3(0, 0, deg_to_rad(-40))
			return r
		"casca":
			return Gfx.prop("res://assets/kenney/food/banana.glb", 1.5)
		"bomba":
			var b := HazardModels.bomb()
			for c in b.get_children():  # brilho vermelho do jogo estoura na foto (parecia maçã)
				if c is MeshInstance3D and c.material_override is StandardMaterial3D:
					c.material_override.emission_enabled = false
			var spark := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1
			sm.height = 0.2
			spark.mesh = sm
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(1.0, 0.8, 0.2)
			fm.emission_enabled = true
			fm.emission = Color(1.0, 0.6, 0.1)
			fm.emission_energy_multiplier = 3.0
			spark.material_override = fm
			spark.position = Vector3(0.24, 0.72, 0)
			b.add_child(spark)
			return b
		"ratoeira":
			return HazardModels.mousetrap()
		"gato":
			var g := HazardModels.cat()
			g.rotation.y = PI - 0.7  # de frente pra câmera
			return g
		"cheese":
			return Gfx.prop("res://assets/kenney/food/cheese.glb", 1.2)
		"triplo":
			var n := Node3D.new()
			for i in 3:
				var c := Gfx.prop("res://assets/kenney/food/cheese.glb", 1.0)
				c.position = Vector3((i - 1) * 0.75, (1 - absi(i - 1)) * 0.25, (absi(i - 1)) * 0.3)
				c.rotation.y = (i - 1) * 0.5
				n.add_child(c)
			return n
		"escudo":
			var n := Node3D.new()
			var c := Gfx.prop("res://assets/kenney/food/cheese.glb", 1.0)
			c.position.y = -0.3
			n.add_child(c)
			var bubble := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.95
			sm.height = 1.9
			bubble.mesh = sm
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.45, 0.8, 1.0, 0.16)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_FRONT  # só a borda de trás: o queijo fica visível
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.9
			tm.outer_radius = 1.0
			ring.mesh = tm
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(0.5, 0.85, 1.0)
			rm.emission_enabled = true
			rm.emission = Color(0.4, 0.75, 1.0)
			rm.emission_energy_multiplier = 1.2
			ring.material_override = rm
			ring.rotation.x = PI / 2.0 - 0.5
			n.add_child(ring)
			bubble.material_override = m
			n.add_child(bubble)
			return n
	return Node3D.new()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	for kind in ["turbo", "casca", "bomba", "ratoeira", "gato", "cheese", "triplo", "escudo"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_8X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
		env.environment.ambient_light_energy = 0.9
		env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
		sun.light_energy = 1.4
		vp.add_child(sun)
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(150), 0)
		fill.light_energy = 0.5
		vp.add_child(fill)
		var holder := Node3D.new()
		vp.add_child(holder)
		var m := _model(kind)
		holder.add_child(m)
		# enquadra pelo AABB: câmera de cima/lado, ortográfica, com margem
		var box: AABB = Gfx.aabb_of(holder)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var dir := Vector3(0.55, 0.6, 1.0).normalized()
		if kind in ["cheese", "triplo", "escudo"]:
			dir = Vector3(0.45, 0.3, 1.0).normalized()  # mais de lado: aparece o furo/a fatia
		var center := box.get_center()
		cam.position = center + dir * 10.0
		vp.add_child(cam)
		cam.look_at(center)
		cam.size = box.get_longest_axis_size() * 1.25
		cam.current = true
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)  # HUD usa ~60-70 px
		img.save_png(ProjectSettings.globalize_path("res://assets/icons/%s.png" % kind))
		print("ícone ", kind)
		vp.queue_free()
		await process_frame
	quit()
