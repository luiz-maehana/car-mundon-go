extends "res://scripts/track_scenery.gd"
## Pista (RF-453): a classe é dividida em camadas, cada uma com um trabalho só:
##   track_geometry.gd  traçado 3D, largura, muro, altura e buscas (base: todo o estado)
##   track_features.gd  setas, rampas, vãos, buracos, pontes, zonas, cruzamentos, resgate
##   track_visuals.gd   malha da pista e das atrações, ajudantes de malha
##   track_scenery.gd   pórtico, boxes e a decoração de cada tema
##   track.gd           monta tudo no _ready (este arquivo)
## Os dados das pistas ficam em track_data.gd.


func _ready() -> void:
	_build_visuals()


# ---------------------------------------------------------------- visuals

func _build_visuals() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	for i in n:
		if not gaps.is_empty() and gap_at(i):
			continue  # RF-330: vão = nada (lá embaixo é a rua)
		# RF-300: no cruzamento a passada de cima fica um tiquinho mais alta e zebra,
		# grama e muro que cairiam dentro da outra pista não são desenhados
		var top: bool = crossing_top[i] if not crossing_top.is_empty() else false
		var road_c: Color = def["road"][(i / 4) % 2]
		if not bridges.is_empty() and bridge_at(i):
			var bc: Array = def.get("bridge_road", [Color(0.55, 0.36, 0.2), Color(0.48, 0.31, 0.17)])
			road_c = bc[i % 2]  # RF-392: tábuas (ou o metal da colher na cozinha)
		var ry := 0.036 if top else 0.03
		var h0 := road_half(i)
		var h1 := road_half((i + 1) % n)
		_strip_e(st, i, -h0, h0, -h1, h1, ry, ry, road_c)
		if top and i % 2 == 0 and _in_other_road(i, 0.0, ROAD_HALF + CURB + 1.0):
			# faixas brancas tracejadas: mostram por onde a outra passada atravessa
			for s in [1.0, -1.0]:
				_strip(st, i, s * (ROAD_HALF - 0.9) - 0.35, s * (ROAD_HALF - 0.9) + 0.35, 0.045, 0.045, Color(0.97, 0.97, 0.95))
		var curb_c: Color = def["curb"][(i / 2) % 2]
		for s in [1.0, -1.0]:
			if not _in_other_road(i, s * (ROAD_HALF + CURB * 0.5), ROAD_HALF + CURB):
				_strip_e(st, i, s * h0, s * (h0 + CURB), s * h1, s * (h1 + CURB), 0.04, 0.04, curb_c)
		# RF-320: muro por amostra (estreito no looping e nas pontes); w0/w1 = as duas pontas do trecho
		var w0 := wall_at(i)
		var w1 := wall_at((i + 1) % n)
		var off_c: Color = def["offroad"]
		for s in [1.0, -1.0]:
			if w0 > h0 + CURB + 0.5 and not _in_other_road(i, s * (h0 + CURB + OFFROAD * 0.5), h0 + CURB + OFFROAD * 0.5):
				_strip_e(st, i, s * (h0 + CURB), s * w0, s * (h1 + CURB), s * w1, 0.02, 0.02, off_c)
		var wall_c: Color = def["wall"][(i / 3) % 2]
		for s in [1.0, -1.0]:
			if not _in_other_road(i, s * WALL, WALL + WALL_T + 1.0):
				# face interna, topo, face externa
				_strip_e(st, i, s * w0, s * w0, s * w1, s * w1, 0.0, WALL_H, wall_c)
				_strip_e(st, i, s * w0, s * (w0 + WALL_T), s * w1, s * (w1 + WALL_T), WALL_H, WALL_H, wall_c)
				_strip_e(st, i, s * (w0 + WALL_T), s * (w0 + WALL_T), s * (w1 + WALL_T), s * (w1 + WALL_T), WALL_H, 0.0, wall_c)
		# RF-320: trecho no alto (ou no looping) ganha laje por baixo: bordas e fundo
		if points[i].y > 0.5 or in_loop(i) or points[(i + 1) % n].y > 0.5:
			var slab_c: Color = def.get("slab", Color(0.85, 0.88, 0.92))
			var th := -0.6 if in_loop(i) else -0.9
			# RF-395: terreno maciço (duna, bancada): a lateral desce até o chão, sem fundo nem pilar
			var solid: bool = def.get("fill_below", false) and not in_loop(i) and not bridge_at(i)
			if solid:
				th = -maxf(points[i].y, points[(i + 1) % n].y) - 0.2
			for s in [1.0, -1.0]:
				_strip_e(st, i, s * (w0 + WALL_T), s * (w0 + WALL_T), s * (w1 + WALL_T), s * (w1 + WALL_T), 0.0, th, slab_c)
			if not solid:
				_strip_e(st, i, -(w0 + WALL_T), w0 + WALL_T, -(w1 + WALL_T), w1 + WALL_T, th, th, slab_c.darkened(0.25))
	_start_line(st)
	_pads_and_ramp(st)
	_zones_visual(st)
	_pits_visual(st)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Gfx.track_material()  # RF-162
	mi.name = "TrackMesh"
	add_child(mi)
	_build_belts()
	_build_supports()
	_build_bridges()
	_build_tunnels_and_enclosure()
	_build_rooftops()
	_build_market()
	_build_moon()
	_build_hazard_bases()
	_build_ground()
	_build_arch()
	_build_trees()
	_build_scenery()
