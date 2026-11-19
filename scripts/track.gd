extends Node3D
## Pista procedural. As pistas são dados (TRACKS, RF-120): nome, pontos de controle e tema.
## Linha central = spline Catmull-Rom fechada, reamostrada a cada SPACING metros.
## Tudo (grama, muro, progresso, IA) é resolvido pela distância lateral à linha central.

const Gfx = preload("res://scripts/gfx.gd")
const RACING := "res://assets/kenney/racing/"

const ROAD_HALF := 8.0
const CURB := 1.2
const OFFROAD := 7.0
const WALL := ROAD_HALF + OFFROAD
const WALL_H := 1.1
const WALL_T := 0.8
const SPACING := 2.0
const ITEM_ROWS := [0.18, 0.47, 0.76]

const TrackData = preload("res://scripts/track_data.gd")
const TRACKS = TrackData.TRACKS  # RF-452: os dados moram em track_data.gd

var def: Dictionary
var points := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var length := 0.0
var bounds_min := Vector2.ZERO
var bounds_max := Vector2.ZERO


func _init(track_id := "queijo") -> void:
	def = find(track_id)
	_build_path()
	_place_features()


# ---------------------------------------------------------------- setas, rampa, queijos (v0.8)

const RAMP_LEN := 3          # amostras (6 m)
const RAMP_H := 1.0
const PAD_LEN := 3
const CHEESE_ROWS := [[0.28, -3.5], [0.55, 3.5], [0.9, 0.0]]
const PAD_RANGES := [[0.07, 0.14], [0.6, 0.7]]
const RAMP_RANGE := [0.3, 0.42]

var pads: Array = []     # {idx, lat}
var ramp_idx := -1
var ramp_h := RAMP_H     # o escorregador do parquinho é mais alto (RF-302)
var gaps: Array = []      # RF-330: {i0, len} amostras sem chão
var gap_ramps: Array = [] # {idx, h} rampinha antes de cada vão
const GAP_LIP := 1.2


## Curvatura em i: ângulo entre a tangente 10 amostras antes e 20 depois.
func curvature_at(i: int) -> float:
	var n := points.size()
	return tangents[wrapi(i - 10, 0, n)].angle_to(tangents[wrapi(i + 20, 0, n)])


func _straightest(f0: float, f1: float) -> int:
	var n := points.size()
	var best := int(n * f0)
	var best_c := INF
	for i in range(int(n * f0), int(n * f1)):
		var c := curvature_at(i)
		if c < best_c:
			best_c = c
			best = i
	return best


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




# ---------------------------------------------------------------- pontos seguros do resgate (RF-311)

var safe := PackedByteArray()   # 1 = dá pra devolver um kart aqui (longe de perigo, rampa e cruzamento)


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


static func find(track_id: String) -> Dictionary:
	for t in TRACKS:
		if t["id"] == track_id:
			return t
	return TRACKS[0]


func _ready() -> void:
	_build_visuals()


func sample_count() -> int:
	return points.size()


func lateral_of(pos: Vector3, i: int) -> float:
	return (pos - points[i]).dot(rights[i])


func along_of(pos: Vector3, i: int) -> float:
	return (pos - points[i]).dot(tangents[i])


func heading_at(i: int) -> float:
	var t := tangents[i]
	return atan2(-t.x, -t.z)


## Índice da amostra mais próxima. Com hint >= 0 busca só numa janela local
## (barato e não "pula" para outro trecho da pista que passe perto).
func nearest_index(pos: Vector3, hint: int = -1, window: int = 12) -> int:
	var n := points.size()
	var best := 0
	var best_d := INF
	if hint < 0:
		for i in n:
			var d := pos.distance_squared_to(points[i])
			if d < best_d:
				best_d = d
				best = i
		return best
	for o in range(-window, window + 1):
		var i := wrapi(hint + o, 0, n)
		var d := pos.distance_squared_to(points[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func item_box_positions() -> Array:
	var out := []
	var n := points.size()
	for f in def.get("item_rows", ITEM_ROWS):
		var i := int(n * float(f))
		for lat in [-6.0, -2.0, 2.0, 6.0]:
			out.append(points[i] + rights[i] * lat * road_half(i) / ROAD_HALF + Vector3.UP * 1.2)
	return out


# ---------------------------------------------------------------- path (v0.26: altura e loopings, RF-320..322)

const LOOP_DENSE := 72          # pontos densos por looping
const NARROW_WALL := ROAD_HALF + CURB + 0.3   # muro colado na zebra (loopings e pontes)
const TIGHT_HALF := 5.0        # RF-370: daqui pra baixo a pista não tem grama (barracas coladas)
const TUNNEL_H := 9.0

var ups := PackedVector3Array()     # normal da pista (UP no plano; gira no looping)
var loop_id := PackedInt32Array()   # por amostra: índice em `loops` ou -1
var loops: Array = []               # {i0, i1, r, w, center, right}
var walls := PackedFloat32Array()   # por amostra: distância do muro (WALL ou NARROW_WALL)
var halfs := PackedFloat32Array()   # RF-370: meia largura da pista por amostra
var islands: Array = []             # RF-371: {i0, len, lat0, lat1, side} barracas no meio da pista


## Hermite (Catmull-Rom com tangentes explícitas, pra o looping não entortar a pista em volta).
func _hermite(p1: Vector3, m1: Vector3, p2: Vector3, m2: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p1 + (t3 - 2.0 * t2 + t) * m1 + (-2.0 * t3 + 3.0 * t2) * p2 + (t3 - t2) * m2


func _build_path() -> void:
	var cps: Array = def["points"]
	var hs: Array = def.get("heights", [])
	var wd: Array = def.get("widths", [])  # RF-370: meia largura da pista por ponto (padrão ROAD_HALF)
	var m := cps.size()
	var real: Array[Vector3] = []
	for i in m:
		var c: Vector2 = cps[i]
		real.append(Vector3(c.x, float(hs[i]) if i < hs.size() else 0.0, c.y))
	var loop_at := {}
	for l in def.get("loops", []):
		loop_at[int(l["cp"])] = l
	# lista de pontos de controle; um looping no cp k vira o par (P_k, P_k + direita * w)
	var list: Array = []   # {p, m, loop}
	for i in m:
		var tan := (real[(i + 1) % m] - real[(i - 1 + m) % m]) * 0.5
		var hw: float = float(wd[i]) if i < wd.size() else ROAD_HALF
		list.append({"p": real[i], "m": tan, "loop": null, "h": hw})
		if loop_at.has(i):
			var l: Dictionary = loop_at[i]
			var d := Vector3(tan.x, 0.0, tan.z).normalized()
			var r := d.cross(Vector3.UP).normalized()
			list.append({"p": real[i] + r * float(l.get("w", 22.0)), "m": tan, "loop": l, "dir": d, "right": r, "from": real[i], "h": hw})
	var dense: Array[Vector3] = []
	var dense_loop := PackedInt32Array()
	var dense_half := PackedFloat32Array()
	var loop_defs: Array = []
	var lm := list.size()
	for j in lm:
		var a: Dictionary = list[j]
		var b: Dictionary = list[(j + 1) % lm]
		if b["loop"] != null:
			# RF-321: looping vertical com deslocamento lateral (a saída passa do lado da entrada)
			var rr := float(b["loop"].get("r", 12.0))
			var w := float(b["loop"].get("w", 22.0))
			var d: Vector3 = b["dir"]
			var right: Vector3 = b["right"]
			var base: Vector3 = b["from"]
			loop_defs.append({"r": rr, "w": w, "center": base + Vector3.UP * rr, "right": right, "dir": d})
			for s in LOOP_DENSE:
				var th := TAU * s / LOOP_DENSE
				dense.append(base + d * rr * sin(th) + Vector3.UP * rr * (1.0 - cos(th)) + right * w * (th - sin(th)) / TAU)
				dense_loop.append(loop_defs.size() - 1)
				dense_half.append(float(a["h"]))
			continue
		for s in 40:
			var hp := _hermite(a["p"], a["m"], b["p"], b["m"], s / 40.0)
			hp.y = maxf(hp.y, 0.0)  # a curva da spline não afunda abaixo do chão
			dense.append(hp)
			dense_loop.append(-1)
			dense_half.append(lerpf(float(a["h"]), float(b["h"]), smoothstep(0.0, 1.0, s / 40.0)))
	var dn := dense.size()
	var cum := PackedFloat64Array()
	cum.append(0.0)
	for i in dn:
		cum.append(cum[i] + dense[i].distance_to(dense[(i + 1) % dn]))
	length = cum[dn]
	var n := int(roundf(length / SPACING))
	var step_len := length / n
	var j := 0
	for k in n:
		var d := k * step_len
		while j < dn - 1 and cum[j + 1] < d:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var f := 0.0 if seg <= 0.0 else (d - cum[j]) / seg
		points.append(dense[j].lerp(dense[(j + 1) % dn], f))
		loop_id.append(dense_loop[j] if dense_loop[(j + 1) % dn] == dense_loop[j] else -1)
		halfs.append(lerpf(dense_half[j], dense_half[(j + 1) % dn], f))
	bounds_min = Vector2(INF, INF)
	bounds_max = Vector2(-INF, -INF)
	for i in n:
		var t := (points[(i + 1) % n] - points[(i - 1 + n) % n]).normalized()
		tangents.append(t)
		var r: Vector3
		if loop_id[i] >= 0:
			var lr: Vector3 = loop_defs[loop_id[i]]["right"]
			r = (lr - t * lr.dot(t)).normalized()
		else:
			r = t.cross(Vector3.UP).normalized()
		rights.append(r)
		ups.append(r.cross(t).normalized())
		var p := points[i]
		bounds_min = Vector2(minf(bounds_min.x, p.x), minf(bounds_min.y, p.z))
		bounds_max = Vector2(maxf(bounds_max.x, p.x), maxf(bounds_max.y, p.z))
	# amostras de cada looping e trechos de muro estreito (looping ± a vizinhança, pontes)
	for li in loop_defs.size():
		var l: Dictionary = loop_defs[li]
		var first := -1
		var last := -1
		for i in n:
			if loop_id[i] == li:
				if first < 0:
					first = i
				last = i
		l["i0"] = first
		l["i1"] = last
		loops.append(l)
	walls.resize(n)
	for i in n:
		# RF-370: pista mais estreita que o normal = barracas coladas na zebra (sem grama)
		walls[i] = halfs[i] + maxf(CURB + 0.3, OFFROAD * clampf((halfs[i] - TIGHT_HALF) / (ROAD_HALF - TIGHT_HALF), 0.0, 1.0))
	for l in loops:
		var c: Vector3 = l["center"]
		for i in n:
			if Vector2(points[i].x - c.x, points[i].z - c.z).length() < float(l["r"]) + float(l["w"]) + 6.0 and absf(points[i].y - (c.y - float(l["r"]))) < float(l["r"]) * 2.0 + 1.0:
				walls[i] = halfs[i] + CURB + 0.3
	for z in def.get("bridges", []):  # RF-392: ponte tem corrimão colado na zebra
		var bi0 := int(n * float(z[0]))
		var bi1 := int(n * float(z[1]))
		for k in wrapi(bi1 - bi0, 0, n) + 1:
			walls[(bi0 + k) % n] = halfs[(bi0 + k) % n] + CURB + 0.3
	for z in def.get("narrow", []):
		var i0 := int(n * float(z[0]))
		var i1 := int(n * float(z[1]))
		for k in wrapi(i1 - i0, 0, n) + 1:
			walls[(i0 + k) % n] = halfs[(i0 + k) % n] + CURB + 0.3


## RF-370: meia largura da pista na amostra i.
func road_half(i: int) -> float:
	return halfs[i] if not halfs.is_empty() else ROAD_HALF


## RF-371: ilha de barracas na amostra i (ou {}). Divide a pista em duas faixas.
func island_at(i: int) -> Dictionary:
	for isl in islands:
		if wrapi(i - int(isl["i0"]), 0, points.size()) <= int(isl["len"]):
			return isl
	return {}


## Distância do muro na amostra i (estreito no looping e nas pontes).
func wall_at(i: int) -> float:
	return walls[i] if not walls.is_empty() else WALL


## Altura do chão da pista perto da amostra i (interpola com a vizinha conforme `along`).
func ground_y(i: int, along: float) -> float:
	var n := points.size()
	if along >= 0.0:
		return lerpf(points[i].y, points[(i + 1) % n].y, clampf(along / SPACING, 0.0, 1.0))
	return lerpf(points[i].y, points[(i - 1 + n) % n].y, clampf(-along / SPACING, 0.0, 1.0))


func in_loop(i: int) -> bool:
	return not loop_id.is_empty() and loop_id[i] >= 0


# ---------------------------------------------------------------- cruzamento (RF-300)

const CROSS_NEAR := 45.0        # raio pra achar a "outra passada" da pista
const CROSS_MIN_GAP := 60       # amostras: mais perto que isso é o mesmo trecho

var cross_near: Array = []      # por amostra: índices de outra passada a menos de CROSS_NEAR
var crossing_top: Array = []    # por amostra: é a passada desenhada por cima?
var crossings: Array = []       # [[i, j], ...] amostras onde as passadas se cruzam
var overpasses: Array = []      # [[baixo, cima], ...] RF-322: uma passada por cima da outra (andares)
const LEVEL_GAP := 3.5          # diferença de altura a partir da qual são andares diferentes


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


## RF-324: túneis (caixa de leite) por cima da pista e a "geladeira" em volta do mundo.
func _build_tunnels_and_enclosure() -> void:
	var n := points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for tn in def.get("tunnels", []):
		var i0 := int(n * float(tn[0]))
		var i1 := int(n * float(tn[1]))
		for k in wrapi(i1 - i0, 0, n):
			var i := (i0 + k) % n
			var w0 := wall_at(i) + WALL_T
			var w1 := wall_at((i + 1) % n) + WALL_T
			var band := (k / 6) % 2 == 0
			var side_c := Color(0.97, 0.97, 0.98) if band else Color(0.25, 0.55, 0.95)
			for s in [1.0, -1.0]:
				_strip_e(st, i, s * w0, s * w0, s * w1, s * w1, 0.0, TUNNEL_H, side_c)
			_strip_e(st, i, -w0, w0, -w1, w1, TUNNEL_H, TUNNEL_H, Color(0.92, 0.94, 0.97))
			any = true
	if any:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _vc_mat(0.6)
		mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.name = "Tunnels"
		add_child(mi)
	if not def.get("enclosure", false):
		return
	# paredes brancas da geladeira (o céu vira o teto) e a lâmpada lá em cima
	var c := (bounds_max + bounds_min) * 0.5
	var half := (bounds_max - bounds_min) * 0.5 + Vector2(170, 170)
	var h := 140.0
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.9, 0.94, 0.98)
	wall_mat.roughness = 0.35
	var specs := [
		[Vector3(c.x, h * 0.5, c.y - half.y), Vector3(half.x * 2.0, h, 2.0)],
		[Vector3(c.x, h * 0.5, c.y + half.y), Vector3(half.x * 2.0, h, 2.0)],
		[Vector3(c.x - half.x, h * 0.5, c.y), Vector3(2.0, h, half.y * 2.0)],
		[Vector3(c.x + half.x, h * 0.5, c.y), Vector3(2.0, h, half.y * 2.0)],
		[Vector3(c.x, h, c.y), Vector3(half.x * 2.0, 2.0, half.y * 2.0)],
	]
	for sp in specs:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sp[1]
		box.mesh = bm
		box.material_override = wall_mat
		box.position = sp[0]
		box.name = "FridgeWall"
		add_child(box)
	# frisos das prateleiras na parede (as bordas de vidro) e a lâmpada
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.88, 1.0, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for y in [40.0, 80.0]:
		for sp in specs.slice(0, 4):
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var sz: Vector3 = sp[1]
			bm.size = Vector3(sz.x if sz.x > 3.0 else 30.0, 1.5, sz.z if sz.z > 3.0 else 30.0)
			strip.mesh = bm
			strip.material_override = glass
			strip.position = Vector3(sp[0].x, y, sp[0].z)
			add_child(strip)
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 14.0
	lm.height = 14.0
	lamp.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.98, 0.9)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.97, 0.88)
	lmat.emission_energy_multiplier = 3.0
	lamp.material_override = lmat
	lamp.position = Vector3(c.x, h - 4.0, c.y)
	add_child(lamp)
	var light := OmniLight3D.new()
	light.position = lamp.position - Vector3.UP * 20.0
	light.omni_range = 600.0
	light.light_energy = 1.2
	light.light_color = Color(0.9, 0.95, 1.0)
	add_child(light)


