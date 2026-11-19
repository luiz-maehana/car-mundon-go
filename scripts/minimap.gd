extends Control
## Minimapa visto de cima: pista + busto de cada piloto (RF-112).
## RF-479: duas camadas. A pista (fundo e traçado) é desenhada uma vez e só refeita se o tamanho
## mudar; por cima, a camada `dots` redesenha só os bustos a cada quadro. Antes o traçado inteiro
## (centenas de pontos com borda suavizada) era refeito todo quadro e pesava no celular.

const Chars = preload("res://scripts/characters.gd")

var track: Node3D
var karts: Array = []
var player: Node3D
var poly := PackedVector2Array()
var scale_f := 1.0
var offset := Vector2.ZERO
var heads_drawn := 0
var dots: Control


func setup(t: Node3D, k: Array, p: Node3D) -> void:
	track = t
	karts = k
	player = p
	if dots == null:
		dots = Control.new()
		dots.name = "Dots"
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dots.draw.connect(_draw_dots)
		add_child(dots)
		resized.connect(queue_redraw)
	queue_redraw()


func _process(_delta: float) -> void:
	if dots:
		dots.queue_redraw()


func _map(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - offset) * scale_f + size * 0.5


## Camada de baixo: fundo, traçado e linha de chegada (só quando o tamanho muda).
func _draw() -> void:
	if track == null:
		return
	var ext: Vector2 = track.bounds_max - track.bounds_min
	scale_f = minf(size.x, size.y) * 0.88 / maxf(ext.x, ext.y)
	offset = (track.bounds_max + track.bounds_min) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	poly.clear()
	var pts: PackedVector3Array = track.points
	for i in range(0, pts.size(), 2):
		poly.append(_map(pts[i]))
	poly.append(poly[0])
	draw_polyline(poly, Color(0.1, 0.1, 0.1, 0.8), 9.0, true)
	draw_polyline(poly, Color(0.85, 0.85, 0.85), 5.0, true)
	var a := _map(pts[0] + track.rights[0] * 8.0)
	var b := _map(pts[0] - track.rights[0] * 8.0)
	draw_line(a, b, Color.WHITE, 3.0)


## Camada de cima (todo quadro): fantasma do recorde e o busto de cada piloto.
func _draw_dots() -> void:
	if track == null:
		return
	# RF-233: fantasma do recorde (bolinha translúcida)
	var race: Node = track.get_parent()
	var ghost = race.get("tt_ghost") if race else null
	if ghost and is_instance_valid(ghost) and ghost.visible:
		var gc := _map(ghost.position)
		dots.draw_circle(gc, 9.0, Color(1, 1, 1, 0.35))
		dots.draw_circle(gc, 6.0, Color(0.75, 0.9, 1.0, 0.7))
	# RF-112: busto de cada piloto; o jogador por último (por cima) e maior
	heads_drawn = 0
	var base := clampf(minf(size.x, size.y) * 0.15, 22.0, 56.0)
	var order := []
	for k in karts:
		if k != player:
			order.append(k)
	if player:
		order.append(player)
	for k in order:
		var big: bool = k == player
		var w := base * (1.35 if big else 1.0)
		var c := _map(k.position)
		dots.draw_circle(c, w * 0.18 + (3.0 if big else 1.5), Color.WHITE if (big or k.is_player) else Color(0, 0, 0, 0.6))
		dots.draw_circle(c, w * 0.18, k.color)
		var tex: Texture2D = Chars.art(k.char_id, "head")
		if tex:
			var h := w * float(tex.get_height()) / float(tex.get_width())
			dots.draw_texture_rect(tex, Rect2(c - Vector2(w * 0.5, h + w * 0.08), Vector2(w, h)), false)
			heads_drawn += 1
