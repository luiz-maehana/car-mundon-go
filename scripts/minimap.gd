extends Control
## Minimapa visto de cima: pista + pontinho de cada kart.

var track: Node3D
var karts: Array = []
var player: Node3D
var poly := PackedVector2Array()
var scale_f := 1.0
var offset := Vector2.ZERO


func setup(t: Node3D, k: Array, p: Node3D) -> void:
	track = t
	karts = k
	player = p


func _process(_delta: float) -> void:
	queue_redraw()


func _map(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - offset) * scale_f + size * 0.5


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
	for k in karts:
		if k == player:
			continue
		if k.is_player:
			draw_circle(_map(k.position), 6.5, Color.WHITE)
		draw_circle(_map(k.position), 5.0, k.color)
	if player:
		draw_circle(_map(player.position), 8.0, Color.WHITE)
		draw_circle(_map(player.position), 6.0, player.color)
