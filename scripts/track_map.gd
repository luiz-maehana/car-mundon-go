extends Control
## RF-292: desenho do trajeto de uma pista (tela de escolha de pista).
## O traço "se desenha" ao trocar de pista e depois um ponto fica dando voltas.
## Marca largada, setas, rampa, zonas (farofa, areia, esteira, grelha), perigos (fogo, roda, prensa,
## gangorra) e o cruzamento das pistas em 8.

const TrackScript = preload("res://scripts/track.gd")

static var _cache := {}   # id -> {pts: PackedVector2Array, pads, ramp, zones, hazards, length}

var track_id := ""
var reveal := 1.0         # 0..1 quanto do traço já apareceu
var runner := 0.0         # posição do pontinho (0..1)
var line_color := Color(1.0, 0.85, 0.3)


## Dados 2D da pista (gerados uma vez; a pista é criada só pra calcular e logo liberada).
static func data(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var t = TrackScript.new(id)
	var pts := PackedVector2Array()
	for p in t.points:
		pts.append(Vector2(p.x, p.z))
	var zones := []
	for z in t.zones:
		zones.append({"kind": z["kind"], "i0": z["i0"], "len": z["len"]})
	var hazards := []
	for h in t.hazard_specs:
		hazards.append({"kind": h["kind"], "idx": h["idx"]})
	var pads := []
	for p in t.pads:
		pads.append(int(p["idx"]))
	var d := {"pts": pts, "pads": pads, "ramp": t.ramp_idx, "zones": zones, "hazards": hazards, "length": t.length, "crossings": t.crossings.duplicate()}
	t.free()
	_cache[id] = d
	return d


func set_track(id: String, animate := true) -> void:
	if id == track_id:
		return
	track_id = id
	reveal = 0.0 if animate else 1.0
	runner = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if track_id == "":
		return
	if reveal < 1.0:
		reveal = minf(1.0, reveal + delta * 1.4)
	else:
		runner = fmod(runner + delta * 0.12, 1.0)
	queue_redraw()


func _draw() -> void:
	if track_id == "":
		return
	var d := data(track_id)
	var pts: PackedVector2Array = d["pts"]
	var n := pts.size()
	if n < 2:
		return
	# encaixa no retângulo mantendo a proporção
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var pad := 26.0
	var sc := minf((size.x - pad * 2.0) / maxf(hi.x - lo.x, 1.0), (size.y - pad * 2.0) / maxf(hi.y - lo.y, 1.0))
	var off := (size - (hi - lo) * sc) * 0.5
	var map := func(p: Vector2) -> Vector2: return off + (p - lo) * sc
	var shown := int(n * reveal)
	var poly := PackedVector2Array()
	for i in shown + 1:
		poly.append(map.call(pts[i % n]))
	if poly.size() >= 2:
		draw_polyline(poly, Color(0, 0, 0, 0.6), 16.0, true)
		draw_polyline(poly, Color(0.85, 0.87, 0.92), 11.0, true)
	# zonas por cima do traço
	var zone_cols := {"farofa": Color(0.9, 0.7, 0.35), "belt": Color(0.35, 0.8, 1.0), "belt_side": Color(0.6, 0.5, 1.0), "grill": Color(1.0, 0.35, 0.1), "sand": Color(1.0, 0.92, 0.7)}
	for z in d["zones"]:
		var seg := PackedVector2Array()
		for k in int(z["len"]) + 1:
			var i := (int(z["i0"]) + k) % n
			if i <= shown:
				seg.append(map.call(pts[i]))
		if seg.size() >= 2:
			draw_polyline(seg, zone_cols.get(z["kind"], Color.WHITE), 9.0, true)
	if reveal < 1.0:
		return
	# largada (quadriculado), setas, rampa e perigos
	var s0: Vector2 = map.call(pts[0])
	var dir: Vector2 = (map.call(pts[3]) - s0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	for k in 4:
		var c := Color.WHITE if k % 2 == 0 else Color.BLACK
		var a := s0 + nrm * (-9.0 + k * 4.5)
		draw_line(a, a + nrm * 4.5, c, 6.0)
	for c in d.get("crossings", []):  # RF-300: cruzamento (X branco)
		var cp: Vector2 = map.call(pts[int(c[0])])
		draw_circle(cp, 12.0, Color(0, 0, 0, 0.7))
		draw_line(cp + Vector2(-6, -6), cp + Vector2(6, 6), Color.WHITE, 3.0, true)
		draw_line(cp + Vector2(-6, 6), cp + Vector2(6, -6), Color.WHITE, 3.0, true)
	for pi in d["pads"]:
		_marker(map.call(pts[pi]), Color(1.0, 0.55, 0.1), "T")
	if int(d["ramp"]) >= 0:
		_marker(map.call(pts[int(d["ramp"])]), Color(1.0, 0.85, 0.15), "R")
	var hz_cols := {"flame": Color(1.0, 0.35, 0.1), "wheel": Color(1.0, 0.8, 0.25), "press": Color(0.7, 0.72, 0.78), "seesaw": Color(0.3, 0.55, 1.0)}
	var hz_txt := {"flame": "F", "wheel": "Q", "press": "P", "seesaw": "G"}
	for h in d["hazards"]:
		_marker(map.call(pts[int(h["idx"])]), hz_cols.get(h["kind"], Color.WHITE), hz_txt.get(h["kind"], "!"))
	# pontinho dando voltas
	var f := runner * n
	var i0 := int(f) % n
	var p: Vector2 = map.call(pts[i0]).lerp(map.call(pts[(i0 + 1) % n]), f - floorf(f))
	draw_circle(p, 9.0, Color(0, 0, 0, 0.6))
	draw_circle(p, 7.0, line_color)


func _marker(p: Vector2, c: Color, txt: String) -> void:
	draw_circle(p, 11.0, Color(0, 0, 0, 0.7))
	draw_circle(p, 9.0, c)
	var font := get_theme_default_font()
	if font:
		var sz := 13
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(font, p + Vector2(-w * 0.5, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.08, 0.08, 0.1))
