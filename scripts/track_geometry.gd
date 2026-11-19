extends Node3D
## Pista — geometria: traçado 3D, normais, largura, muro, altura do chão e buscas por amostra (RF-120, 320, 370).
## (camada de track.gd — ver o topo de track.gd)

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


# ---------------------------------------------------------------- pontos seguros do resgate (RF-311)

var safe := PackedByteArray()   # 1 = dá pra devolver um kart aqui (longe de perigo, rampa e cruzamento)


static func find(track_id: String) -> Dictionary:
	for t in TRACKS:
		if t["id"] == track_id:
			return t
	return TRACKS[0]


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


# ---------------------------------------------------------------- feira (RF-370..372)

const AWNING_H := 6.2        # toldo da ilha: acima da câmera (que passa por baixo no atalho)
const SIDE_AWNING_H := 3.6   # toldo das barracas nas laterais (por cima do muro)
const STALL_COLS := [Color(0.9, 0.2, 0.2), Color(0.2, 0.6, 0.3), Color(0.2, 0.45, 0.9), Color(0.95, 0.75, 0.15), Color(0.9, 0.45, 0.15)]


# ---------------------------------------------------------------- buracos e pontes (RF-390..392)

var pits: Array = []      # RF-390: {idx, lat, r, pos} buracos redondos na pista (cair = balões)
var bridges: Array = []   # RF-392: {i0, len} trechos de ponte (tábuas, corrimão e rio embaixo)


# ---------------------------------------------------------------- cenário (RF-167)

var scenery_count := 0


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