# ---------------------------------------------------------------- telhados (RF-330..333)

## Prédios embaixo dos trechos de telhado (um bloco por trecho entre vãos), com janelas.
func _build_rooftops() -> void:
	if not def.get("buildings", false):
		return
	var n := points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var facades := [Color(0.78, 0.68, 0.55), Color(0.62, 0.7, 0.78), Color(0.8, 0.6, 0.55), Color(0.7, 0.75, 0.62), Color(0.85, 0.8, 0.68)]
	var boxes: Array = []
	var box_cols: Array = []
	var lit: Array[Transform3D] = []
	var dark: Array[Transform3D] = []
	var seg := 0
	var was_gap := false
	for i in range(0, n, 5):
		var g := gap_at(i) or gap_at((i + 2) % n)
		if g:
			was_gap = true
			continue
		if was_gap:
			seg += 1
			was_gap = false
		var top := points[i].y - 0.9
		var w := wall_at(i) + WALL_T
		var yaw := Basis(Vector3.UP, heading_at(i))
		var base := Vector3(points[i].x, 0.0, points[i].z)
		boxes.append(Transform3D(yaw.scaled(Vector3(w * 2.0, top, 10.6)), base + Vector3.UP * top * 0.5))
		box_cols.append(facades[seg % facades.size()])
		for s in [1.0, -1.0]:
			var y := 3.0
			while y < top - 1.5:
				for c in [-2.5, 2.5]:
					var p: Vector3 = base + rights[i] * s * (w + 0.06) + tangents[i] * c
					p.y = y
					(lit if rng.randf() < 0.45 else dark).append(Transform3D(yaw, p))
				y += 3.6
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	_multimesh_colored(cube, boxes, box_cols, _vc_mat(0.85))
	_windows(lit, dark)
	scenery_count += boxes.size()
	# varais de roupa atravessando a pista (só enfeite: ficam bem acima dos karts)
	var poles: Array[Transform3D] = []
	var lines: Array[Transform3D] = []
	var clothes: Array = []
	var cloth_cols: Array = []
	var cpal := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(1.0, 0.9, 0.3), Color(0.95, 0.95, 0.95), Color(0.5, 0.85, 0.45), Color(0.95, 0.55, 0.8)]
	for f in def.get("clotheslines", []):
		var i := int(n * float(f))
		var w := wall_at(i) + 0.4
		var yaw := Basis(Vector3.UP, heading_at(i))
		for s in [1.0, -1.0]:
			poles.append(Transform3D(yaw, points[i] + rights[i] * s * w + Vector3.UP * 3.5))
		lines.append(Transform3D(yaw, points[i] + Vector3.UP * 6.8))
		var k := 0
		var lat := -w + 1.5
		while lat < w - 1.5:
			var sz := Vector3(rng.randf_range(1.2, 2.2), rng.randf_range(1.4, 2.4), 0.08)
			clothes.append(Transform3D(yaw.scaled(sz), points[i] + rights[i] * lat + Vector3.UP * (6.7 - sz.y * 0.5)))
			cloth_cols.append(cpal[(k + i) % cpal.size()])
			lat += sz.x + rng.randf_range(0.4, 1.4)
			k += 1
	if not poles.is_empty():
		var pole := CylinderMesh.new()
		pole.top_radius = 0.12
		pole.bottom_radius = 0.15
		pole.height = 7.0
		pole.material = _deco_mat(Color(0.35, 0.35, 0.38))
		_multimesh(pole, poles, Vector3.ZERO)
		var line := BoxMesh.new()
		line.size = Vector3((ROAD_HALF + CURB + OFFROAD + 0.4) * 2.0, 0.05, 0.05)
		line.material = _deco_mat(Color(0.9, 0.9, 0.9))
		_multimesh(line, lines, Vector3.ZERO)
		var cloth := BoxMesh.new()
		cloth.size = Vector3.ONE
		var cm := _vc_mat(0.9)
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_multimesh_colored(cloth, clothes, cloth_cols, cm)
		scenery_count += clothes.size()


