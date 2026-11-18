extends SceneTree
## Gera a arte dos pilotos a partir das ilustrações originais (fundo cinza liso):
##   assets/chars/<id>.png       corpo inteiro, fundo transparente (metade da resolução)
##   assets/chars/<id>_head.png  busto (cabeça + orelhas), recortado justo
##   assets/ui/intro.jpg         tela de abertura (se houver intro.png na origem)
## Uso: godot --headless --path . --script tools/process_characters.gd -- <pasta_origem>
## O arquivo de origem é <nome>.png (aceita "digão.png" para o id "digao").

const IDS := {"fejaum": "fejaum", "burcca": "burcca", "mugurin": "mugurin", "telles": "telles", "ortiz": "ortiz", "shinando": "shinando", "nanni": "nanni", "digao": "digão"}
const SCALE := 0.5
const HEAD_FRACTION := 0.41   # parte de cima da imagem que vira o busto
const STEP_TOL := 0.06        # distância máx. da cor de referência local do fundo
const WARM_MAX := 0.025       # variação máx. de "temperatura" (r - b) em relação ao fundo local
const BG_TOL := 0.3          # distância máx. da cor média do fundo


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("uso: -- <pasta_origem>")
		quit(1)
		return
	var src_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/chars"))
	var fails := 0
	for id in IDS:
		var path: String = src_dir.path_join(IDS[id] + ".png")
		var img := Image.load_from_file(path)
		if img == null:
			printerr("não achei ", path)
			fails += 1
			continue
		var t := Time.get_ticks_msec()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(int(img.get_width() * SCALE), int(img.get_height() * SCALE), Image.INTERPOLATE_LANCZOS)
		_remove_background(img)
		img.save_png("res://assets/chars/%s.png" % id)
		var head := img.get_region(Rect2i(0, 0, img.get_width(), int(img.get_height() * HEAD_FRACTION)))
		var used := head.get_used_rect()
		head = head.get_region(used)
		head.save_png("res://assets/chars/%s_head.png" % id)
		print("%-9s %dx%d  busto %dx%d  (%d ms)" % [id, img.get_width(), img.get_height(), head.get_width(), head.get_height(), Time.get_ticks_msec() - t])
	# tela de abertura (RF-100): intro.png -> assets/ui/intro.jpg
	var intro := Image.load_from_file(src_dir.path_join("intro.png"))
	if intro:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
		intro.convert(Image.FORMAT_RGB8)
		intro.save_jpg("res://assets/ui/intro.jpg", 0.9)
		print("intro     %dx%d" % [intro.get_width(), intro.get_height()])
	quit(1 if fails > 0 else 0)


## Flood fill a partir das bordas: some com o fundo conectado à borda (o cinza da
## camiseta, por exemplo, não está conectado e fica). Borda do recorte ganha 1px de suavização.
func _remove_background(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var n := w * h
	# cor média do fundo = média das 4 bordas
	var avg := Vector3.ZERO
	var count := 0
	for x in w:
		for y in [0, h - 1]:
			avg += _rgb(data, (y * w + x) * 4)
			count += 1
	for y in h:
		for x in [0, w - 1]:
			avg += _rgb(data, (y * w + x) * 4)
			count += 1
	avg /= count
	var bg := PackedByteArray()
	bg.resize(n)
	var queue := PackedInt32Array()
	for x in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)
	var head := 0
	# ref = cor de referência do fundo que "anda" devagar junto com o gradiente
	var ref := PackedVector3Array()
	ref.resize(n)
	var q2 := PackedInt32Array()
	for p in queue:
		var c := _rgb(data, p * 4)
		if bg[p] == 0 and c.distance_to(avg) < BG_TOL:
			bg[p] = 1
			ref[p] = c
			q2.append(p)
	queue = q2
	while head < queue.size():
		var p := queue[head]
		head += 1
		var r := ref[p]
		var px := p % w
		var py := p / w
		for d in 4:
			var nx := px + (1 if d == 0 else (-1 if d == 1 else 0))
			var ny := py + (1 if d == 2 else (-1 if d == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var np := ny * w + nx
			if bg[np] == 1:
				continue
			var nc := _rgb(data, np * 4)
			if nc.distance_to(r) < STEP_TOL and absf((nc.x - nc.z) - (r.x - r.z)) < WARM_MAX and nc.distance_to(avg) < BG_TOL:
				bg[np] = 1
				ref[np] = r.lerp(nc, 0.15)
				queue.append(np)
	# alpha: fundo = 0; pixel de borda (vizinho do fundo) = meio transparente
	for p in n:
		if bg[p] == 1:
			data[p * 4 + 3] = 0
		else:
			var px := p % w
			var py := p / w
			var edge := false
			if px > 0 and bg[p - 1] == 1:
				edge = true
			elif px < w - 1 and bg[p + 1] == 1:
				edge = true
			elif py > 0 and bg[p - w] == 1:
				edge = true
			elif py < h - 1 and bg[p + w] == 1:
				edge = true
			if edge:
				data[p * 4 + 3] = 140
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


func _rgb(data: PackedByteArray, i: int) -> Vector3:
	return Vector3(data[i], data[i + 1], data[i + 2]) / 255.0


