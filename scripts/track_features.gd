extends "res://scripts/track_geometry.gd"
## Pista — atrações e regras: setas, rampas, vãos, buracos, pontes, zonas, cruzamentos e pontos de resgate.
## (camada de track.gd — ver o topo de track.gd)


func _init(track_id := "queijo") -> void:
	def = find(track_id)
	_build_path()
	_place_features()


func _place_features() -> void:
	var lats := [-4.0, 4.0]
	var pr: Array = def.get("pad_ranges", PAD_RANGES)
	for k in pr.size():
		pads.append({"idx": _straightest(pr[k][0], pr[k][1]), "lat": lats[k % 2]})
	var rr = def.get("ramp_range", RAMP_RANGE)
	ramp_idx = _straightest(rr[0], rr[1]) if rr != null else -1
	# RF-330: vãos entre prédios, cada um com uma rampinha de beirada logo antes
	for g in def.get("gaps", []):
		var gi := _straightest(float(g["range"][0]), float(g["range"][1]))
		gaps.append({"i0": gi, "len": int(g.get("len", 4))})
		gap_ramps.append({"idx": wrapi(gi - RAMP_LEN, 0, points.size()), "h": float(g.get("lip", GAP_LIP))})
	ramp_h = float(def.get("ramp_h", RAMP_H))
	_find_crossings()
	_parse_zones()
	_parse_pits_bridges()
	_build_safe()


func _build_safe() -> void:
	var n := points.size()
	safe.resize(n)
	safe.fill(1)
	var block := func(i0: int, i1: int) -> void:
		for i in range(i0, i1 + 1):
			safe[wrapi(i, 0, n)] = 0
	for h in hazard_specs:
		block.call(int(h["idx"]) - 8, int(h["idx"]) + 6)
	for z in zones:
		block.call(int(z["i0"]) - 3, int(z["i0"]) + int(z["len"]) + 2)
	if ramp_idx >= 0:
		block.call(ramp_idx - 2, ramp_idx + RAMP_LEN + 18)  # rampa e pouso
	for l in loops:
		block.call(int(l["i0"]) - 6, int(l["i1"]) + 4)  # RF-321: nunca dentro do looping
	for p in pits:
		block.call(int(p["idx"]) - 6, int(p["idx"]) + 4)  # RF-390: nunca em cima de um buraco
	for g in gaps:
		block.call(int(g["i0"]) - RAMP_LEN - 4, int(g["i0"]) + int(g["len"]) + 12)  # RF-330: rampinha, vão e pouso
	for c in crossings:
		for ci in c:
			block.call(int(ci) - 14, int(ci) + 14)


## Ponto seguro mais próximo andando pra trás a partir de i (nunca pra frente: o resgate não adianta ninguém).
func safe_before(i: int) -> int:
	var n := points.size()
	for k in n:
		var j := wrapi(i - k, 0, n)
		if safe.is_empty() or safe[j] == 1:
			return j
	return i


## Kart está em cima de uma seta? (RF-140)
func on_pad(i: int, lat: float) -> bool:
	var n := points.size()
	for p in pads:
		var d := wrapi(i - int(p["idx"]), 0, n)
		if d <= PAD_LEN and absf(lat - float(p["lat"])) < 2.4:
			return true
	return false


## Fração (0..1) do kart ao longo da rampa, ou -1 se não está nela (RF-141).
func ramp_frac(i: int, along: float, lat: float) -> float:
	if absf(lat) > road_half(i):
		return -1.0
	for r in _all_ramps():
		var d := wrapi(i - int(r["idx"]), 0, points.size())
		if d > RAMP_LEN + 1:
			continue
		var f := (d + along / SPACING) / RAMP_LEN
		if f >= 0.0 and f <= 1.0:
			return f
	return -1.0


## Altura da rampa que contém a amostra i (a principal ou a de beirada de um vão).
func ramp_height(i: int) -> float:
	for r in _all_ramps():
		if wrapi(i - int(r["idx"]), 0, points.size()) <= RAMP_LEN + 1:
			return float(r["h"])
	return ramp_h


func _all_ramps() -> Array:
	var out := gap_ramps.duplicate()
	if ramp_idx >= 0:
		out.push_front({"idx": ramp_idx, "h": ramp_h})
	return out


## RF-330: amostra sem chão (vão entre prédios)?
func gap_at(i: int) -> bool:
	for g in gaps:
		if wrapi(i - int(g["i0"]), 0, points.size()) < int(g["len"]):
			return true
	return false


func cheese_positions() -> Array:
	var out := []
	var n := points.size()
	for row in def.get("cheese_rows", CHEESE_ROWS):
		var i0 := int(n * float(row[0]))
		for k in 5:
			var i := (i0 + k * 4) % n
			out.append(points[i] + rights[i] * float(row[1]) * road_half(i) / ROAD_HALF + Vector3.UP * 0.7)
	return out