## Janelas: acesas (amarelo que brilha) e apagadas.
func _windows(lit: Array[Transform3D], dark: Array[Transform3D]) -> void:
	var win := BoxMesh.new()
	win.size = Vector3(1.4, 1.9, 1.4)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.85, 0.45)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.78, 0.35)
	lm.emission_energy_multiplier = 1.6
	win.material = lm
	if not lit.is_empty():
		_multimesh(win, lit, Vector3.ZERO)
	var dwin := BoxMesh.new()
	dwin.size = win.size
	dwin.material = _deco_mat(Color(0.12, 0.14, 0.22))
	if not dark.is_empty():
		_multimesh(dwin, dark, Vector3.ZERO)


## Lua cheia grande no céu (não some na neblina).
func _build_moon() -> void:
	if not def.get("moon", false):
		return
	var c := (bounds_max + bounds_min) * 0.5
	var moon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 60.0
	sm.height = 120.0
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.97, 0.85)
	mm.disable_fog = true
	moon.material_override = mm
	moon.position = Vector3(c.x + 700.0, 380.0, c.y - 900.0)
	moon.name = "Moon"
	add_child(moon)


# ---------------------------------------------------------------- feira (RF-370..372)

const AWNING_H := 6.2        # toldo da ilha: acima da câmera (que passa por baixo no atalho)
const SIDE_AWNING_H := 3.6   # toldo das barracas nas laterais (por cima do muro)
const STALL_COLS := [Color(0.9, 0.2, 0.2), Color(0.2, 0.6, 0.3), Color(0.2, 0.45, 0.9), Color(0.95, 0.75, 0.15), Color(0.9, 0.45, 0.15)]


## Ilha de barracas (calçada + bancas + toldos por cima do atalho) e barracas nos trechos apertados.
func _build_market() -> void:
	if islands.is_empty() and not def.get("market", false):
		return
	var n := points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tables: Array = []
	var table_cols: Array = []
	var fruit: Array = []
	var fruit_cols: Array = []
	var posts: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var fpal := [Color(1.0, 0.55, 0.1), Color(0.85, 0.12, 0.1), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 0.2), Color(0.55, 0.2, 0.5)]
	for isl in islands:
		var la: float = isl["lat0"]
		var lb: float = isl["lat1"]
		var side: float = isl["side"]
		for k in int(isl["len"]):
			var i := (int(isl["i0"]) + k) % n
			# calçada da ilha (um degrau)
			_strip_e(st, i, la, lb, la, lb, 0.25, 0.25, Color(0.78, 0.76, 0.72))
			for e in [la, lb]:
				_strip_e(st, i, e, e, e, e, 0.0, 0.25, Color(0.6, 0.58, 0.55))
			if k % 4 != 1:
				continue
			# banca: mesa com frutas, dois postes e o toldo inclinado por cima da faixa do atalho
			var yaw := Basis(Vector3.UP, heading_at(i))
			var mid := (la + lb) * 0.5
			var c := points[i] + rights[i] * mid
			tables.append(Transform3D(yaw.scaled(Vector3(lb - la - 1.0, 1.0, 6.0)), c + Vector3.UP * 0.75))
			table_cols.append(Color(0.55, 0.36, 0.2))
			for q in 6:
				var fp := c + rights[i] * rng.randf_range(la - mid + 0.8, lb - mid - 0.8) + tangents[i] * rng.randf_range(-2.5, 2.5) + Vector3.UP * 1.45
				var s := rng.randf_range(0.5, 0.9)
				fruit.append(Transform3D(Basis().scaled(Vector3.ONE * s), fp))
				fruit_cols.append(fpal[(k + q) % fpal.size()])
			var edge_in := la if side < 0.0 else lb          # lado do atalho
			var far := -road_half(i) + 1.0 if side < 0.0 else road_half(i) - 1.0
			for t in [-3.0, 3.0]:
				posts.append(Transform3D(yaw, points[i] + rights[i] * edge_in + tangents[i] * t + Vector3.UP * AWNING_H * 0.5))
			var col: Color = STALL_COLS[(k / 4) % STALL_COLS.size()]
			for stripe in 4:
				var f0 := float(stripe) / 4.0
				var f1 := float(stripe + 1) / 4.0
				var l0 := lerpf(edge_in, far, f0)
				var l1 := lerpf(edge_in, far, f1)
				var y0 := lerpf(AWNING_H, AWNING_H - 0.8, f0)
				var y1 := lerpf(AWNING_H, AWNING_H - 0.8, f1)
				var cc := col if stripe % 2 == 0 else Color(0.97, 0.97, 0.95)
				var a0 := points[i] + rights[i] * l0 - tangents[i] * 3.6 + Vector3.UP * y0
				var b0 := points[i] + rights[i] * l1 - tangents[i] * 3.6 + Vector3.UP * y1
				var b1 := points[i] + rights[i] * l1 + tangents[i] * 3.6 + Vector3.UP * y1
				var a1 := points[i] + rights[i] * l0 + tangents[i] * 3.6 + Vector3.UP * y0
				_quad(st, a0, b0, b1, a1, cc)
	# barracas coladas no muro nos trechos apertados (a pista "afunila entre as barracas")
	for i in range(0, n, 5):
		if road_half(i) >= ROAD_HALF - 1.5 or not island_at(i).is_empty():
			continue
		var yaw := Basis(Vector3.UP, heading_at(i))
		for s in [1.0, -1.0]:
			var w := wall_at(i) + WALL_T + 1.8
			var c: Vector3 = points[i] + rights[i] * s * w
			tables.append(Transform3D(yaw.scaled(Vector3(3.0, 1.0, 8.0)), c + Vector3.UP * 0.75))
			table_cols.append(Color(0.55, 0.36, 0.2))
			for q in 5:
				var fp: Vector3 = c + rights[i] * rng.randf_range(-1.0, 1.0) + tangents[i] * rng.randf_range(-3.2, 3.2) + Vector3.UP * 1.45
				fruit.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 0.9)), fp))
				fruit_cols.append(fpal[(i + q) % fpal.size()])
			var col: Color = STALL_COLS[(i / 5 + (1 if s > 0 else 0)) % STALL_COLS.size()]
			# toldo inclinado pra pista, por cima do muro
			var l_out: float = s * (w + 2.0)
			var l_in: float = s * (wall_at(i) - 0.6)
			for stripe in 4:
				var f0 := float(stripe) / 4.0
				var f1 := float(stripe + 1) / 4.0
				var cc := col if stripe % 2 == 0 else Color(0.97, 0.97, 0.95)
				var p0 := lerpf(l_out, l_in, f0)
				var p1 := lerpf(l_out, l_in, f1)
				var y0 := lerpf(SIDE_AWNING_H + 0.8, SIDE_AWNING_H, f0)
				var y1 := lerpf(SIDE_AWNING_H + 0.8, SIDE_AWNING_H, f1)
				_quad(st, points[i] + rights[i] * p0 - tangents[i] * 4.4 + Vector3.UP * y0, points[i] + rights[i] * p1 - tangents[i] * 4.4 + Vector3.UP * y1,
					points[i] + rights[i] * p1 + tangents[i] * 4.4 + Vector3.UP * y1, points[i] + rights[i] * p0 + tangents[i] * 4.4 + Vector3.UP * y0, cc)
			posts.append(Transform3D(yaw.scaled(Vector3(1, (SIDE_AWNING_H + 0.8) / AWNING_H, 1)), points[i] + rights[i] * s * (w + 2.0) + Vector3.UP * (SIDE_AWNING_H + 0.8) * 0.5))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := _vc_mat(0.8)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "Market"
	add_child(mi)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	_multimesh_colored(cube, tables, table_cols, _vc_mat(0.85))
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	_multimesh_colored(ball, fruit, fruit_cols, _vc_mat(0.5))
	var post := CylinderMesh.new()
	post.top_radius = 0.1
	post.bottom_radius = 0.1
	post.height = AWNING_H
	post.material = _deco_mat(Color(0.75, 0.75, 0.78))
	if not posts.is_empty():
		_multimesh(post, posts, Vector3.ZERO)
	scenery_count += tables.size()
	_market_signs()


## Barraca do pastel e do caldo de cana perto da largada, com placa.
func _market_signs() -> void:
	var n := points.size()
	var spots := [[int(n * 0.03), 1.0, "PASTEL", Color(0.95, 0.75, 0.2)], [int(n * 0.97), -1.0, "CALDO DE CANA", Color(0.45, 0.8, 0.3)]]
	for sp in spots:
		var i: int = sp[0]
		var s: float = sp[1]
		var pos: Vector3 = points[i] + rights[i] * s * (wall_at(i) + 6.0)
		pos.y = 0.0
		var yaw := Basis.looking_at(-rights[i] * s)
		var booth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.0, 3.0, 4.0)
		booth.mesh = bm
		booth.material_override = _deco_mat(Color(0.95, 0.95, 0.92))
		booth.basis = yaw
		booth.position = pos + Vector3.UP * 1.5
		add_child(booth)
		var roof := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(9.0, 0.4, 5.0)
		roof.mesh = rm
		roof.material_override = _deco_mat(sp[3])
		roof.basis = yaw
		roof.position = pos + Vector3.UP * 5.2
		add_child(roof)
		for x in [-4.2, 4.2]:
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.12
			pm.bottom_radius = 0.12
			pm.height = 2.2
			pole.mesh = pm
			pole.material_override = _deco_mat(Color(0.7, 0.7, 0.72))
			pole.position = pos + yaw * Vector3(x, 4.1, 0.0)
			add_child(pole)
		var lbl := Label3D.new()
		lbl.text = sp[2]
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.outline_size = 16
		lbl.modulate = Color(1, 1, 1)
		lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lbl.position = pos + Vector3.UP * 6.4
		add_child(lbl)
		scenery_count += 1


# ---------------------------------------------------------------- buracos e pontes (RF-390..392)

var pits: Array = []      # RF-390: {idx, lat, r, pos} buracos redondos na pista (cair = balões)
var bridges: Array = []   # RF-392: {i0, len} trechos de ponte (tábuas, corrimão e rio embaixo)


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


