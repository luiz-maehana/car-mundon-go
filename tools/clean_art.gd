extends SceneTree
## Tira sobra de fundo (cinza-lilás do recorte original) das artes dos pilotos.
## Só nas imagens listadas: o fundo é apagado por "balde" a partir das sementes e das
## bordas com a transparência, só pela cor do fundo (camisetas cinza ficam intactas).
## godot --headless --path . --script tools/clean_art.gd

const BG := Color(0.53, 0.46, 0.49)
const TIGHT := 0.035   # pra começar o balde na borda com a transparência
const LOOSE := 0.075   # pra espalhar
const FEATHER := 0.12  # entre LOOSE e isso: alfa parcial (borda suave)
const JOBS := [
	["res://assets/chars/shinando.png", [Vector2i(245, 584)]],
	["res://assets/chars/ortiz.png", [Vector2i(362, 204)]],
	["res://assets/chars/ortiz_head.png", [Vector2i(288, 197)], true],  # true: semente em todo pixel cor de fundo (não tem roupa cinza)
]


func _dist(c: Color) -> float:
	return maxf(absf(c.r - BG.r), maxf(absf(c.g - BG.g), absf(c.b - BG.b)))


func _initialize() -> void:
	for job in JOBS:
		var path: String = ProjectSettings.globalize_path(job[0])
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var seen := PackedByteArray()
		seen.resize(w * h)
		var queue: Array[Vector2i] = []
		for s in job[1]:
			queue.append(s)
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a < 0.5 or _dist(c) > TIGHT:
					continue
				if job.size() > 2 and job[2]:
					queue.append(Vector2i(x, y))
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and img.get_pixelv(n).a < 0.5:
						queue.append(Vector2i(x, y))
						break
		var removed := 0
		while not queue.is_empty():
			var p: Vector2i = queue.pop_back()
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x]:
				continue
			seen[p.y * w + p.x] = 1
			var c := img.get_pixelv(p)
			if c.a < 0.02:
				continue
			var dist := _dist(c)
			if dist > FEATHER:
				continue
			if dist > LOOSE:  # borda: só suaviza, não espalha
				c.a *= (dist - LOOSE) / (FEATHER - LOOSE)
				img.set_pixelv(p, c)
				continue
			c.a = 0.0
			img.set_pixelv(p, c)
			removed += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				queue.append(p + d)
		img.save_png(path)
		print("%s: %d px de fundo removidos" % [job[0], removed])
	quit()