func item_box_positions() -> Array:
	var out := []
	var n := points.size()
	for f in def.get("item_rows", ITEM_ROWS):
		var i := int(n * float(f))
		for lat in [-6.0, -2.0, 2.0, 6.0]:
			out.append(points[i] + rights[i] * lat * road_half(i) / ROAD_HALF + Vector3.UP * 1.2)
	return out


func _find_crossings() -> void:
	if not def.get("crossing", false) and def.get("heights", []).is_empty():
		return
	var n := points.size()
	cross_near.resize(n)
	crossing_top.resize(n)
	for i in n:
		cross_near[i] = PackedInt32Array()
		crossing_top[i] = false
	var r2 := CROSS_NEAR * CROSS_NEAR
	for i in n:
		for j in range(i + CROSS_MIN_GAP, n):
			if n - (j - i) < CROSS_MIN_GAP:
				break
			var dy := absf(points[i].y - points[j].y)
			var h2 := Vector2(points[i].x - points[j].x, points[i].z - points[j].z).length_squared()
			if dy >= LEVEL_GAP:
				if h2 < 2.3 * 2.3 and (overpasses.is_empty() or absi(int(overpasses[-1][0]) - (i if points[i].y < points[j].y else j)) > 5):
					overpasses.append([i, j] if points[i].y < points[j].y else [j, i])
				continue
			var d2 := h2 + dy * dy
			if d2 < r2:
				cross_near[i].append(j)
				cross_near[j].append(i)
				crossing_top[j] = true
				if d2 < 2.3 * 2.3 and (crossings.is_empty() or absi(int(crossings[-1][0]) - i) > 5):
					crossings.append([i, j])


## O ponto (meio da amostra i, lateral lat) cai a menos de `half` da linha central de outra passada?
func _in_other_road(i: int, lat: float, half: float) -> bool:
	if cross_near.is_empty() or (cross_near[i] as PackedInt32Array).is_empty():
		return false
	var k := (i + 1) % points.size()
	var p := (points[i] + points[k]) * 0.5 + rights[i] * lat
	var h2 := half * half
	for j in cross_near[i]:
		if Vector2(p.x - points[j].x, p.z - points[j].z).length_squared() < h2:
			return true
	return false


func _parse_pits_bridges() -> void:
	var n := points.size()
	for p in def.get("pits", []):
		var i := _frac_idx(float(p["at"]))
		var lat := float(p.get("lat", 0.0))
		pits.append({"idx": i, "lat": lat, "r": float(p.get("r", 2.4)), "pos": points[i] + rights[i] * lat})
	for b in def.get("bridges", []):
		var i0 := _frac_idx(float(b[0]))
		var i1 := _frac_idx(float(b[1]))
		bridges.append({"i0": i0, "len": wrapi(i1 - i0, 0, n)})


## RF-390: o ponto cai dentro de um buraco? (perto da amostra i)
func pit_at(pos: Vector3, i: int) -> bool:
	var n := points.size()
	for p in pits:
		if absi(wrapi(i - int(p["idx"]), -n / 2, n / 2)) > 6:
			continue
		var c: Vector3 = p["pos"]
		if Vector2(pos.x - c.x, pos.z - c.z).length() < float(p["r"]) - 0.5 and absf(pos.y - c.y) < 2.0:
			return true
	return false


func bridge_at(i: int) -> bool:
	for b in bridges:
		if wrapi(i - int(b["i0"]), 0, points.size()) <= int(b["len"]):
			return true
	return false


func _parse_zones() -> void:
	var n := points.size()
	for z in def.get("zones", []):
		var i0 := _frac_idx(float(z["from"]))
		var i1 := _frac_idx(float(z["to"]))
		var lat: Array = z.get("lat", [-ROAD_HALF, ROAD_HALF])
		zones.append({"kind": z["kind"], "i0": i0, "len": wrapi(i1 - i0, 0, n), "lat0": float(lat[0]), "lat1": float(lat[1]), "dir": float(z.get("dir", 1.0))})
	for isl in def.get("islands", []):
		var a := _frac_idx(float(isl["from"]))
		var b := _frac_idx(float(isl["to"]))
		islands.append({"i0": a, "len": wrapi(b - a, 0, n), "lat0": float(isl["lat"][0]), "lat1": float(isl["lat"][1]), "side": float(isl.get("shortcut", 1.0))})
	for h in def.get("hazards", []):
		var spec: Dictionary = h.duplicate()
		spec["idx"] = _frac_idx(float(h["at"]))
		hazard_specs.append(spec)


## Zona sob o kart (amostra i, lateral lat): o dicionário da zona ou {}.
func zone_at(i: int, lat: float) -> Dictionary:
	var n := points.size()
	for z in zones:
		if wrapi(i - int(z["i0"]), 0, n) <= int(z["len"]) and lat >= float(z["lat0"]) and lat <= float(z["lat1"]):
			return z
	return {}
