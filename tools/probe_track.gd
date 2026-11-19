extends SceneTree
## Mede uma pista: extensão, cruzamentos, curvatura e onde caem setas/rampa/itens.
func _init() -> void:
	var id := "parquinho"
	for a in OS.get_cmdline_user_args():
		id = a
	var T = load("res://scripts/track.gd")
	var t = T.new(id)
	var n: int = t.points.size()
	print("len %.0f m, n %d" % [t.length, n])
	for i in n:
		for j in range(i + 40, n):
			if n - (j - i) < 40:
				continue
			if t.points[i].distance_to(t.points[j]) < 2.1:
				var ang := rad_to_deg(t.tangents[i].angle_to(t.tangents[j]))
				print("cruza %d (%.3f) x %d (%.3f) ang %.0f" % [i, float(i) / n, j, float(j) / n, ang])
	var maxc := 0.0
	var maxi := 0
	for i in n:
		var c: float = t.curvature_at(i)
		if c > maxc:
			maxc = c
			maxi = i
	print("curv max %.2f rad em %.3f" % [maxc, float(maxi) / n])
	var si := int(n * 0.065)
	print("curva da areia vira pra %s" % ("direita (lat +)" if t.tangents[(si + 8) % n].dot(t.rights[si]) > 0.0 else "esquerda (lat -)"))
	print("crossings ", t.crossings)
	print("pads ", t.pads.map(func(p): return snappedf(float(p["idx"]) / n, 0.001)), " ramp %.3f" % (float(t.ramp_idx) / n))
	t.free()
	quit()
