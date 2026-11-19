extends SceneTree
## Conta os shaders diferentes que uma corrida usa (cada um compila no 1º desenho; no navegador
## isso trava a página). Uso: godot --path . --rendering-method gl_compatibility --script tools/count_shaders.gd -- [pista]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var game = root.get_node("Game")
	game.num_players = 1
	game.track_id = args[0] if args.size() > 0 else "queijo"
	game.selected_chars = ["mugurin"]
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	await process_frame
	var by_shader := {}   # chave -> [quantos materiais, exemplo]
	for n in race.find_children("*", "", true, false):
		var mats := []
		if n is GeometryInstance3D:
			if n.material_override: mats.append(n.material_override)
			if n.material_overlay: mats.append(n.material_overlay)
		if n is MeshInstance3D and n.mesh:
			for s in n.mesh.get_surface_count():
				mats.append(n.get_active_material(s))
		if n is GPUParticles3D or n is CPUParticles3D:
			if n is GPUParticles3D and n.process_material: mats.append(n.process_material)
			var dm = n.draw_pass_1 if n is GPUParticles3D else n.mesh
			if dm:
				for s in dm.get_surface_count(): mats.append(dm.surface_get_material(s))
		if n is Label3D or n is Sprite3D:
			mats.append(n)  # cada combinação de flags vira shader próprio
		for m in mats:
			if m == null: continue
			var key := ""
			if m is ShaderMaterial:
				key = "shader:" + (m.shader.resource_path if m.shader else "?")
			elif m is BaseMaterial3D:
				key = "std:" + _std_key(m)
			else:
				key = m.get_class() + ":" + _flags(m)
			if not by_shader.has(key):
				by_shader[key] = [0, n.get_path()]
			by_shader[key][0] += 1
	print("SHADERS distintos: ", by_shader.size())
	for k in by_shader:
		print("  ", by_shader[k][0], "x  ", k, "  ", str(by_shader[k][1]).get_file())
	quit()


## O Godot gera um shader por combinação de modos/opções/texturas presentes (não por cor ou número).
func _std_key(m: BaseMaterial3D) -> String:
	var parts := []
	for p in m.get_property_list():
		var nm: String = p["name"]
		if p["type"] == TYPE_BOOL or (p["type"] == TYPE_INT and p["hint"] == PROPERTY_HINT_ENUM):
			parts.append("%s=%s" % [nm, m.get(nm)])
		elif p["type"] == TYPE_OBJECT and nm.ends_with("_texture"):
			if m.get(nm) != null:
				parts.append(nm)
	return str(hash(",".join(parts)))


func _flags(n) -> String:
	return "%s/%s/%s/%s" % [n.billboard, n.shaded, n.double_sided, n.alpha_cut] if "billboard" in n else "?"