## Buraco: borda colorida e fundo preto (desenhado por cima do asfalto).
func _pits_visual(st: SurfaceTool) -> void:
	var rim: Color = def.get("pit_rim", Color(0.35, 0.3, 0.25))
	for p in pits:
		var i: int = p["idx"]
		var c: Vector3 = p["pos"] + Vector3.UP * 0.075
		var r: float = p["r"]
		var t := tangents[i]
		var rr := rights[i]
		var seg := 20
		for k in seg:
			var a0 := TAU * k / seg
			var a1 := TAU * (k + 1) / seg
			var d0 := rr * cos(a0) + t * sin(a0)
			var d1 := rr * cos(a1) + t * sin(a1)
			_quad(st, c, c + d0 * (r - 0.35), c + d1 * (r - 0.35), c, Color(0.02, 0.02, 0.03))
			_quad(st, c + d0 * (r - 0.35), c + d0 * (r + 0.25) + Vector3.UP * 0.01, c + d1 * (r + 0.25) + Vector3.UP * 0.01, c + d1 * (r - 0.35), rim)


## RF-392: ponte — corrimão de madeira dos dois lados e o rio largo passando embaixo.
func _build_bridges() -> void:
	if bridges.is_empty() and not def.has("gap_floor"):
		return
	var n := points.size()
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	# RF-394: fundo do cânion embaixo de cada vão (quando a pista pede)
	if def.has("gap_floor"):
		for g in gaps:
			var gm := (int(g["i0"]) + int(g["len"]) / 2) % n
			var fl := MeshInstance3D.new()
			var fm := PlaneMesh.new()
			fm.size = Vector2(70.0, 26.0)
			fl.mesh = fm
			fl.material_override = _deco_mat(def["gap_floor"])
			fl.basis = Basis(Vector3.UP, heading_at(gm))
			fl.position = Vector3(points[gm].x, 0.03, points[gm].z)
			fl.name = "GapFloor"
			add_child(fl)
	for b in bridges:
		var i0: int = b["i0"]
		var ln: int = b["len"]
		for k in ln + 1:
			var i := (i0 + k) % n
			var yaw := Basis(Vector3.UP, heading_at(i))
			for s in [1.0, -1.0]:
				var p: Vector3 = points[i] + rights[i] * s * (wall_at(i) + WALL_T * 0.5)
				if k % 2 == 0:
					posts.append(Transform3D(yaw, p + Vector3.UP * 1.1))
				rails.append(Transform3D(yaw.scaled(Vector3(1, 1, SPACING * 1.05)), p + Vector3.UP * 2.1 + tangents[i] * SPACING * 0.5))
		# rio: faixa larga de água atravessando embaixo do meio da ponte
		var mid := (i0 + ln / 2) % n
		if float(def.get("river_w", 34.0)) <= 0.0:
			continue
		var water := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(float(def.get("river_len", 200.0)), float(def.get("river_w", 34.0)))  # atravessa a pista
		water.mesh = pm
		var wm := StandardMaterial3D.new()
		wm.albedo_color = def.get("river_color", Color(0.2, 0.45, 0.75))
		wm.roughness = 0.08
		wm.metallic_specular = 0.9
		water.material_override = wm
		water.basis = Basis(Vector3.UP, heading_at(mid))
		water.position = Vector3(points[mid].x, 0.02, points[mid].z)
		water.name = "River"
		add_child(water)
	if posts.is_empty():
		return
	var post := BoxMesh.new()
	post.size = Vector3(0.3, 2.2, 0.3)
	post.material = _deco_mat(Color(0.45, 0.28, 0.14))
	_multimesh(post, posts, Vector3.ZERO)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.22, 0.22, 1.0)
	rail.material = _deco_mat(Color(0.55, 0.36, 0.18))
	_multimesh(rail, rails, Vector3.ZERO)


## RF-320: pilares embaixo dos trechos altos (caixas de leite/potes na geladeira), fora de outras pistas.
func _build_supports() -> void:
	if def.get("buildings", false):
		return  # nos telhados quem segura a pista são os prédios
	var n := points.size()
	var xf: Array = []
	var cols: Array = []
	var pal: Array = def.get("pillar_colors", [Color(0.95, 0.95, 0.97), Color(0.35, 0.6, 0.95), Color(0.95, 0.4, 0.45)])
	var k := 0
	for i in range(0, n, 9):
		var top := points[i].y - 0.9
		if top < 1.5 or in_loop(i):
			continue
		if def.get("fill_below", false) and not bridge_at(i):
			continue  # terreno maciço não precisa de pilar
		if def.get("river_w", 34.0) <= 0.0 and bridge_at(i):
			continue  # a colher da cozinha fica apoiada nas bancadas
		var base := Vector3(points[i].x, 0.0, points[i].z)
		if _over_other_road(i, base, 1.5):
			continue
		var w := 5.0 + float(k % 3)
		xf.append(Transform3D(Basis(Vector3.UP, heading_at(i)).scaled(Vector3(w, top, w * 0.8)), base + Vector3.UP * top * 0.5))
		cols.append(pal[k % pal.size()])
		k += 1
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_multimesh_colored(box, xf, cols, _vc_mat(0.5))
	scenery_count += xf.size()


## O ponto do chão `p` (abaixo da amostra i) cai em cima de outra pista mais baixa?
func _over_other_road(i: int, p: Vector3, margin: float) -> bool:
	var n := points.size()
	for j in n:
		if absi(wrapi(j - i, -n / 2, n / 2)) < 20:
			continue
		if points[j].y < points[i].y - LEVEL_GAP and Vector2(p.x - points[j].x, p.z - points[j].z).length() < wall_at(j) + WALL_T + margin:
			return true
	return false


func _strip(st: SurfaceTool, i: int, la: float, lb: float, ya: float, yb: float, c: Color) -> void:
	_strip_e(st, i, la, lb, la, lb, ya, yb, c)


## Faixa entre as amostras i e i+1, com laterais próprias em cada ponta; a altura segue a normal
## da pista (no looping o "pra cima" gira junto).
func _strip_e(st: SurfaceTool, i: int, la0: float, lb0: float, la1: float, lb1: float, ya: float, yb: float, c: Color) -> void:
	var n := points.size()
	var k := (i + 1) % n
	var ui := ups[i] if not ups.is_empty() else Vector3.UP
	var uk := ups[k] if not ups.is_empty() else Vector3.UP
	var a0 := points[i] + rights[i] * la0 + ui * ya
	var b0 := points[i] + rights[i] * lb0 + ui * yb
	var a1 := points[k] + rights[k] * la1 + uk * ya
	var b1 := points[k] + rights[k] * lb1 + uk * yb
	_quad(st, a0, b0, b1, a1, c)


func _quad(st: SurfaceTool, a0: Vector3, b0: Vector3, b1: Vector3, a1: Vector3, c: Color) -> void:
	var nrm := (b0 - a0).cross(a1 - a0).normalized()
	st.set_color(c)
	st.set_normal(nrm)
	for v in [a0, b1, b0, a0, a1, b1]:
		st.add_vertex(v)


func _start_line(st: SurfaceTool) -> void:
	var p := points[0]
	var r := rights[0]
	var t := tangents[0]
	var cols := 10
	var w := ROAD_HALF * 2.0 / cols
	for row in 2:
		for col in cols:
			var c := Color.WHITE if (row + col) % 2 == 0 else Color(0.05, 0.05, 0.05)
			var la := -ROAD_HALF + col * w
			var al := -1.0 + row * 1.0
			var y := Vector3.UP * 0.05
			var a0 := p + r * la + t * al + y
			var b0 := p + r * (la + w) + t * al + y
			var b1 := p + r * (la + w) + t * (al + 1.0) + y
			var a1 := p + r * la + t * (al + 1.0) + y
			_quad(st, a0, b0, b1, a1, c)


func _build_ground() -> void:
	var size := (bounds_max - bounds_min) + Vector2(400, 400)
	var center := (bounds_max + bounds_min) * 0.5
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = Gfx.ground_material(def.get("ground_tex", "grass"), def["ground"])
	mi.name = "Ground"
	mi.position = Vector3(center.x, -0.02, center.y)
	add_child(mi)


## RF-173: pórtico de largada com semáforo (Racing Kit) e o nome do jogo.
func _build_arch() -> void:
	var gantry := Gfx.prop(RACING + "overheadLights.glb", (ROAD_HALF + 3.0) * 2.0)
	gantry.name = "StartGantry"
	gantry.position = points[0]
	gantry.basis = Basis(Vector3.UP, heading_at(0))
	add_child(gantry)
	var box := Gfx.aabb_of(gantry)
	# placa em cima do pórtico, com o nome em cada face (cada texto só de um lado, sem
	# espelhar: Label3D é dupla face por padrão e os dois se sobrepunham ilegíveis)
	var sign_y := box.size.y + 1.3
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(15.0, 2.4, 0.5)
	panel.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.1, 0.1, 0.14)
	panel.material_override = pmat
	panel.position = Vector3(0, sign_y, 0)
	panel.name = "StartSign"
	gantry.add_child(panel)
	for side in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = "Car Mundon'GO"
		lbl.font_size = 110
		lbl.pixel_size = 0.014
		lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.85, 0.2)
		lbl.double_sided = false
		lbl.position = Vector3(0, sign_y, side * 0.28)
		if side < 0:
			lbl.rotation.y = PI
		gantry.add_child(lbl)


