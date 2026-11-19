extends SceneTree
## Mede pistas: extensão, altura por fração, curvas e onde caem setas/rampa.
## godot --headless --path . --script tools/probe_all.gd -- queijo deserto
func _init() -> void:
	var T = load("res://scripts/track.gd")
	for id in OS.get_cmdline_user_args():
		var t = T.new(id)
		var n: int = t.points.size()
		print("== %s: %.0f m, n %d, cruzamentos %s, viadutos %s" % [id, t.length, n, str(t.crossings), str(t.overpasses)])
		var rows := []
		for q in 20:
			var qi := int(n * q / 20.0)
			var turn: float = t.tangents[(qi + 8) % n].dot(t.rights[qi])
			rows.append("%.2f:y%.0f%s%s" % [q / 20.0, t.points[qi].y, "D" if turn > 0.05 else ("E" if turn < -0.05 else "-"), "*" if t.curvature_at(qi) < 0.12 else ""])
		print("   ", " ".join(rows))
		print("   pads ", t.pads.map(func(p): return snappedf(float(p["idx"]) / n, 0.001)), " ramp %.3f" % (float(t.ramp_idx) / n))
		t.free()
	quit()
