extends Control
## Ícones desenhados em código (RF-130/135): "turbo", "casca", "bomba", "cheese" ou "" (vazio).

var kind := ""


func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	match kind:
		"turbo":
			for k in 2:
				var off := Vector2((k - 0.5) * r * 0.75, 0)
				var col := Color(1.0, 0.55, 0.1) if k == 0 else Color(1.0, 0.85, 0.2)
				var pts := PackedVector2Array([
					c + off + Vector2(-r * 0.45, -r * 0.8), c + off + Vector2(r * 0.15, -r * 0.8),
					c + off + Vector2(r * 0.65, 0), c + off + Vector2(r * 0.15, r * 0.8),
					c + off + Vector2(-r * 0.45, r * 0.8), c + off + Vector2(0.05 * r, 0),
				])
				draw_colored_polygon(pts, col)
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.3, 0.1, 0.0), 2.0, true)
		"casca":
			draw_arc(c + Vector2(r * 0.15, -r * 0.35), r * 0.85, deg_to_rad(95), deg_to_rad(215), 24, Color(0.35, 0.25, 0.0), r * 0.5, true)
			draw_arc(c + Vector2(r * 0.15, -r * 0.35), r * 0.85, deg_to_rad(98), deg_to_rad(212), 24, Color(1.0, 0.88, 0.2), r * 0.38, true)
			draw_circle(c + Vector2(-r * 0.62, r * 0.18), r * 0.1, Color(0.35, 0.25, 0.0))
			draw_circle(c + Vector2(r * 0.05, r * 0.5), r * 0.1, Color(0.35, 0.25, 0.0))
		"bomba":
			draw_circle(c + Vector2(0, r * 0.12), r * 0.72, Color(0.05, 0.05, 0.07))
			draw_circle(c + Vector2(-r * 0.25, -r * 0.12), r * 0.18, Color(1, 1, 1, 0.5))
			draw_line(c + Vector2(r * 0.35, -r * 0.45), c + Vector2(r * 0.7, -r * 0.85), Color(0.6, 0.45, 0.2), r * 0.12)
			draw_circle(c + Vector2(r * 0.72, -r * 0.88), r * 0.16, Color(1.0, 0.4, 0.1))
			draw_circle(c + Vector2(r * 0.72, -r * 0.88), r * 0.08, Color(1.0, 0.95, 0.4))
		"cheese":
			var pts := PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(r, r * 0.6), c + Vector2(r * 0.6, -r * 0.6)])
			draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.38, 0.0), 2.0, true)
			draw_circle(c + Vector2(r * 0.1, r * 0.2), r * 0.17, Color(0.85, 0.6, 0.1))
			draw_circle(c + Vector2(r * 0.55, -r * 0.05), r * 0.11, Color(0.85, 0.6, 0.1))
			draw_circle(c + Vector2(-r * 0.45, r * 0.38), r * 0.1, Color(0.85, 0.6, 0.1))
		"triplo":
			# três fatias de queijo em leque
			for k in 3:
				var off := Vector2((k - 1) * r * 0.55, (absf(k - 1.0)) * r * 0.2)
				var s := r * 0.55
				var pts := PackedVector2Array([c + off + Vector2(-s, s * 0.6), c + off + Vector2(s, s * 0.6), c + off + Vector2(s * 0.6, -s * 0.8)])
				draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.38, 0.0), 2.0, true)
				draw_circle(c + off + Vector2(s * 0.15, s * 0.15), s * 0.17, Color(0.85, 0.6, 0.1))
		"ratoeira":
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.45), Vector2(r * 1.7, r * 0.9)), Color(0.72, 0.5, 0.28))
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.45), Vector2(r * 1.7, r * 0.9)), Color(0.4, 0.25, 0.1), false, 2.0)
			draw_line(c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(r * 0.7, -r * 0.3), Color(0.85, 0.86, 0.9), 3.0)
			draw_line(c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(-r * 0.7, r * 0.25), Color(0.85, 0.86, 0.9), 3.0)
			draw_line(c + Vector2(r * 0.7, -r * 0.3), c + Vector2(r * 0.7, r * 0.25), Color(0.85, 0.86, 0.9), 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.1, r * 0.3), c + Vector2(r * 0.6, r * 0.3), c + Vector2(r * 0.45, 0)]), Color(1.0, 0.82, 0.25))
		"escudo":
			var pts := PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r * 0.8, -r * 0.6), c + Vector2(r * 0.7, r * 0.25), c + Vector2(0, r * 0.95), c + Vector2(-r * 0.7, r * 0.25), c + Vector2(-r * 0.8, -r * 0.6)])
			draw_colored_polygon(pts, Color(0.4, 0.75, 1.0))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1), 3.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, r * 0.3), c + Vector2(r * 0.4, r * 0.3), c + Vector2(r * 0.25, -r * 0.3)]), Color(1.0, 0.82, 0.25))
		"gato":
			# cabeça de gato laranja com olhos verdes
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.1), c + Vector2(-r * 0.65, -r * 0.95), c + Vector2(-r * 0.2, -r * 0.55)]), Color(0.95, 0.55, 0.15))
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.8, -r * 0.1), c + Vector2(r * 0.65, -r * 0.95), c + Vector2(r * 0.2, -r * 0.55)]), Color(0.95, 0.55, 0.15))
			draw_circle(c + Vector2(0, r * 0.1), r * 0.72, Color(0.95, 0.55, 0.15))
			for x in [-1.0, 1.0]:
				draw_circle(c + Vector2(x * r * 0.3, 0), r * 0.17, Color(0.5, 1.0, 0.3))
				draw_rect(Rect2(c + Vector2(x * r * 0.3 - r * 0.04, -r * 0.14), Vector2(r * 0.08, r * 0.28)), Color(0.05, 0.05, 0.05))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.1, r * 0.3), c + Vector2(r * 0.1, r * 0.3), c + Vector2(0, r * 0.42)]), Color(1.0, 0.5, 0.6))
		_:
			draw_line(c - Vector2(r * 0.35, 0), c + Vector2(r * 0.35, 0), Color(1, 1, 1, 0.35), 4.0)