## RF-173: boxes, tendas, torres de faixa e outdoors do Racing Kit perto da largada.
func _racing_props() -> void:
	var n := points.size()
	# lado oposto ao da arquibancada
	var side := -1.0 if _clear_of_track(points[0] + rights[0] * (WALL + 20.0), 6.0) else 1.0
	var placed := 0
	var spots := [
		[-14, "pitsGarage.glb", 13.0], [-7, "pitsGarage.glb", 13.0], [0, "pitsOffice.glb", 13.0],
		[7, "tentLong.glb", 12.0], [14, "tent.glb", 9.0],
	]
	for sp in spots:
		var i := wrapi(int(sp[0]), 0, n)
		var pos: Vector3 = points[i] + rights[i] * side * (WALL + 11.0)
		pos.y = 0.0
		if not _clear_of_track(pos, 7.0):
			continue
		var p := Gfx.prop(RACING + String(sp[1]), float(sp[2]))
		p.position = pos
		p.basis = Basis.looking_at(rights[i] * side)  # frente (+Z) virada pra pista
		add_child(p)
		placed += 1
	# torres de faixa nas pontas da reta
	for k in [-22, 22]:
		for s in [-1.0, 1.0]:
			var i := wrapi(k, 0, n)
			var pos: Vector3 = points[i] + rights[i] * s * (WALL + 3.5)
			if not _clear_of_track(pos, 2.0):
				continue
			var t := Gfx.prop(RACING + ("bannerTowerRed.glb" if s > 0 else "bannerTowerGreen.glb"), 9.0, true)
			t.position = pos
			t.basis = Basis(Vector3.UP, heading_at(i))
			add_child(t)
			placed += 1
	# outdoors espalhados pela pista, virados pra ela
	for f in [0.22, 0.42, 0.62, 0.84]:
		var i := int(n * f)
		var s := 1.0 if (int(f * 100) / 2) % 2 == 0 else -1.0
		var pos: Vector3 = points[i] + rights[i] * s * (WALL + 7.0)
		if not _clear_of_track(pos, 4.0):
			s = -s
			pos = points[i] + rights[i] * s * (WALL + 7.0)
			if not _clear_of_track(pos, 4.0):
				continue
		var b := Gfx.prop(RACING + "billboard.glb", 9.0)
		b.position = pos
		b.basis = Basis.looking_at(rights[i] * s)
		add_child(b)
		placed += 1
	scenery_count += placed


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < 160 and tries < 4000:
		tries += 1
		var p := Vector3(rng.randf_range(bounds_min.x - 120, bounds_max.x + 120), 0, rng.randf_range(bounds_min.y - 120, bounds_max.y + 120))
		if not _clear_of_track(p, 6.0):
			continue
		var s := rng.randf_range(0.8, 1.6)
		xforms.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p))
	var deco_color: Color = def["deco_color"]
	match def["deco"]:
		"skewer":
			# RF-273: espetos gigantes fincados na mesa (metade) e garrafas de vidro (outra metade)
			var sk: Array[Transform3D] = []
			var bt: Array[Transform3D] = []
			for i in xforms.size():
				(sk if i % 2 == 0 else bt).append(xforms[i])
			var stick := CylinderMesh.new()
			stick.top_radius = 0.12
			stick.bottom_radius = 0.12
			stick.height = 11.0
			stick.material = _deco_mat(Color(0.75, 0.75, 0.78))
			_multimesh(stick, sk, Vector3(0, 5.5, 0))
			var chunk_cols := [Color(0.45, 0.2, 0.1), Color(0.85, 0.75, 0.85), Color(0.2, 0.55, 0.15), Color(0.55, 0.15, 0.1)]
			for c in chunk_cols.size():
				var chunk := BoxMesh.new()
				chunk.size = Vector3(1.3, 1.1, 1.3)
				chunk.material = _deco_mat(chunk_cols[c])
				_multimesh(chunk, sk, Vector3(0, 3.0 + c * 1.6, 0))
			var glass := CylinderMesh.new()
			glass.top_radius = 1.0
			glass.bottom_radius = 1.0
			glass.height = 5.0
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.15, 0.45, 0.2, 0.75)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.roughness = 0.1
			gm.metallic_specular = 1.0
			glass.material = gm
			var neck := CylinderMesh.new()
			neck.top_radius = 0.35
			neck.bottom_radius = 0.9
			neck.height = 2.2
			neck.material = gm
			var label := CylinderMesh.new()
			label.top_radius = 1.03
			label.bottom_radius = 1.03
			label.height = 1.6
			label.material = _deco_mat(Color(0.95, 0.85, 0.2))
			_multimesh(glass, bt, Vector3(0, 2.5, 0))
			_multimesh(neck, bt, Vector3(0, 6.1, 0))
			_multimesh(label, bt, Vector3(0, 2.6, 0))
		"city":
			# RF-333: a vila em volta — prédios com janelas, caixas de água e antenas nos telhados
			var rngc := RandomNumberGenerator.new()
			rngc.seed = 777
			var bx: Array = []
			var bc: Array = []
			var lit: Array[Transform3D] = []
			var dark: Array[Transform3D] = []
			var tanks: Array[Transform3D] = []
			var masts: Array[Transform3D] = []
			var pal := [Color(0.55, 0.5, 0.48), Color(0.45, 0.5, 0.6), Color(0.6, 0.45, 0.4), Color(0.5, 0.55, 0.45), Color(0.65, 0.6, 0.52)]
			for i in xforms.size():
				var o := xforms[i].origin
				if not _clear_of_track(o, 14.0):
					continue  # prédio largo não pode invadir a pista
				var h := rngc.randf_range(10.0, 34.0)
				var w := rngc.randf_range(14.0, 22.0)
				var d := rngc.randf_range(14.0, 22.0)
				var yaw := Basis(Vector3.UP, rngc.randf() * TAU)
				bx.append(Transform3D(yaw.scaled(Vector3(w, h, d)), o + Vector3.UP * h * 0.5))
				bc.append((pal[i % pal.size()] as Color).darkened(rngc.randf() * 0.2))
				for face in 4:
					var nrm: Vector3 = yaw * [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][face]
					var half := (w if face < 2 else d) * 0.5
					var span := (d if face < 2 else w) * 0.5 - 2.0
					var along: Vector3 = nrm.cross(Vector3.UP).normalized()
					var y := 3.0
					while y < h - 2.0:
						var x := -span
						while x <= span:
							if rngc.randf() < 0.3:
								lit.append(Transform3D(yaw, o + nrm * (half + 0.05) + along * x + Vector3.UP * y))
							x += 4.0
						y += 3.6
				if i % 3 == 0:
					tanks.append(Transform3D(Basis(), o + Vector3.UP * h))
				elif i % 3 == 1:
					masts.append(Transform3D(Basis(), o + Vector3.UP * h))
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			_multimesh_colored(cube, bx, bc, _vc_mat(0.9))
			_windows(lit, dark)
			var tank := CylinderMesh.new()
			tank.top_radius = 2.2
			tank.bottom_radius = 2.2
			tank.height = 3.2
			tank.material = _deco_mat(Color(0.3, 0.42, 0.65))
			_multimesh(tank, tanks, Vector3(0, 3.6, 0))
			var legs := BoxMesh.new()
			legs.size = Vector3(3.6, 2.0, 3.6)
			legs.material = _deco_mat(Color(0.25, 0.25, 0.28))
			_multimesh(legs, tanks, Vector3(0, 1.0, 0))
			var mast := CylinderMesh.new()
			mast.top_radius = 0.08
			mast.bottom_radius = 0.12
			mast.height = 6.0
			mast.material = _deco_mat(Color(0.7, 0.7, 0.72))
			_multimesh(mast, masts, Vector3(0, 3.0, 0))
			var bar := BoxMesh.new()
			bar.size = Vector3(3.0, 0.08, 0.08)
			bar.material = mast.material
			_multimesh(bar, masts, Vector3(0, 5.0, 0))
			_multimesh(bar, masts, Vector3(0, 4.0, 0))
		"market":
			# RF-372: em volta da rua — tendas coloridas (metade) e pilhas de caixotes com fruta (metade)
			var tents: Array = []
			var tent_cols: Array = []
			var crates: Array = []
			var crate_cols: Array = []
			var tops: Array = []
			var top_cols: Array = []
			var fp := [Color(1.0, 0.55, 0.1), Color(0.85, 0.12, 0.1), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 0.2)]
			for i in xforms.size():
				var o := xforms[i].origin
				var yaw := Basis(Vector3.UP, float(i) * 2.3)
				if i % 2 == 0:
					tents.append(Transform3D(yaw.scaled(Vector3(7.0, 2.6, 5.0)), o + Vector3.UP * 1.3))
					tent_cols.append(Color(0.95, 0.95, 0.92))
					tops.append(Transform3D(yaw.scaled(Vector3(8.0, 2.4, 6.0)), o + Vector3.UP * 3.8))
					top_cols.append(STALL_COLS[(i / 2) % STALL_COLS.size()])
				else:
					for h in 3:
						crates.append(Transform3D(yaw.scaled(Vector3(2.4, 1.3, 1.8)), o + Vector3.UP * (0.65 + h * 1.35)))
						crate_cols.append(Color(0.62, 0.42, 0.22).darkened(0.08 * h))
					tops.append(Transform3D(Basis().scaled(Vector3(2.0, 0.8, 1.5)), o + Vector3.UP * 4.4))
					top_cols.append(fp[i % fp.size()])
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			_multimesh_colored(cube, tents, tent_cols, _vc_mat(0.8))
			_multimesh_colored(cube, crates, crate_cols, _vc_mat(0.9))
			var prism := PrismMesh.new()
			prism.size = Vector3.ONE
			_multimesh_colored(prism, tops, top_cols, _vc_mat(0.7))
		"fridge":
			# RF-324: comida gigante de geladeira — caixas de leite, potes de iogurte, ovos e garrafas
			var groups: Array = [[], [], [], []]
			for i in xforms.size():
				(groups[i % 4] as Array).append(xforms[i])
			var milk: Array[Transform3D] = []
			milk.assign(groups[0])
			var carton := BoxMesh.new()
			carton.size = Vector3(5.0, 11.0, 5.0)
			carton.material = _deco_mat(Color(0.97, 0.97, 0.98))
			_multimesh(carton, milk, Vector3(0, 5.5, 0))
			var band := BoxMesh.new()
			band.size = Vector3(5.1, 3.0, 5.1)
			band.material = _deco_mat(Color(0.25, 0.55, 0.95))
			_multimesh(band, milk, Vector3(0, 6.5, 0))
			var roof := PrismMesh.new()
			roof.size = Vector3(5.0, 2.2, 5.0)
			roof.material = _deco_mat(Color(0.95, 0.95, 0.97))
			_multimesh(roof, milk, Vector3(0, 12.1, 0))
			var yog: Array[Transform3D] = []
			yog.assign(groups[1])
			var pot := CylinderMesh.new()
			pot.top_radius = 3.0
			pot.bottom_radius = 2.4
			pot.height = 5.0
			pot.material = _deco_mat(Color(1.0, 0.92, 0.95))
			_multimesh(pot, yog, Vector3(0, 2.5, 0))
			var lid := CylinderMesh.new()
			lid.top_radius = 3.15
			lid.bottom_radius = 3.15
			lid.height = 0.25
			lid.material = _deco_mat(Color(0.9, 0.3, 0.5))
			_multimesh(lid, yog, Vector3(0, 5.1, 0))
			var eggs: Array[Transform3D] = []
			for x in groups[2]:
				eggs.append(Transform3D(x.basis.scaled(Vector3(1.0, 1.3, 1.0)), x.origin))
			var egg := SphereMesh.new()
			egg.radius = 2.2
			egg.height = 4.4
			egg.material = _deco_mat(Color(0.98, 0.9, 0.78))
			_multimesh(egg, eggs, Vector3(0, 2.6, 0))
			var bot: Array[Transform3D] = []
			bot.assign(groups[3])
			var bottle := CylinderMesh.new()
			bottle.top_radius = 1.6
			bottle.bottom_radius = 1.6
			bottle.height = 9.0
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color(0.85, 0.15, 0.1)
			bm.roughness = 0.3
			bottle.material = bm
			_multimesh(bottle, bot, Vector3(0, 4.5, 0))
			var cap := CylinderMesh.new()
			cap.top_radius = 0.6
			cap.bottom_radius = 1.2
			cap.height = 2.0
			cap.material = _deco_mat(Color(0.95, 0.95, 0.95))
			_multimesh(cap, bot, Vector3(0, 10.0, 0))
		"playground":
			# RF-304: praça — árvores do Racing Kit, balanços (pórtico + assentos) e bolas coloridas
			var trees: Array[Transform3D] = []
			var swings: Array[Transform3D] = []
			var balls: Array[Transform3D] = []
			for i in xforms.size():
				var x := xforms[i]
				match i % 4:
					0, 1:
						trees.append(Transform3D(x.basis.scaled(Vector3.ONE * 9.0), x.origin))
					2:
						swings.append(Transform3D(Basis(Vector3.UP, float(i) * 1.7), x.origin))
					3:
						balls.append(x)
			_multimesh_scene(RACING + "treeLarge.glb", trees)
			var leg := BoxMesh.new()
			leg.size = Vector3(0.35, 8.6, 0.35)
			leg.material = _deco_mat(Color(0.2, 0.45, 0.9))
			for sx in [-4.0, 4.0]:
				for sz in [-1.2, 1.2]:
					var tilted: Array[Transform3D] = []
					for x in swings:
						tilted.append(Transform3D(x.basis * Basis(Vector3.RIGHT, -signf(sz) * 0.14), x.origin + x.basis * Vector3(sx, 0, sz)))
					_multimesh(leg, tilted, Vector3(0, 4.2, 0))
			var bar := BoxMesh.new()
			bar.size = Vector3(8.6, 0.4, 0.4)
			bar.material = _deco_mat(Color(0.95, 0.3, 0.3))
			_multimesh(bar, swings, Vector3(0, 8.4, 0))
			var rope := BoxMesh.new()
			rope.size = Vector3(0.08, 6.0, 0.08)
			rope.material = _deco_mat(Color(0.3, 0.3, 0.32))
			var seat := BoxMesh.new()
			seat.size = Vector3(1.6, 0.18, 0.8)
			seat.material = _deco_mat(Color(1.0, 0.8, 0.2))
			for sx in [-2.0, 2.0]:
				_multimesh(rope, swings, Vector3(sx - 0.6, 5.3, 0))
				_multimesh(rope, swings, Vector3(sx + 0.6, 5.3, 0))
				_multimesh(seat, swings, Vector3(sx, 2.3, 0))
			var ball := SphereMesh.new()
			ball.radius = 1.6
			ball.height = 3.2
			var cols := [Color(0.95, 0.25, 0.25), Color(0.25, 0.55, 1.0), Color(1.0, 0.85, 0.2), Color(0.35, 0.8, 0.35)]
			var bxf: Array = []
			var bcol: Array = []
			for k in balls.size():
				bxf.append(Transform3D(balls[k].basis, balls[k].origin + Vector3.UP * 1.6 * balls[k].basis.get_scale().y))
				bcol.append(cols[k % cols.size()])
			_multimesh_colored(ball, bxf, bcol, _vc_mat(0.4))
		"machine":
			# RF-274: chaminés com faixa (metade) e máquinas-caixa com luz (outra metade)
			var ch: Array[Transform3D] = []
			var mc: Array[Transform3D] = []
			for i in xforms.size():
				(ch if i % 2 == 0 else mc).append(xforms[i])
			var pipe := CylinderMesh.new()
			pipe.top_radius = 1.1
			pipe.bottom_radius = 1.4
			pipe.height = 18.0
			pipe.material = _deco_mat(deco_color)
			var band := CylinderMesh.new()
			band.top_radius = 1.2
			band.bottom_radius = 1.2
			band.height = 1.2
			band.material = _deco_mat(Color(0.75, 0.15, 0.1))
			_multimesh(pipe, ch, Vector3(0, 9.0, 0))
			_multimesh(band, ch, Vector3(0, 15.0, 0))
			var box := BoxMesh.new()
			box.size = Vector3(6.0, 4.0, 5.0)
			box.material = _deco_mat(Color(0.25, 0.26, 0.3))
			var lamp := BoxMesh.new()
			lamp.size = Vector3(6.1, 0.4, 5.1)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(1.0, 0.6, 0.15)
			lm.emission_enabled = true
			lm.emission = Color(1.0, 0.55, 0.1)
			lm.emission_energy_multiplier = 2.0
			lamp.material = lm
			_multimesh(box, mc, Vector3(0, 2.0, 0))
			_multimesh(lamp, mc, Vector3(0, 3.2, 0))
		"cactus":
			var body := CylinderMesh.new()
			body.top_radius = 0.5
			body.bottom_radius = 0.55
			body.height = 4.5
			body.material = _deco_mat(deco_color)
			var arm := CylinderMesh.new()
			arm.top_radius = 0.32
			arm.bottom_radius = 0.32
			arm.height = 1.8
			arm.material = body.material
			_multimesh(body, xforms, Vector3(0, 2.25, 0))
			_multimesh(arm, xforms, Vector3(0.75, 2.8, 0))
			_multimesh(arm, xforms, Vector3(-0.7, 2.1, 0))
		"lamp":
			# postes em fila do lado de fora do muro, alternando os lados
			xforms.clear()
			for i in range(0, points.size(), 18):
				var side := 1.0 if (i / 18) % 2 == 0 else -1.0
				xforms.append(Transform3D(Basis(), points[i] + rights[i] * side * (WALL + 2.0)))
			var post := CylinderMesh.new()
			post.top_radius = 0.12
			post.bottom_radius = 0.18
			post.height = 6.0
			post.material = _deco_mat(Color(0.2, 0.2, 0.25))
			var bulb := SphereMesh.new()
			bulb.radius = 0.55
			bulb.height = 1.1
			var bulb_mat := StandardMaterial3D.new()
			bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bulb_mat.albedo_color = deco_color
			bulb.material = bulb_mat
			var halo := QuadMesh.new()
			halo.size = Vector2(4.0, 4.0)
			var halo_mat := StandardMaterial3D.new()
			halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			halo_mat.albedo_color = Color(deco_color.r, deco_color.g, deco_color.b, 0.5)
			var grad := Gradient.new()
			grad.set_color(0, Color(1, 1, 1, 1))
			grad.set_color(1, Color(1, 1, 1, 0))
			var glow := GradientTexture2D.new()
			glow.gradient = grad
			glow.fill = GradientTexture2D.FILL_RADIAL
			glow.fill_from = Vector2(0.5, 0.5)
			glow.fill_to = Vector2(0.5, 0.0)
			glow.width = 64
			glow.height = 64
			halo_mat.albedo_texture = glow
			halo.material = halo_mat
			_multimesh(post, xforms, Vector3(0, 3.0, 0))
			_multimesh(bulb, xforms, Vector3(0, 6.2, 0))
			_multimesh(halo, xforms, Vector3(0, 6.2, 0))
		_:
			# RF-173: árvores do Racing Kit (Kenney), metade grandes, metade pequenas
			var big: Array[Transform3D] = []
			var small: Array[Transform3D] = []
			for i in xforms.size():
				var x := xforms[i]
				var t := Transform3D(x.basis.scaled(Vector3.ONE * 9.0), x.origin)
				(big if i % 2 == 0 else small).append(t)
			_multimesh_scene(RACING + "treeLarge.glb", big)
			_multimesh_scene(RACING + "treeSmall.glb", small)


## MultiMesh a partir das malhas de um modelo (.glb), uma MultiMesh por malha.
func _multimesh_scene(path: String, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var local := Gfx._rel_transform(inst, mi)
		var offs: Array[Transform3D] = []
		for x in xforms:
			offs.append(x * local)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = offs.size()
		for i in offs.size():
			mm.set_instance_transform(i, offs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		scenery_count += offs.size()
	inst.free()


func _deco_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], offset: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var x := xforms[i]
		mm.set_instance_transform(i, Transform3D(x.basis, x.origin + x.basis * offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


## Setas de turbo (chevrons laranja/amarelo) e a rampa listrada (RF-140/141).
func _pads_and_ramp(st: SurfaceTool) -> void:
	var n := points.size()
	for p in pads:
		var i0: int = p["idx"]
		var lat: float = p["lat"]
		for k in PAD_LEN + 1:
			var i := (i0 + k) % n
			var c := points[i] + rights[i] * lat + Vector3.UP * 0.06
			var t := tangents[i]
			var r := rights[i]
			# base laranja
			_quad(st, c - r * 2.2 - t * 1.0, c + r * 2.2 - t * 1.0, c + r * 2.2 + t * 1.0, c - r * 2.2 + t * 1.0, Color(0.95, 0.45, 0.05))
			# chevron amarelo apontando pra frente (-tangente é "trás"; a pista anda em +t)
			var up := Vector3.UP * 0.01
			var tip := c + t * 0.8 + up
			_quad(st, c - r * 1.8 - t * 0.6 + up, c - r * 1.2 - t * 0.6 + up, tip + t * 0.0, tip - t * 0.6, Color(1.0, 0.92, 0.2))
			_quad(st, c + r * 1.2 - t * 0.6 + up, c + r * 1.8 - t * 0.6 + up, tip - t * 0.6, tip, Color(1.0, 0.92, 0.2))
	for r in _all_ramps():
		_draw_ramp(st, int(r["idx"]), float(r["h"]), "slide" if int(r["idx"]) == ramp_idx and def.get("ramp_style", "") == "slide" else ("lip" if int(r["idx"]) != ramp_idx else ""))


## Uma rampa: listrada (comum), escorregador (RF-302) ou tábua de beirada antes de um vão (RF-330).
func _draw_ramp(st: SurfaceTool, idx: int, h: float, style: String) -> void:
	var n := points.size()
	var slide := style == "slide"
	var plank := style == "lip"
	for k in RAMP_LEN:
		var i := (idx + k) % n
		var j := (i + 1) % n
		var y0 := h * float(k) / RAMP_LEN
		var y1 := h * float(k + 1) / RAMP_LEN
		var stripes := 6
		for s in stripes:
			var la := -ROAD_HALF + 2.0 * ROAD_HALF * s / stripes
			var lb := -ROAD_HALF + 2.0 * ROAD_HALF * (s + 1) / stripes
			var c := Color(1.0, 0.8, 0.1) if (s + k) % 2 == 0 else Color(0.1, 0.1, 0.12)
			if slide:  # RF-302: escorregador de plástico (vermelho com faixas amarelas)
				c = Color(0.92, 0.22, 0.2) if s % 3 != 1 else Color(1.0, 0.82, 0.2)
			elif plank:  # tábuas de madeira com a ponta pintada de amarelo
				c = Color(0.55, 0.36, 0.2).darkened(0.12 * (s % 2)) if k < RAMP_LEN - 1 else Color(1.0, 0.82, 0.15)
			_quad(st, points[i] + rights[i] * la + Vector3.UP * y0, points[i] + rights[i] * lb + Vector3.UP * y0,
				points[j] + rights[j] * lb + Vector3.UP * y1, points[j] + rights[j] * la + Vector3.UP * y1, c)
		# laterais (no escorregador: parede azul que sobe acima da rampa, a "borda" do brinquedo)
		var side_c := Color(0.2, 0.5, 0.95) if slide else (Color(0.4, 0.26, 0.14) if plank else Color(0.25, 0.25, 0.28))
		var lip := 0.7 if slide else 0.0
		for side in [-ROAD_HALF, ROAD_HALF]:
			_quad(st, points[i] + rights[i] * side, points[i] + rights[i] * side + Vector3.UP * (y0 + lip),
				points[j] + rights[j] * side + Vector3.UP * (y1 + lip), points[j] + rights[j] * side, side_c)
	# face da frente (queda)
	var e := (idx + RAMP_LEN) % n
	var face_c := Color(0.2, 0.5, 0.95) if slide else (Color(0.4, 0.26, 0.14) if plank else Color(0.25, 0.25, 0.28))
	_quad(st, points[e] - rights[e] * ROAD_HALF, points[e] + rights[e] * ROAD_HALF,
		points[e] + rights[e] * ROAD_HALF + Vector3.UP * h, points[e] - rights[e] * ROAD_HALF + Vector3.UP * h, face_c)


# ---------------------------------------------------------------- cenário (RF-167)

var scenery_count := 0


func _build_scenery() -> void:
	if def.get("stands", true):  # nos telhados não tem arquibancada nem boxes
		_grandstand()
		_racing_props()
		_flags()
		_tire_stacks()
	_scatter()


func _clear_of_track(pos: Vector3, radius: float) -> bool:
	# no plano (x, z): um trecho alto também ocupa o chão embaixo dele
	for i in points.size():
		if Vector2(pos.x - points[i].x, pos.z - points[i].z).length() <= wall_at(i) + radius:
			return false
	return true


func _vc_mat(roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	return m


func _multimesh_colored(mesh: Mesh, xforms: Array, colors: Array, mat: Material) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	scenery_count += xforms.size()


## Arquibancada com torcida do lado de fora da largada (o lado que tiver espaço).
func _grandstand() -> void:
	var side := 1.0
	if not _clear_of_track(points[0] + rights[0] * (WALL + 20.0), 6.0):
		side = -1.0
	var stand := Node3D.new()
	stand.name = "Grandstand"
	stand.position = points[0] + rights[0] * side * (WALL + 9.0)
	stand.basis = Basis(Vector3.UP, heading_at(0))
	add_child(stand)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.62, 0.66)
	concrete.albedo_texture = Gfx.noise_tex("grain", 0.35, [Color(0.72, 0.72, 0.72), Color(0.92, 0.92, 0.92), Color(1, 1, 1)])
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var length := 44.0
	for k in 4:
		var tier := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.6, 0.9 * (k + 1), length)
		tier.mesh = bm
		tier.material_override = concrete
		tier.position = Vector3(side * (k * 2.6), 0.45 * (k + 1), 0)
		stand.add_child(tier)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = def["wall"][0]
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(12.0, 0.35, length + 2.0)
	roof.mesh = rm
	roof.material_override = roof_mat
	roof.position = Vector3(side * 4.0, 7.2, 0)
	stand.add_child(roof)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.18
	post_mesh.bottom_radius = 0.18
	post_mesh.height = 7.2
	for z in [-length * 0.5, 0.0, length * 0.5]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = concrete
		post.position = Vector3(side * 9.5, 3.6, z)
		stand.add_child(post)
	# placa pendurada na frente do telhado: o letreiro tem fundo (antes flutuava no ar)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = def["wall"][0]
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.08, 0.09, 0.16)
	for part in [[Vector3(0.22, 2.3, 33.0), frame_mat, -1.62], [Vector3(0.12, 1.9, 32.2), board_mat, -1.75]]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = part[0]
		mi.mesh = bx
		mi.material_override = part[1]
		mi.position = Vector3(side * float(part[2]), 5.9, 0)
		mi.name = "BannerBoard"
		stand.add_child(mi)
	var banner := Label3D.new()
	banner.text = "Car Mundon'GO"
	banner.font_size = 150
	banner.pixel_size = 0.0115
	banner.outline_size = 24
	banner.modulate = Color(1.0, 0.85, 0.2)
	banner.position = Vector3(side * -1.84, 5.9, 0)
	banner.rotation.y = -PI / 2.0 * side
	banner.double_sided = false  # sem texto espelhado por trás
	stand.add_child(banner)
	# torcida: cápsulas coloridas nos degraus
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var fan := CapsuleMesh.new()
	fan.radius = 0.28
	fan.height = 1.0
	var xf: Array = []
	var cols: Array = []
	for k in 4:
		var z := -length * 0.5 + 0.6
		while z < length * 0.5 - 0.6:
			if rng.randf() < 0.85:
				var local := Vector3(side * (k * 2.6), 0.9 * (k + 1) + 0.5, z + rng.randf_range(-0.15, 0.15))
				xf.append(Transform3D(stand.basis, stand.position + stand.basis * local))
				cols.append(Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.0)))
			z += 0.85
	_multimesh_colored(fan, xf, cols, _vc_mat())


## Bandeirolas quadriculadas dos dois lados da reta de largada.
func _flags() -> void:
	var n := points.size()
	var poles: Array = []
	var flags: Array = []
	for k in range(-24, 25, 6):
		var i := wrapi(k, 0, n)
		for side in [-1.0, 1.0]:
			var base: Vector3 = points[i] + rights[i] * side * (WALL + WALL_T + 1.2)
			poles.append(Transform3D(Basis(), base + Vector3.UP * 2.5))
			flags.append(Transform3D(Basis(Vector3.UP, heading_at(i) + PI / 2.0), base + Vector3.UP * 4.4 - tangents[i] * 0.8))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 5.0
	var white: Array = []
	for t in poles:
		white.append(Color(0.85, 0.85, 0.9))
	_multimesh_colored(pole, poles, white, _vc_mat(0.4))
	var flag := QuadMesh.new()
	flag.size = Vector2(1.6, 1.0)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = Gfx.checker_tex(Color.WHITE, Color(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05), "flag")
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.uv1_scale = Vector3(2, 2, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = flag
	mm.instance_count = flags.size()
	for i in flags.size():
		mm.set_instance_transform(i, flags[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = fm
	add_child(mmi)
	scenery_count += flags.size()


## Pilhas de pneu do lado de fora das curvas mais fechadas.
func _tire_stacks() -> void:
	var n := points.size()
	var tire := TorusMesh.new()
	tire.inner_radius = 0.28
	tire.outer_radius = 0.55
	var xf: Array = []
	var cols: Array = []
	var last := -100
	for i in range(0, n, 2):
		if i - last < 12 or curvature_at(i) < 0.75:
			continue
		last = i
		var turn := tangents[i].cross(tangents[(i + 10) % n]).y
		var outer := 1.0 if turn > 0.0 else -1.0
		for s in [-1, 0, 1]:
			var j := wrapi(i + 5 + s, 0, n)
			var base: Vector3 = points[j] + rights[j] * outer * (WALL - 0.7)
			for h in 3:
				xf.append(Transform3D(Basis(), base + Vector3.UP * (0.15 + h * 0.3)))
				var top_c := Color(0.9, 0.15, 0.1) if s == 0 else Color(0.92, 0.92, 0.92)
				cols.append(top_c if h == 2 else Color(0.08, 0.08, 0.09))
	_multimesh_colored(tire, xf, cols, _vc_mat(0.9))


## Tufos/pedras (ou queijos gigantes na cozinha) espalhados fora da pista.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var kind: String = def.get("scenery", "rocks_green")
	var tufts: Array = []
	var tuft_cols: Array = []
	var rocks: Array = []
	var rock_cols: Array = []
	var count := 260 if kind != "cheese" else 30
	if kind == "none":
		return
	if kind == "ice":
		count = 70
	if kind == "fruit":
		count = 110
	if kind == "bbq":
		count = 90
	var tries := 0
	while tufts.size() + rocks.size() < count and tries < 6000:
		tries += 1
		var i := rng.randi_range(0, points.size() - 1)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p: Vector3 = points[i] + rights[i] * side * rng.randf_range(WALL + 3.0, WALL + 55.0)
		p.y = 0.0
		if not _clear_of_track(p, 2.5):
			continue
		var yaw := rng.randf() * TAU
		if kind == "fruit":  # RF-372: laranjas, tomates e melancias caídos da feira
			var fpal := [[Color(1.0, 0.55, 0.1), Vector3(1, 1, 1)], [Color(0.85, 0.12, 0.1), Vector3(1, 0.85, 1)], [Color(0.2, 0.55, 0.2), Vector3(1.6, 1.1, 1.1)]]
			var fk: Array = fpal[rng.randi_range(0, fpal.size() - 1)]
			var fs := rng.randf_range(0.7, 1.6)
			var fv: Vector3 = fk[1] * fs
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(fv), p + Vector3.UP * fv.y * 0.45))
			rock_cols.append((fk[0] as Color).darkened(rng.randf() * 0.1))
			continue
		if kind == "bbq":  # RF-273: tomates, pães e cebolas gigantes na mesa
			var pal := [[Color(0.85, 0.12, 0.08), Vector3(1, 0.9, 1)], [Color(0.78, 0.55, 0.28), Vector3(2.2, 0.8, 1)], [Color(0.62, 0.3, 0.55), Vector3(1, 1.1, 1)], [Color(0.95, 0.9, 0.75), Vector3(1.6, 0.5, 1.6)]]
			var pk: Array = pal[rng.randi_range(0, pal.size() - 1)]
			var s := rng.randf_range(2.0, 4.5)
			var sv: Vector3 = pk[1] * s
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(sv), p + Vector3.UP * sv.y * 0.45))
			rock_cols.append((pk[0] as Color).darkened(rng.randf() * 0.12))
		elif kind == "ice":  # RF-324: cubos de gelo derretendo no fundo da geladeira
			var s := rng.randf_range(1.5, 4.0)
			var axis := Vector3(rng.randf() - 0.5, 1.0, rng.randf() - 0.5).normalized()
			rocks.append(Transform3D(Basis(axis, yaw).scaled(Vector3(s, s * 0.85, s)), p + Vector3.UP * s * 0.4))
			rock_cols.append(Color(0.75, 0.9, 1.0).lightened(rng.randf() * 0.2))
		elif kind == "cheese":
			var s := rng.randf_range(3.0, 8.0)
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * 0.6, s)), p + Vector3.UP * s * 0.3))
			rock_cols.append(Color(1.0, 0.8, 0.25).darkened(rng.randf() * 0.15))
		elif rng.randf() < (0.8 if kind == "rocks_green" else 0.35):
			var s := rng.randf_range(0.6, 1.4)
			tufts.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.8, 1.5), s)), p + Vector3.UP * 0.35 * s))
			var g: Color = Color(0.2, 0.45, 0.15) if kind == "rocks_green" else Color(0.55, 0.45, 0.2)
			tuft_cols.append(g.lightened(rng.randf_range(-0.1, 0.2)))
		else:
			var s := rng.randf_range(0.5, 2.2)
			var axis := Vector3(rng.randf(), 1.0, rng.randf()).normalized()
			rocks.append(Transform3D(Basis(axis, yaw).scaled(Vector3(s, s * 0.6, s * 0.8)), p + Vector3.UP * s * 0.2))
			var rc: Color = Color(0.5, 0.5, 0.52) if kind == "rocks_green" else Color(0.65, 0.5, 0.35)
			rock_cols.append(rc.darkened(rng.randf() * 0.25))
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.45
	tuft.height = 0.9
	tuft.radial_segments = 5
	_multimesh_colored(tuft, tufts, tuft_cols, _vc_mat(1.0))
	var rock: Mesh
	if kind == "ice":
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		rock = cube
	elif kind == "cheese":
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 3
		c.rings = 1
		rock = c
	else:
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		sp.radial_segments = 7
		sp.rings = 4
		rock = sp
	_multimesh_colored(rock, rocks, rock_cols, _vc_mat(0.85))


# ---------------------------------------------------------------- zonas e perigos da pista (RF-270..274)

const BELT_SPEED := 9.0       # esteira pra frente (m/s)
const BELT_SIDE_SPEED := 5.0  # esteira lateral (m/s)
const FAROFA_MULT := 0.62
const SAND_MULT := 0.72         # caixa de areia do parquinho: atalho por dentro, mas lento

var zones: Array = []          # {kind, i0, len, lat0, lat1, dir}
var hazard_specs: Array = []   # {kind, idx, ...} — a corrida cria e anima
var belt_mats: Array = []      # {mat, speed}


func _frac_idx(f: float) -> int:
	return int(points.size() * f) % points.size()


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


func _zones_visual(st: SurfaceTool) -> void:
	var n := points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for z in zones:
		var la: float = z["lat0"]
		var lb: float = z["lat1"]
		for k in int(z["len"]):
			var i := (int(z["i0"]) + k) % n
			match z["kind"]:
				"farofa":
					# areia amarelada com grãos (pontinhos) por cima
					_strip(st, i, la, lb, 0.06, 0.06, Color(0.86, 0.68, 0.36).darkened(rng.randf() * 0.08))
					for g in 6:
						var lat := rng.randf_range(la + 0.3, lb - 0.3)
						var c := points[i] + rights[i] * lat + tangents[i] * rng.randf_range(0.0, SPACING) + Vector3.UP * 0.075
						var s := rng.randf_range(0.12, 0.3)
						_quad(st, c - rights[i] * s - tangents[i] * s, c + rights[i] * s - tangents[i] * s, c + rights[i] * s + tangents[i] * s, c - rights[i] * s + tangents[i] * s, Color(0.98, 0.85, 0.55) if g % 2 == 0 else Color(0.6, 0.42, 0.2))
				"ice":
					# RF-323: gelo azul-claro brilhante com riscos de patins
					_strip(st, i, la, lb, 0.06, 0.06, Color(0.78, 0.92, 1.0).lightened(rng.randf() * 0.1))
					if k % 2 == 0:
						var lat := rng.randf_range(la + 1.0, lb - 3.0)
						_strip(st, i, lat, lat + rng.randf_range(0.15, 0.3), 0.07, 0.07, Color(1, 1, 1))
				"sand":
					# RF-301: caixa de areia clarinha com moldura de madeira e forminhas de brinquedo
					_strip(st, i, la, lb, 0.06, 0.06, Color(0.95, 0.85, 0.6).darkened(rng.randf() * 0.06))
					for lat in [la, lb]:
						_strip(st, i, lat - 0.25, lat + 0.25, 0.14, 0.14, Color(0.6, 0.38, 0.18))
					if k == 0 or k == int(z["len"]) - 1:
						var e := points[i] + tangents[i] * (0.0 if k == 0 else SPACING) + Vector3.UP * 0.14
						_quad(st, e + rights[i] * la - tangents[i] * 0.25, e + rights[i] * lb - tangents[i] * 0.25, e + rights[i] * lb + tangents[i] * 0.25, e + rights[i] * la + tangents[i] * 0.25, Color(0.6, 0.38, 0.18))
					if k % 3 == 1:
						var c := points[i] + rights[i] * rng.randf_range(la + 1.5, lb - 1.5) + Vector3.UP * 0.075
						var s := rng.randf_range(0.4, 0.7)
						var toy: Color = [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(1.0, 0.85, 0.2)][(k / 3) % 3]
						_quad(st, c - rights[i] * s - tangents[i] * s, c + rights[i] * s - tangents[i] * s, c + rights[i] * s + tangents[i] * s, c - rights[i] * s + tangents[i] * s, toy)
				"grill":
					# grelha: fundo com brasa e barras escuras atravessadas
					_strip(st, i, la, lb, 0.05, 0.05, Color(0.55, 0.12, 0.02))
					var c0 := points[i] + Vector3.UP * 0.08
					for b in 2:
						var a := c0 + tangents[i] * (0.5 + b * 1.0)
						_quad(st, a + rights[i] * la - tangents[i] * 0.22, a + rights[i] * lb - tangents[i] * 0.22, a + rights[i] * lb + tangents[i] * 0.22, a + rights[i] * la + tangents[i] * 0.22, Color(0.1, 0.1, 0.11))
					if k % 6 == 0:  # longarinas
						for lat in [la + 0.4, lb - 0.4]:
							var p: Vector3 = points[i] + rights[i] * lat + Vector3.UP * 0.09
							_quad(st, p - rights[i] * 0.2, p + rights[i] * 0.2, p + rights[i] * 0.2 + tangents[i] * SPACING * 6.0, p - rights[i] * 0.2 + tangents[i] * SPACING * 6.0, Color(0.12, 0.12, 0.13))


static func _belt_texture() -> Texture2D:
	var img := Image.create(8, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var c := Color(0.13, 0.13, 0.15) if y % 16 < 11 else Color(0.32, 0.32, 0.36)
		if y % 16 == 11:
			c = Color(0.85, 0.7, 0.15)  # friso amarelo
		for x in 8:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Esteiras: malha própria com UV e material que rola (o _process anda o UV).
func _build_belts() -> void:
	var n := points.size()
	var tex := _belt_texture()
	for z in zones:
		if not String(z["kind"]).begins_with("belt"):
			continue
		var side: bool = z["kind"] == "belt_side"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var la: float = z["lat0"]
		var lb: float = z["lat1"]
		for k in int(z["len"]):
			var i := (int(z["i0"]) + k) % n
			var j := (i + 1) % n
			var y := Vector3.UP * 0.07
			var v0 := float(k) * SPACING / 4.0
			var v1 := float(k + 1) * SPACING / 4.0
			var quad := [points[i] + rights[i] * la + y, points[i] + rights[i] * lb + y, points[j] + rights[j] * lb + y, points[j] + rights[j] * la + y]
			# esteira lateral: frisos ao longo da pista (UV girado), andando pro lado
			var uvs: Array = [Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)] if not side else [Vector2(v0, la / 4.0), Vector2(v0, lb / 4.0), Vector2(v1, lb / 4.0), Vector2(v1, la / 4.0)]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[idx])
				st.add_vertex(quad[idx])
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.7
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.name = "Belt"
		add_child(mi)
		var spd: float = (BELT_SIDE_SPEED if side else BELT_SPEED) * float(z["dir"])
		belt_mats.append({"mat": mat, "speed": spd})


func _process(delta: float) -> void:
	for b in belt_mats:
		var m: StandardMaterial3D = b["mat"]
		m.uv1_offset.y = fmod(m.uv1_offset.y - float(b["speed"]) * delta / 4.0, 1.0)


## Base fixa dos perigos (suportes); o que mexe é criado pela corrida.
func _build_hazard_bases() -> void:
	for h in hazard_specs:
		var i: int = h["idx"]
		if h["kind"] == "press":
			# pórtico da prensa: duas colunas e uma viga por cima da faixa
			var lat: Array = h["lat"]
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.65, 0.1)
			mat.metallic = 0.4
			mat.roughness = 0.5
			for l in [float(lat[0]) - 0.8, float(lat[1]) + 0.8]:
				var col := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.7, 9.0, 0.7)
				col.mesh = bm
				col.material_override = mat
				col.position = points[i] + rights[i] * l + Vector3.UP * 4.5
				add_child(col)
			var beam := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(absf(float(lat[1]) - float(lat[0])) + 2.4, 0.8, 1.2)
			beam.mesh = bb
			beam.material_override = mat
			beam.position = points[i] + rights[i] * (float(lat[0]) + float(lat[1])) * 0.5 + Vector3.UP * 9.2
			beam.basis = Basis(Vector3.UP, heading_at(i))  # X local = lateral da pista
			add_child(beam)
